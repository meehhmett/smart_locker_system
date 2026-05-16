import 'package:flutter_test/flutter_test.dart';
import 'package:smart_locker_app/core/utils/locker_utils.dart';

void main() {
  test('locker helpers parse locker keys and durations', () {
    expect(lockerIdFromKey('locker12'), 12);
    expect(unitForPlan('Daily'), 'days');
    expect(unitForPlan('Weekly'), 'weeks');
    expect(unitForPlan('Hourly'), 'hours');
  });
}
