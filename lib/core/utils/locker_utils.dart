import '../models/locker_models.dart';

const int hourlyPrice = 10;
const String defaultOrganizationId = '';
const String defaultOrganizationName = 'No organization';
const String defaultOrganizationType = 'other';

Map<String, dynamic> safeMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

String readable(dynamic value, String fallback) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString();
  if (text.trim().isEmpty) {
    return fallback;
  }
  return text;
}

int toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String moneyText(num amount) => 'TL ${amount.round()}';

String signedMoneyText(num amount) {
  final rounded = amount.round();
  if (rounded < 0) {
    return '- TL ${rounded.abs()}';
  }
  return '+ TL $rounded';
}

// ESP32 expects compact uppercase RFID values without separators.
String normalizedRfidUid(dynamic value) {
  return readable(
    value,
    '',
  ).replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
}

bool isAdminRole(dynamic value) {
  final role = value?.toString().toLowerCase() ?? '';
  return role == 'admin' || role == 'organizationadmin';
}

String organizationIdOf(Map<String, dynamic> data) {
  return readable(data['organizationId'], defaultOrganizationId);
}

String organizationNameOf(Map<String, dynamic> data) {
  return readable(data['organizationName'], defaultOrganizationName);
}

String organizationTypeOf(Map<String, dynamic> data) {
  return readable(data['type'], defaultOrganizationType).toLowerCase();
}

bool isFreeOrganization(Map<String, dynamic> organization) {
  final type = organizationTypeOf(organization);
  return type == 'school' || type == 'gym';
}

int organizationHourlyPrice(Map<String, dynamic> organization) {
  if (isFreeOrganization(organization)) {
    return 0;
  }
  final value = toInt(organization['hourlyPrice']);
  return value <= 0 ? hourlyPrice : value;
}

String organizationLockerPath(String organizationId, String lockerKey) {
  return 'organizations/$organizationId/lockers/$lockerKey';
}

int lockerIdFromKey(String key) =>
    int.tryParse(key.replaceAll('locker', '')) ?? 0;

DateTime calculateEndDate(DateTime now, String plan, int duration) {
  if (plan == 'Hourly') {
    return now.add(Duration(hours: duration));
  }
  if (plan == 'Daily') {
    return now.add(Duration(days: duration));
  }
  return now.add(Duration(days: duration * 7));
}

String formatDate(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) {
    return '-';
  }
  try {
    final date = DateTime.parse(value.toString());
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return value.toString();
  }
}

String timeLeft(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) {
    return '-';
  }
  try {
    final end = DateTime.parse(value.toString());
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) {
      final late = DateTime.now().difference(end);
      if (late.inMinutes <= 15) {
        return 'Grace period: ${15 - late.inMinutes} min';
      }
      return 'Expired';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return '$days days $hours hours';
    }
    if (hours > 0) {
      return '$hours hours $minutes min';
    }
    return '$minutes min';
  } catch (_) {
    return '-';
  }
}

int minutesUntilPenalty(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) {
    return -1;
  }
  try {
    final end = DateTime.parse(value.toString());
    final penaltyStartsAt = end.add(const Duration(minutes: 15));
    return penaltyStartsAt.difference(DateTime.now()).inMinutes;
  } catch (_) {
    return -1;
  }
}

String unitForPlan(dynamic value) {
  final plan = value?.toString() ?? '';
  if (plan == 'Daily') {
    return 'days';
  }
  if (plan == 'Weekly') {
    return 'weeks';
  }
  return 'hours';
}

PenaltyInfo calculatePenalty(Map<String, dynamic> locker) {
  final rawEnd = locker['endsAt'];
  if (rawEnd == null || rawEnd.toString().trim().isEmpty) {
    return PenaltyInfo(amount: 0, periods: 0, description: 'No penalty');
  }
  try {
    final end = DateTime.parse(rawEnd.toString());
    final now = DateTime.now();
    if (now.isBefore(end)) {
      return PenaltyInfo(amount: 0, periods: 0, description: 'No penalty');
    }
    final lateMinutes = now.difference(end).inMinutes;
    if (lateMinutes <= 15) {
      return PenaltyInfo(
        amount: 0,
        periods: 0,
        description: 'Grace: ${15 - lateMinutes} min left',
      );
    }
    final chargeableMinutes = lateMinutes - 15;
    final periods = (chargeableMinutes / 15).ceil();
    final amount = periods * hourlyPrice;
    return PenaltyInfo(
      amount: amount,
      periods: periods,
      description: '$periods x 15 min = ${moneyText(amount)}',
    );
  } catch (_) {
    return PenaltyInfo(amount: 0, periods: 0, description: 'No penalty');
  }
}

MyLockerResult? findMyLocker(dynamic rawLockers, String userId) {
  if (rawLockers is! Map) {
    return null;
  }
  for (final entry in rawLockers.entries) {
    final data = safeMap(entry.value);
    if (data['ownerId'] == userId || data['ownerUid'] == userId) {
      return MyLockerResult(key: entry.key.toString(), data: data);
    }
  }
  return null;
}
