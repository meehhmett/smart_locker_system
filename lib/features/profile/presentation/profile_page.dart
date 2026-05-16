import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/utils/locker_utils.dart';
import '../../../shared/widgets/app_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final organizationCodeController = TextEditingController();
  bool joiningOrganization = false;
  String get userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    organizationCodeController.dispose();
    super.dispose();
  }

  Future<void> addBalance(int amount) async {
    final db = FirebaseDatabase.instance.ref();
    final snap = await db.child('users/$userId/balance').get();
    final currentBalance = toInt(snap.value);
    await db.child('users/$userId').update({
      'balance': currentBalance + amount,
    });
  }

  Future<void> requestOrganizationJoin(Map<String, dynamic> user) async {
    if (joiningOrganization) return;
    final code = organizationCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      showMessage('Please enter an organization code');
      return;
    }
    setState(() => joiningOrganization = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      final orgSnap = await db
          .child('organizations')
          .orderByChild('joinCode')
          .equalTo(code)
          .get();
      final organizations = safeMap(orgSnap.value);
      if (organizations.isEmpty) {
        showMessage('Organization code not found');
        return;
      }
      final orgEntry = organizations.entries.first;
      final organization = safeMap(orgEntry.value);
      final organizationId = orgEntry.key;
      final now = DateTime.now();
      await db.child('organizationRequests').push().set({
        'userId': userId,
        'userName':
            '${readable(user['name'], '')} ${readable(user['surname'], '')}'
                .trim(),
        'userEmail':
            FirebaseAuth.instance.currentUser?.email ??
            readable(user['email'], '-'),
        'fromOrganizationId': organizationIdOf(user),
        'fromOrganizationName': organizationNameOf(user),
        'organizationId': organizationId,
        'organizationName': organizationNameOf(organization),
        'joinCode': code,
        'status': 'pending',
        'createdAt': now.toIso8601String(),
        'createdAtMillis': now.millisecondsSinceEpoch,
      });
      organizationCodeController.clear();
      showMessage('Request sent. Waiting for admin approval.');
    } catch (e) {
      showMessage(e.toString());
    } finally {
      if (mounted) setState(() => joiningOrganization = false);
    }
  }

  Future<void> switchOrganization({
    required String organizationId,
    required Map<String, dynamic> organization,
  }) async {
    await FirebaseDatabase.instance.ref('users/$userId').update({
      'organizationId': organizationId,
      'organizationName': organizationNameOf(organization),
    });
    showMessage('Organization changed to ${organizationNameOf(organization)}');
  }

  Future<void> logout() async => FirebaseAuth.instance.signOut();

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseDatabase.instance.ref('users/$userId');
    return ResponsiveContent(
      desktopMaxWidth: 860,
      child: StreamBuilder<DatabaseEvent>(
        stream: userRef.onValue,
        builder: (context, snapshot) {
          final user = safeMap(snapshot.data?.snapshot.value);
          final balance = toInt(user['balance']);
          final name = readable(user['name'], '');
          final surname = readable(user['surname'], '');
          final email =
              FirebaseAuth.instance.currentUser?.email ??
              readable(user['email'], '-');
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
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
                      titleRow(Icons.person_outline_rounded, 'Account'),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: innerDecoration(),
                        child: Column(
                          children: [
                            InfoRow(
                              left: 'Name',
                              right: '$name $surname'.trim().isEmpty
                                  ? '-'
                                  : '$name $surname'.trim(),
                            ),
                            InfoRow(left: 'Email', right: email),
                            InfoRow(
                              left: 'Organization',
                              right: organizationNameOf(user),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                organizationsCard(user),
                const SizedBox(height: 18),
                cardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow(Icons.apartment_rounded, 'Join Organization'),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the code shared by your university, pharmacy, or organization. Admin approval is required.',
                        style: TextStyle(color: Colors.white38),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: darkInput(
                              controller: organizationCodeController,
                              hint: 'Organization code',
                              icon: Icons.key_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 54,
                            child: HoverScale(
                              child: ElevatedButton(
                                onPressed: joiningOrganization
                                    ? null
                                    : () => requestOrganizationJoin(user),
                                style: purpleButtonStyle(),
                                child: Text(
                                  joiningOrganization
                                      ? 'Sending...'
                                      : 'Request',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                cardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow(Icons.account_balance_wallet, 'Balance'),
                      const SizedBox(height: 18),
                      Text(
                        moneyText(balance),
                        style: const TextStyle(
                          color: Color(0xff6759ff),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => addBalance(50),
                                style: purpleButtonStyle(),
                                child: const FittedBox(
                                  child: Text(
                                    '+ TL 50',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => addBalance(100),
                                style: purpleButtonStyle(),
                                child: const FittedBox(
                                  child: Text(
                                    '+ TL 100',
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
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: logout,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xffff6f8e)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Color(0xffff6f8e),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget organizationsCard(Map<String, dynamic> user) {
    final activeOrganizationId = organizationIdOf(user);
    final memberships = safeMap(user['organizations']);
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.apartment_rounded, 'My Organizations'),
          const SizedBox(height: 16),
          if (memberships.isEmpty)
            const Text(
              'No approved organizations yet',
              style: TextStyle(color: Colors.white54),
            )
          else
            ...memberships.entries.map((entry) {
              final organization = safeMap(entry.value);
              final active = entry.key == activeOrganizationId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xff181c28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? const Color(0xff6759ff)
                        : const Color(0xff272c3d),
                  ),
                ),
                child: Row(
                  children: [
                    iconCircle(
                      active
                          ? Icons.check_circle_outline_rounded
                          : Icons.apartment_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            organizationNameOf(organization),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            active ? 'Active organization' : 'Approved',
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    if (!active)
                      HoverScale(
                        child: OutlinedButton(
                          onPressed: () => switchOrganization(
                            organizationId: entry.key,
                            organization: organization,
                          ),
                          style: outlinePurpleButtonStyle(),
                          child: const Text(
                            'Use',
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
            }),
        ],
      ),
    );
  }
}
