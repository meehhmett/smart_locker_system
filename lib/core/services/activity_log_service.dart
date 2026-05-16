import 'package:firebase_database/firebase_database.dart';

import '../utils/locker_utils.dart';

class ActivityLogService {
  const ActivityLogService._();

  static Future<void> write({
    required String organizationId,
    required String actorId,
    required String type,
    required String message,
    String? targetUserId,
    String? lockerKey,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final ref = FirebaseDatabase.instance.ref('activityLogs').push();
    await ref.set({
      'organizationId': organizationId.isEmpty
          ? defaultOrganizationId
          : organizationId,
      'actorId': actorId,
      'targetUserId': targetUserId ?? '',
      'lockerKey': lockerKey ?? '',
      'type': type,
      'message': message,
      'createdAt': now.toIso8601String(),
      'createdAtMillis': now.millisecondsSinceEpoch,
      'metadata': metadata ?? <String, dynamic>{},
    });
  }
}
