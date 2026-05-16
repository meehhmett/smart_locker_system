import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../core/utils/locker_utils.dart';
import '../../../shared/widgets/app_widgets.dart';

class RequestLockerPage extends StatefulWidget {
  final int lockerId;
  final String lockerKey;

  const RequestLockerPage({
    super.key,
    required this.lockerId,
    required this.lockerKey,
  });

  @override
  State<RequestLockerPage> createState() => _RequestLockerPageState();
}

class _RequestLockerPageState extends State<RequestLockerPage> {
  String selectedPlan = 'Hourly';
  int duration = 1;
  bool loading = false;
  final couponController = TextEditingController();
  double discountRate = 0;
  String appliedCoupon = '';
  Map<String, dynamic> organization = {};
  String get userId => FirebaseAuth.instance.currentUser!.uid;

  int get pricePerUnit {
    final hourly = organizationHourlyPrice(organization);
    if (selectedPlan == 'Hourly') return hourly;
    if (selectedPlan == 'Daily') return hourly * 7;
    return hourly * 45;
  }

  String get unitText {
    if (selectedPlan == 'Hourly') return 'hours';
    if (selectedPlan == 'Daily') return 'days';
    return 'weeks';
  }

  int get subtotal => duration * pricePerUnit;
  int get discountAmount => (subtotal * discountRate).round();
  int get total => subtotal - discountAmount;

  @override
  void dispose() {
    couponController.dispose();
    super.dispose();
  }

