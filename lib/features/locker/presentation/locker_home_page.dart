import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/utils/locker_utils.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../admin/presentation/admin_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../rfid/presentation/rfid_page.dart';
import 'my_locker_page.dart';
import 'request_locker_page.dart';

class LockerHomePage extends StatefulWidget {
  const LockerHomePage({super.key});

  @override
  State<LockerHomePage> createState() => _LockerHomePageState();
}

class _LockerHomePageState extends State<LockerHomePage> {
  int selectedIndex = 0;
  final lockerSearchController = TextEditingController();
  final notifiedLockers = <String>{};
  Timer? penaltyWarningTimer;
  String lockerSearchQuery = '';
  String get userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    lockerSearchController.addListener(() {
      setState(() => lockerSearchQuery = lockerSearchController.text.trim());
    });
    penaltyWarningTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkPenaltyWarning(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => checkPenaltyWarning());
  }

  @override
  void dispose() {
    penaltyWarningTimer?.cancel();
    lockerSearchController.dispose();
    super.dispose();
  }

  Future<void> checkPenaltyWarning() async {
    if (!mounted) return;
    final userSnap = await FirebaseDatabase.instance.ref('users/$userId').get();
    final organizationId = organizationIdOf(safeMap(userSnap.value));
    if (organizationId.isEmpty) return;
    final snap = await FirebaseDatabase.instance
        .ref('organizations/$organizationId/lockers')
        .get();
    final myLocker = findMyLocker(snap.value, userId);
    if (myLocker == null) return;
    final minutes = minutesUntilPenalty(myLocker.data['endsAt']);
    if (minutes < 0 || minutes > 30 || notifiedLockers.contains(myLocker.key)) {
      return;
    }
    notifiedLockers.add(myLocker.key);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Penalty starts in $minutes minutes. Please release or extend your locker.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
      builder: (context, snapshot) {
        final user = safeMap(snapshot.data?.snapshot.value);
        final canAccessAdmin = isAdminRole(user['role']);
        final pages = [
          lockersPage(),
          MyLockerPage(userId: userId),
          RfidPage(userId: userId),
          const ProfilePage(),
          if (canAccessAdmin) AdminPage(userId: userId),
        ];
        final safeIndex = selectedIndex >= pages.length ? 0 : selectedIndex;
        return Scaffold(
          backgroundColor: const Color(0xff0b0d14),
          bottomNavigationBar: desktop ? null : bottomBar(canAccessAdmin),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) desktopNavigationRail(canAccessAdmin),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.015, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(safeIndex),
                      child: pages[safeIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget lockersPage() {
    return ResponsiveContent(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
            final mainContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lockers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Choose an available locker',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 18),
                lockerSearchField(),
                const SizedBox(height: 18),
                lockersGrid(),
              ],
            );
            final sideContent = Column(
              children: [
                rfidCard(),
                const SizedBox(height: 20),
                lockerInfoCard(),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                topBar(),
                const SizedBox(height: 28),
                if (desktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: mainContent),
                      const SizedBox(width: 22),
                      Expanded(flex: 4, child: sideContent),
                    ],
                  )
                else ...[
                  mainContent,
                  const SizedBox(height: 20),
                  sideContent,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget lockersGrid() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xff6759ff)),
          );
        }
        final user = safeMap(snapshot.data?.snapshot.value);
        final userOrganizationId = organizationIdOf(user);
        if (userOrganizationId.isEmpty) {
          return nearbyPublicLockersGrid();
        }
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref('organizations/$userOrganizationId/lockers')
              .onValue,
          builder: (context, lockerSnapshot) {
            final raw = safeMap(lockerSnapshot.data?.snapshot.value);
            if (raw.isEmpty) {
              return cardContainer(
                child: const Text(
                  'No locker found in Firebase',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            final normalizedQuery = lockerSearchQuery.toLowerCase();
            final entries = raw.entries.where((entry) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final id = lockerIdFromKey(entry.key.toString()).toString();
              return id.contains(normalizedQuery) ||
                  'locker $id'.contains(normalizedQuery) ||
                  entry.key.toString().toLowerCase().contains(normalizedQuery);
            }).toList();
            entries.sort(
              (a, b) => lockerIdFromKey(
                a.key.toString(),
              ).compareTo(lockerIdFromKey(b.key.toString())),
            );
            if (entries.isEmpty) {
              return cardContainer(
                child: const Text(
                  'No locker matches your search',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1000
                    ? 4
                    : width >= 680
                    ? 3
                    : 2;
                final aspectRatio = width >= 1000
                    ? 0.78
                    : width >= 680
                    ? 0.74
                    : 0.62;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: aspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final lockerKey = entries[index].key.toString();
                    final locker = safeMap(entries[index].value);
                    final lockerId = lockerIdFromKey(lockerKey);
                    return lockerCard(
                      lockerKey: lockerKey,
                      id: lockerId,
                      data: locker,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget topBar() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
      builder: (context, snapshot) {
        final user = safeMap(snapshot.data?.snapshot.value);
        final name = readable(user['name'], 'U');
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
        final organizationId = organizationIdOf(user);
        if (organizationId.isEmpty) {
          return Row(
            children: [
              const Text(
                'Smart ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Locker',
                style: TextStyle(
                  color: Color(0xff6759ff),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              notificationIcon(false),
              const SizedBox(width: 12),
              userAvatar(initial),
            ],
          );
        }
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref('organizations/$organizationId/lockers')
              .onValue,
          builder: (context, lockerSnapshot) {
            final myLocker = findMyLocker(
              lockerSnapshot.data?.snapshot.value,
              userId,
            );
            final minutesToPenalty = minutesUntilPenalty(
              myLocker?.data['endsAt'],
            );
            final showPenaltyBadge =
                minutesToPenalty >= 0 && minutesToPenalty <= 30;
            return Row(
              children: [
                const Text(
                  'Smart ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Locker',
                  style: TextStyle(
                    color: Color(0xff6759ff),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                notificationIcon(showPenaltyBadge),
                const SizedBox(width: 12),
                userAvatar(initial),
              ],
            );
          },
        );
      },
    );
  }

  Widget userAvatar(String initial) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xff6759ff),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget nearbyPublicLockersGrid() {
    final lockers = List.generate(8, (index) {
      final distance = 400 + (index * 230);
      return {
        'id': index + 1,
        'distance': distance > 2000 ? 2000 : distance,
        'status': index == 5 ? 'in_use' : 'available',
      };
    });
    final normalizedQuery = lockerSearchQuery.toLowerCase();
    final filtered = lockers.where((locker) {
      if (normalizedQuery.isEmpty) return true;
      final id = locker['id'].toString();
      return id.contains(normalizedQuery) ||
          'locker $id'.contains(normalizedQuery);
    }).toList();
    if (filtered.isEmpty) {
      return cardContainer(
        child: const Text(
          'No nearby locker matches your search',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cardContainer(
          child: const Text(
            'Nearby public lockers are shown as a prototype. Organization approval is not required for this future flow.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1000
                ? 4
                : width >= 680
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: width >= 680 ? 0.85 : 0.74,
              ),
              itemBuilder: (context, index) {
                final locker = filtered[index];
                final available = locker['status'] == 'available';
                final distance = toInt(locker['distance']);
                return HoverScale(
                  scale: available ? 1.025 : 1.01,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff141824),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xff232738)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        iconCircle(Icons.location_on_outlined),
                        const SizedBox(height: 14),
                        Text(
                          'Public Locker ${locker['id']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          distance < 1000
                              ? '$distance m away'
                              : '${(distance / 1000).toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: Color(0xff8d81ff),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          available ? 'Available nearby' : 'Currently in use',
                          style: TextStyle(
                            color: available
                                ? const Color(0xff7ce78c)
                                : const Color(0xffff6f8e),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: const Color(0xff262936),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Future Work',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget lockerSearchField() {
    return TextField(
      controller: lockerSearchController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
        suffixIcon: lockerSearchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: lockerSearchController.clear,
                icon: const Icon(Icons.close_rounded, color: Colors.white38),
              ),
        hintText: 'Search locker number',
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xff181c28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget notificationIcon(bool showBadge) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        HoverScale(child: iconCircle(Icons.notifications_none_rounded)),
        if (showBadge)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xffff6f8e),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff0b0d14), width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget lockerCard({
    required String lockerKey,
    required int id,
    required Map<String, dynamic> data,
  }) {
    final status = readable(data['status'], 'available');
    final maintenance =
        data['maintenance'] == true || status.toLowerCase() == 'maintenance';
    final ownerId = readable(data['ownerId'] ?? data['ownerUid'], '');
    final lockState = readable(data['lockState'], 'locked');
    final mine = ownerId == userId;
    final available = status == 'available' && !maintenance && ownerId.isEmpty;

    String label = 'Available';
    Color labelBg = const Color(0xff1f4f33);
    Color labelText = const Color(0xff7ce78c);
    if (mine) {
      label = 'My Locker';
      labelBg = const Color(0xff27225f);
      labelText = const Color(0xff9b90ff);
    } else if (maintenance) {
      label = 'Maintenance';
      labelBg = const Color(0xff4a3a1f);
      labelText = const Color(0xffffc857);
    } else if (status == 'in_use' || status == 'rented' || ownerId.isNotEmpty) {
      label = 'In Use';
      labelBg = const Color(0xff522636);
      labelText = const Color(0xffff6f8e);
    }

    return HoverScale(
      scale: available ? 1.025 : 1.01,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xff141824),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mine ? const Color(0xff6759ff) : const Color(0xff232738),
            width: mine ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            iconCircle(mine ? Icons.lock_open_rounded : Icons.lock),
            const SizedBox(height: 12),
            Text(
              'Locker $id',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: labelBg,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: labelText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            if (mine) ...[
              const SizedBox(height: 6),
              Text(
                lockState == 'unlocked'
                    ? 'Unlocked / A\u00e7\u0131k'
                    : 'Locked / Kilitli',
                style: TextStyle(
                  color: lockState == 'unlocked'
                      ? const Color(0xff7ce78c)
                      : Colors.white38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const Spacer(),
            Text(
              toInt(data['hourlyPrice']) == 0 ? 'Free locker' : 'Price from',
              style: const TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  toInt(data['hourlyPrice']) == 0
                      ? 'Free'
                      : moneyText(toInt(data['hourlyPrice'])),
                  style: const TextStyle(
                    color: Color(0xff6759ff),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (toInt(data['hourlyPrice']) > 0) ...[
                  const SizedBox(width: 4),
                  const Text('/ hour', style: TextStyle(color: Colors.white54)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: available
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestLockerPage(
                            lockerId: id,
                            lockerKey: lockerKey,
                          ),
                        ),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: available
                      ? const Color(0xff6759ff)
                      : const Color(0xff262936),
                  disabledBackgroundColor: const Color(0xff262936),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  mine
                      ? 'Currently Yours'
                      : available
                      ? 'Request Locker'
                      : 'Unavailable',
                  style: TextStyle(
                    color: available ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget rfidCard() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
      builder: (context, snapshot) {
        final user = safeMap(snapshot.data?.snapshot.value);
        final rfidUid = readable(user['rfidUid'] ?? user['rfidUID'], '-');
        final rfidStatus = readable(
          user['rfidStatus'],
          rfidUid == '-' ? 'Not connected' : 'Connected',
        );
        return cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow(Icons.wifi_tethering_rounded, 'My RFID Card'),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: innerDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RFID UID',
                                style: TextStyle(color: Colors.white38),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rfidUid,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.copy_rounded,
                          color: Color(0xff6759ff),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: rfidUid == '-'
                                ? const Color(0xff522636)
                                : const Color(0xff1f4f33),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            rfidStatus,
                            style: TextStyle(
                              color: rfidUid == '-'
                                  ? const Color(0xffff6f8e)
                                  : const Color(0xff7ce78c),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now().toIso8601String();
                    final uid = 'RFID-${DateTime.now().millisecondsSinceEpoch}';
                    await FirebaseDatabase.instance
                        .ref('users/$userId')
                        .update({
                          'rfidUid': uid,
                          'rfidUID': uid,
                          'rfidStatus': 'Connected',
                          'rfidRegisteredAt': now,
                          'rfidLastSeenAt': now,
                        });
                  },
                  style: outlinePurpleButtonStyle(),
                  child: const Text(
                    'Connect New RFID Card',
                    style: TextStyle(
                      color: Color(0xff8d81ff),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget lockerInfoCard() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
      builder: (context, snapshot) {
        final user = safeMap(snapshot.data?.snapshot.value);
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref('organizations/${organizationIdOf(user)}/lockers')
              .onValue,
          builder: (context, lockerSnapshot) {
            final myLocker = findMyLocker(
              lockerSnapshot.data?.snapshot.value,
              userId,
            );
            if (myLocker == null) {
              return cardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow(Icons.lock_outline_rounded, 'My Locker Info'),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: innerDecoration(),
                      child: Column(
                        children: [
                          const InfoRow(
                            left: 'Status',
                            right: 'No active locker',
                          ),
                          const InfoRow(left: 'Command', right: 'none'),
                          const InfoRow(left: 'Requested At', right: '-'),
                          const InfoRow(left: 'Time Left', right: '-'),
                          InfoRow(
                            left: 'Total Paid',
                            right: moneyText(0),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            final info = myLocker.data;
            final penalty = calculatePenalty(info);
            return cardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleRow(Icons.lock_outline_rounded, 'My Locker Info'),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: innerDecoration(),
                    child: Column(
                      children: [
                        InfoRow(
                          left: 'Status',
                          right: readable(info['status'], '-'),
                          green:
                              info['status'] == 'in_use' ||
                              info['status'] == 'rented',
                        ),
                        InfoRow(
                          left: 'Command',
                          right: readable(info['command'], 'none'),
                        ),
                        InfoRow(
                          left: 'Plan',
                          right: readable(info['plan'], '-'),
                        ),
                        InfoRow(
                          left: 'Requested At',
                          right: formatDate(info['requestedAt']),
                        ),
                        InfoRow(
                          left: 'Ends At',
                          right: formatDate(info['endsAt']),
                        ),
                        InfoRow(
                          left: 'Time Left',
                          right: timeLeft(info['endsAt']),
                        ),
                        InfoRow(
                          left: 'Penalty',
                          right: moneyText(penalty.amount),
                          green: penalty.amount == 0,
                        ),
                        InfoRow(
                          left: 'Total Paid',
                          right: moneyText(toInt(info['totalPaid'])),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget bottomBar(bool canAccessAdmin) {
    return Container(
      height: 80,
      color: const Color(0xff10131c),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          bottomItem(Icons.grid_view_rounded, 'Lockers', 0),
          bottomItem(Icons.lock_outline_rounded, 'My Locker', 1),
          bottomItem(Icons.wifi_tethering_rounded, 'RFID', 2),
          bottomItem(Icons.person_outline_rounded, 'Profile', 3),
          if (canAccessAdmin)
            bottomItem(Icons.admin_panel_settings_rounded, 'Admin', 4),
        ],
      ),
    );
  }

  Widget bottomItem(IconData icon, String text, int index) {
    final active = selectedIndex == index;
    return HoverScale(
      scale: 1.08,
      child: GestureDetector(
        onTap: () => setState(() => selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xff1b1f35) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? const Color(0xff6759ff) : Colors.white38,
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(
                  color: active ? const Color(0xff6759ff) : Colors.white38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget desktopNavigationRail(bool canAccessAdmin) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: Color(0xff10131c),
        border: Border(right: BorderSide(color: Color(0xff232738))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Locker',
            style: TextStyle(
              color: Color(0xff6759ff),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 34),
          desktopNavItem(Icons.grid_view_rounded, 'Lockers', 0),
          desktopNavItem(Icons.lock_outline_rounded, 'My Locker', 1),
          desktopNavItem(Icons.wifi_tethering_rounded, 'RFID', 2),
          desktopNavItem(Icons.person_outline_rounded, 'Profile', 3),
          if (canAccessAdmin)
            desktopNavItem(Icons.admin_panel_settings_rounded, 'Admin', 4),
        ],
      ),
    );
  }

  Widget desktopNavItem(IconData icon, String text, int index) {
    final active = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverScale(
        scale: 1.025,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => selectedIndex = index),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? const Color(0xff1b1f35) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? const Color(0xff6759ff) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: active ? const Color(0xff8d81ff) : Colors.white38,
                ),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
