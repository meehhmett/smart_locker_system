import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/utils/locker_utils.dart';
import '../../../shared/widgets/app_widgets.dart';

class RfidPage extends StatelessWidget {
  final String userId;
  const RfidPage({super.key, required this.userId});

  Future<void> connectRfid() async {
    final now = DateTime.now().toIso8601String();
    await FirebaseDatabase.instance.ref('users/$userId').update({
      'rfidUid': 'RFID-${DateTime.now().millisecondsSinceEpoch}',
      'rfidStatus': 'Connected',
      'rfidRegisteredAt': now,
      'rfidLastSeenAt': now,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      desktopMaxWidth: 860,
      child: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
        builder: (context, snapshot) {
          final user = safeMap(snapshot.data?.snapshot.value);
          final rfidUid = readable(user['rfidUid'], '-');
          final rfidStatus = readable(
            user['rfidStatus'],
            rfidUid == '-' ? 'Not connected' : 'Connected',
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RFID',
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
                        Icons.wifi_tethering_rounded,
                        'RFID Information',
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: innerDecoration(),
                        child: Column(
                          children: [
                            InfoRow(left: 'RFID UID', right: rfidUid),
                            InfoRow(
                              left: 'Status',
                              right: rfidStatus,
                              green: rfidUid != '-',
                            ),
                            InfoRow(
                              left: 'Registered At',
                              right: formatDate(user['rfidRegisteredAt']),
                            ),
                            InfoRow(
                              left: 'Last Seen At',
                              right: formatDate(user['rfidLastSeenAt']),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: connectRfid,
                          style: outlinePurpleButtonStyle(),
                          child: const Text(
                            'Connect / Refresh RFID',
                            style: TextStyle(
                              color: Color(0xff8d81ff),
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
}