  Future<void> proceedPayment() async {
    if (loading) return;
    setState(() => loading = true);
    final db = FirebaseDatabase.instance.ref();
    try {
      final balanceSnap = await db.child('users/$userId/balance').get();
      final userSnap = await db.child('users/$userId').get();
      final balance = toInt(balanceSnap.value);
      final userData = safeMap(userSnap.value);
      final organizationId = organizationIdOf(userData);
      if (organizationId.isEmpty) {
        showMessage('Join an organization before requesting a locker');
        return;
      }
      final organizationSnap = await db
          .child('organizations/$organizationId')
          .get();
      final organizationData = safeMap(organizationSnap.value);
      final lockerSnap = await db
          .child(organizationLockerPath(organizationId, widget.lockerKey))
          .get();
      final lockerData = safeMap(lockerSnap.value);
      final organizationLockersSnap = await db
          .child('organizations/$organizationId/lockers')
          .get();
      final existingLocker = findMyLocker(
        organizationLockersSnap.value,
        userId,
      );
      if (existingLocker != null && existingLocker.key != widget.lockerKey) {
        showMessage(
          'You can rent only one locker in this organization at a time.',
        );
        return;
      }
      final ownerId = readable(lockerData['ownerId'], '');
      final lockerOrganizationId = organizationIdOf(lockerData);
      final available =
          lockerData['status'] == 'available' &&
          lockerData['maintenance'] != true &&
          ownerId.isEmpty;
      if (lockerOrganizationId != organizationId) {
        showMessage('This locker does not belong to your organization');
        return;
      }
      if (!available) {
        showMessage('Locker is not available');
        return;
      }
      if (balance < total) {
        showMessage('Insufficient balance');
        return;
      }
      final now = DateTime.now();
      final endsAt = calculateEndDate(now, selectedPlan, duration);
      if (total > 0) {
        await db.child('users/$userId').update({'balance': balance - total});
      }
      await db
          .child(organizationLockerPath(organizationId, widget.lockerKey))
          .update({
            'status': 'in_use',
            'maintenance': false,
            'ownerId': userId,
            'organizationId': organizationId,
            'organizationName': readable(
              organizationData['name'],
              organizationNameOf(userData),
            ),
            'hourlyPrice': organizationHourlyPrice(organizationData),
            'organizationType': organizationTypeOf(organizationData),
            'command': 'none',
            'plan': selectedPlan,
            'duration': duration,
            'requestedAt': now.toIso8601String(),
            'endsAt': endsAt.toIso8601String(),
            'totalPaid': total,
            'subtotal': subtotal,
            'discount': discountAmount,
            'coupon': appliedCoupon,
            'penaltyPaid': 0,
            'lastPenaltyCalculatedAt': now.toIso8601String(),
          });
      await ActivityLogService.write(
        organizationId: organizationId,
        actorId: userId,
        targetUserId: userId,
        lockerKey: widget.lockerKey,
        type: 'locker_rented',
        message: 'Locker ${widget.lockerId} rented for $duration $unitText',
        metadata: {
          'plan': selectedPlan,
          'duration': duration,
          'totalPaid': total,
          'endsAt': endsAt.toIso8601String(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total == 0 ? 'Locker assigned' : 'Payment successful'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      showMessage(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void applyCoupon() {
    final code = couponController.text.trim().toLowerCase();
    if (code == 'sepette50') {
      setState(() {
        discountRate = 0.5;
        appliedCoupon = 'sepette50';
      });
      showMessage('%50 discount applied');
    } else {
      setState(() {
        discountRate = 0;
        appliedCoupon = '';
      });
      showMessage('Invalid coupon code');
    }
  }

  Widget selectablePricingOption({
    required String title,
    required String subtitle,
    required String price,
    String? badge,
  }) {
    final selected = selectedPlan == title;
    return GestureDetector(
      onTap: () => setState(() {
        selectedPlan = title;
        duration = 1;
      }),
      child: pricingOption(
        selected: selected,
        title: title,
        subtitle: subtitle,
        price: price,
        badge: badge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b0d14),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
          builder: (context, userSnapshot) {
            final user = safeMap(userSnapshot.data?.snapshot.value);
            final organizationId = organizationIdOf(user);
            if (organizationId.isEmpty) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktopLayout(context) ? 720 : 500,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: cardContainer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleRow(Icons.apartment_rounded, 'No Organization'),
                          const SizedBox(height: 14),
                          const Text(
                            'Join an organization before requesting a locker.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('organizations/$organizationId')
                  .onValue,
              builder: (context, orgSnapshot) {
                organization = safeMap(orgSnapshot.data?.snapshot.value);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktopLayout(context) ? 980 : 500,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Column(
                                children: [
                                  const Text(
                                    'Request Locker',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Locker ${widget.lockerId}',
                                    style: const TextStyle(
                                      color: Color(0xff6759ff),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 28),
                          if (isFreeOrganization(organization))
                            requestCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionTitle('Free Organization'),
                                  const SizedBox(height: 6),
                                  sectionSub(
                                    'This organization type uses lockers for free.',
                                  ),
                                ],
                              ),
                            )
                          else
                            requestCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionTitle('Pricing Options'),
                                  const SizedBox(height: 6),
                                  sectionSub('Choose a plan that suits you'),
                                  const SizedBox(height: 18),
                                  selectablePricingOption(
                                    title: 'Hourly',
                                    subtitle: 'Minimum 1 hour',
                                    price:
                                        '${moneyText(organizationHourlyPrice(organization))} / hour',
                                    badge: 'Most Popular',
                                  ),
                                  const SizedBox(height: 14),
                                  selectablePricingOption(
                                    title: 'Daily',
                                    subtitle: 'Save 30% compared to hourly',
                                    price:
                                        '${moneyText(organizationHourlyPrice(organization) * 7)} / day',
                                  ),
                                  const SizedBox(height: 14),
                                  selectablePricingOption(
                                    title: 'Weekly',
                                    subtitle: 'Save 35% compared to daily',
                                    price:
                                        '${moneyText(organizationHourlyPrice(organization) * 45)} / week',
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 18),
                          requestCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionTitle('Duration'),
                                const SizedBox(height: 6),
                                sectionSub('How long do you need the locker?'),
                                const SizedBox(height: 20),
                                Container(
                                  height: 56,
                                  decoration: innerDecoration(),
                                  child: Row(
                                    children: [
                                      durationButton(Icons.remove, () {
                                        if (duration > 1) {
                                          setState(() => duration--);
                                        }
                                      }, left: true),
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            '$duration $unitText',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      durationButton(
                                        Icons.add,
                                        () => setState(() => duration++),
                                        left: false,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          requestCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionTitle('Coupon / Promo Code'),
                                const SizedBox(height: 6),
                                sectionSub('Test coupon: sepette50'),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: couponController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter code',
                                          hintStyle: const TextStyle(
                                            color: Colors.white30,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xff181c28),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: applyCoupon,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xff242936,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Apply',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
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
                          requestCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionTitle('Price Breakdown'),
                                const SizedBox(height: 24),
                                PriceRow(left: 'Plan', right: selectedPlan),
                                PriceRow(
                                  left: 'Duration',
                                  right: '$duration $unitText',
                                ),
                                PriceRow(
                                  left: 'Price per unit',
                                  right: pricePerUnit == 0
                                      ? 'Free'
                                      : moneyText(pricePerUnit),
                                ),
                                PriceRow(
                                  left: 'Subtotal',
                                  right: subtotal == 0
                                      ? 'Free'
                                      : moneyText(subtotal),
                                ),
                                PriceRow(
                                  left: 'Discount',
                                  right: signedMoneyText(-discountAmount),
                                  green: true,
                                ),
                                const Divider(
                                  color: Color(0xff242938),
                                  height: 34,
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        color: Color(0xff6759ff),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      total == 0 ? 'Free' : moneyText(total),
                                      style: const TextStyle(
                                        color: Color(0xff6759ff),
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: loading ? null : proceedPayment,
                                    style: purpleButtonStyle(),
                                    child: Text(
                                      loading
                                          ? 'Processing...'
                                          : total == 0
                                          ? 'Assign Locker'
                                          : 'Proceed to Payment',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
