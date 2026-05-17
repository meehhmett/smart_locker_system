import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/models/locker_models.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../core/utils/locker_utils.dart';
import '../../../shared/widgets/app_widgets.dart';

class MyLockerPage extends StatefulWidget {
  final String userId;
  const MyLockerPage({super.key, required this.userId});

  @override
  State<MyLockerPage> createState() => _MyLockerPageState();
}

class _MyLockerPageState extends State<MyLockerPage> {
  String historyOrganizationFilter = 'all';

  String get userId => widget.userId;

  Future<void> requestUnlock({
    required BuildContext context,
    required String lockerKey,
    required Map<String, dynamic> data,
  }) async {
    final organizationId = organizationIdOf(data);
    final status = readable(data['status'], '');
    final ownerUid = readable(data['ownerUid'] ?? data['ownerId'], '');
    if (status != 'rented' || ownerUid != userId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locker cannot be opened')),
        );
      }
      return;
    }
    await FirebaseDatabase.instance
        .ref(
          '${organizationLockerPath(organizationId, lockerKey)}/unlockRequest',
        )
        .set(true);
    await ActivityLogService.write(
      organizationId: organizationId,
      actorId: userId,
      targetUserId: userId,
      lockerKey: lockerKey,
      type: 'locker_unlock_requested',
      message: 'Locker unlock requested from app',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unlock request sent')));
    }
  }

  Future<void> releaseLocker({
    required BuildContext context,
    required String lockerKey,
    required Map<String, dynamic> data,
  }) async {
    final penalty = calculatePenalty(data);
    if (penalty.amount > 0) {
      showPenaltyPaymentDialog(
        context: context,
        lockerKey: lockerKey,
        data: data,
        penalty: penalty,
      );
      return;
    }
    await releaseLockerAfterPayment(
      context: context,
      lockerKey: lockerKey,
      data: data,
      penalty: penalty,
    );
  }

  Future<void> showPenaltyPaymentDialog({
    required BuildContext context,
    required String lockerKey,
    required Map<String, dynamic> data,
    required PenaltyInfo penalty,
  }) async {
    final db = FirebaseDatabase.instance.ref();
    final balanceSnap = await db.child('users/$userId/balance').get();
    final balance = toInt(balanceSnap.value);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final canPay = balance >= penalty.amount;
        return AlertDialog(
          backgroundColor: const Color(0xff141824),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xff232738)),
          ),
          title: const Text(
            'Penalty Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have a penalty before releasing this locker.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              InfoRow(
                left: 'Penalty',
                right: 'TL ${penalty.amount}',
                bold: true,
              ),
              InfoRow(left: 'Balance', right: 'TL $balance', green: canPay),
              if (!canPay)
                const Text(
                  'Your balance is not enough to pay this penalty.',
                  style: TextStyle(
                    color: Color(0xffff6f8e),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            HoverScale(
              child: ElevatedButton(
                onPressed: canPay
                    ? () async {
                        Navigator.pop(dialogContext);
                        await releaseLockerAfterPayment(
                          context: context,
                          lockerKey: lockerKey,
                          data: data,
                          penalty: penalty,
                        );
                      }
                    : null,
                style: purpleButtonStyle(),
                child: const Text(
                  'Pay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> releaseLockerAfterPayment({
    required BuildContext context,
    required String lockerKey,
    required Map<String, dynamic> data,
    required PenaltyInfo penalty,
  }) async {
    final db = FirebaseDatabase.instance.ref();
    final balanceSnap = await db.child('users/$userId/balance').get();
    final organizationId = organizationIdOf(data);
    final currentBalance = toInt(balanceSnap.value);
    if (currentBalance < penalty.amount) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance for penalty payment'),
          ),
        );
      }
      return;
    }
    await db.child('users/$userId').update({
      'balance': currentBalance - penalty.amount,
      'lastPenaltyCharged': penalty.amount,
      'lastPenaltyChargedAt': DateTime.now().toIso8601String(),
    });
    await db.child(organizationLockerPath(organizationId, lockerKey)).update({
      'status': 'available',
      'maintenance': false,
      'ownerId': '',
      'ownerUid': '',
      'allowedRfidUID': '0',
      'lockState': 'locked',
      'unlockRequest': false,
      'rentalStartAt': null,
      'rentalEndAt': null,
      'rentalEndAtIso': null,
      'command': 'none',
      'plan': '',
      'duration': 0,
      'requestedAt': '',
      'endsAt': '',
      'totalPaid': 0,
      'subtotal': 0,
      'discount': 0,
      'coupon': '',
      'penaltyPaid': penalty.amount,
      'releasedAt': DateTime.now().toIso8601String(),
    });
    await db.child('users/$userId/lockerHistory').push().set({
      'lockerKey': lockerKey,
      'lockerNumber': lockerIdFromKey(lockerKey),
      'organizationId': organizationId,
      'organizationName': organizationNameOf(data),
      'plan': readable(data['plan'], '-'),
      'duration': toInt(data['duration']),
      'requestedAt': readable(data['requestedAt'], ''),
      'endsAt': readable(data['endsAt'], ''),
      'releasedAt': DateTime.now().toIso8601String(),
      'subtotal': toInt(data['subtotal']),
      'discount': toInt(data['discount']),
      'totalPaid': toInt(data['totalPaid']),
      'penaltyPaid': penalty.amount,
    });
    await ActivityLogService.write(
      organizationId: organizationId,
      actorId: userId,
      targetUserId: userId,
      lockerKey: lockerKey,
      type: 'locker_released',
      message: penalty.amount > 0
          ? 'Locker released after TL ${penalty.amount} penalty payment'
          : 'Locker released',
      metadata: {'penaltyPaid': penalty.amount},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            penalty.amount > 0
                ? 'Locker released. Penalty charged: ${moneyText(penalty.amount)}'
                : 'Locker released',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      desktopMaxWidth: 860,
      child: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
        builder: (context, snapshot) {
          final user = safeMap(snapshot.data?.snapshot.value);
          final organizationId = organizationIdOf(user);
          if (organizationId.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Locker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 22),
                  cardContainer(
                    child: const Center(
                      child: Text(
                        'Join an organization to use lockers.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  previousLockersCard(user),
                ],
              ),
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
              if (myLocker == null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Locker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 22),
                      cardContainer(
                        child: const Center(
                          child: Text(
                            "You don't have an active locker",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      previousLockersCard(user),
                    ],
                  ),
                );
              }
              final data = myLocker.data;
              final penalty = calculatePenalty(data);
              final lockerNumber = lockerIdFromKey(myLocker.key);
              final ownerUid = readable(
                data['ownerUid'] ?? data['ownerId'],
                '',
              );
              final canRequestUnlock =
                  data['status'] == 'rented' && ownerUid == userId;
              final lockState = readable(data['lockState'], 'locked');
              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Locker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 22),
                    cardContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleRow(
                            Icons.lock_outline_rounded,
                            'Locker $lockerNumber',
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: innerDecoration(),
                            child: Column(
                              children: [
                                InfoRow(
                                  left: 'Status',
                                  right: readable(data['status'], '-'),
                                  green:
                                      data['status'] == 'in_use' ||
                                      data['status'] == 'rented',
                                ),
                                InfoRow(
                                  left: 'Lock State',
                                  right: lockState == 'unlocked'
                                      ? 'Unlocked / A\u00e7\u0131k'
                                      : 'Locked / Kilitli',
                                  green: lockState == 'unlocked',
                                ),
                                InfoRow(
                                  left: 'Plan',
                                  right: readable(data['plan'], '-'),
                                ),
                                InfoRow(
                                  left: 'Duration',
                                  right:
                                      '${toInt(data['duration'])} ${unitForPlan(data['plan'])}',
                                ),
                                InfoRow(
                                  left: 'Requested At',
                                  right: formatDate(data['requestedAt']),
                                ),
                                InfoRow(
                                  left: 'Ends At',
                                  right: formatDate(data['endsAt']),
                                ),
                                InfoRow(
                                  left: 'Time Left',
                                  right: timeLeft(data['endsAt']),
                                ),
                                InfoRow(
                                  left: 'Grace / Penalty',
                                  right: penalty.description,
                                  green: penalty.amount == 0,
                                ),
                                InfoRow(
                                  left: 'Current Penalty',
                                  right: moneyText(penalty.amount),
                                  green: penalty.amount == 0,
                                ),
                                InfoRow(
                                  left: 'Subtotal',
                                  right: moneyText(toInt(data['subtotal'])),
                                ),
                                InfoRow(
                                  left: 'Discount',
                                  right: signedMoneyText(
                                    -toInt(data['discount']),
                                  ),
                                  green: true,
                                ),
                                InfoRow(
                                  left: 'Total Paid',
                                  right: moneyText(toInt(data['totalPaid'])),
                                  bold: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (canRequestUnlock) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: HoverScale(
                                child: ElevatedButton.icon(
                                  onPressed: () => requestUnlock(
                                    context: context,
                                    lockerKey: myLocker.key,
                                    data: data,
                                  ),
                                  style: purpleButtonStyle(),
                                  icon: const Icon(
                                    Icons.lock_open_rounded,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Open Locker',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: HoverScale(
                              child: ElevatedButton(
                                onPressed: () => releaseLocker(
                                  context: context,
                                  lockerKey: myLocker.key,
                                  data: data,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffff6f8e),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Release Locker',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    previousLockersCard(user),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget previousLockersCard(Map<String, dynamic> user) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/$userId/lockerHistory')
          .onValue,
      builder: (context, snapshot) {
        final history = safeMap(snapshot.data?.snapshot.value).entries.toList()
          ..sort(
            (a, b) => readable(
              safeMap(b.value)['releasedAt'],
              '',
            ).compareTo(readable(safeMap(a.value)['releasedAt'], '')),
          );
        final organizations = <String, String>{
          'all': 'All organizations',
          for (final entry in history)
            organizationIdOf(safeMap(entry.value)): organizationNameOf(
              safeMap(entry.value),
            ),
        };
        if (!organizations.containsKey(historyOrganizationFilter)) {
          historyOrganizationFilter = 'all';
        }
        final filtered = history.where((entry) {
          if (historyOrganizationFilter == 'all') return true;
          return organizationIdOf(safeMap(entry.value)) ==
              historyOrganizationFilter;
        }).toList();

        return cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: titleRow(Icons.history_rounded, 'Previous Lockers'),
                  ),
                  if (organizations.length > 1)
                    SizedBox(
                      width: 210,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: innerDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: historyOrganizationFilter,
                            dropdownColor: const Color(0xff181c28),
                            iconEnabledColor: Colors.white54,
                            isExpanded: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            items: organizations.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => historyOrganizationFilter = value);
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Text(
                  'No previous locker history',
                  style: TextStyle(color: Colors.white54),
                )
              else
                ...filtered.map((entry) {
                  final item = safeMap(entry.value);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: innerDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            iconCircle(Icons.lock_outline_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Locker ${toInt(item['lockerNumber'])}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              'TL ${toInt(item['totalPaid'])}',
                              style: const TextStyle(
                                color: Color(0xff8d81ff),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InfoRow(
                          left: 'Organization',
                          right: organizationNameOf(item),
                        ),
                        InfoRow(
                          left: 'Plan',
                          right: readable(item['plan'], '-'),
                        ),
                        InfoRow(
                          left: 'Requested',
                          right: formatDate(item['requestedAt']),
                        ),
                        InfoRow(
                          left: 'Released',
                          right: formatDate(item['releasedAt']),
                        ),
                        InfoRow(
                          left: 'Penalty Paid',
                          right: 'TL ${toInt(item['penaltyPaid'])}',
                          green: toInt(item['penaltyPaid']) == 0,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
