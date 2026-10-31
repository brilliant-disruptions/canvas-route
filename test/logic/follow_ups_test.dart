import 'package:canvas_route/core/logic/follow_ups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 16, 30); // Saturday afternoon

  test('buckets by calendar day, not by hours', () {
    expect(followUpBucket(DateTime(2026, 10, 30), now), FollowUpBucket.overdue);
    expect(followUpBucket(DateTime(2026, 10, 31), now), FollowUpBucket.today);
    expect(followUpBucket(DateTime(2026, 10, 31, 23, 59), now), FollowUpBucket.today);
    expect(followUpBucket(DateTime(2026, 11, 1), now), FollowUpBucket.thisWeek);
    expect(followUpBucket(DateTime(2026, 11, 6), now), FollowUpBucket.thisWeek);
    expect(followUpBucket(DateTime(2026, 11, 7), now), FollowUpBucket.later);
  });

  test('due labels read naturally', () {
    expect(followUpDueLabel(DateTime(2026, 10, 30), now), '1 day overdue');
    expect(followUpDueLabel(DateTime(2026, 10, 27), now), '4 days overdue');
    expect(followUpDueLabel(DateTime(2026, 10, 31), now), 'Due today');
    expect(followUpDueLabel(DateTime(2026, 11, 1), now), 'Due tomorrow');
    expect(followUpDueLabel(DateTime(2026, 11, 5), now), 'Due Thu');
    expect(followUpDueLabel(DateTime(2026, 11, 14), now), 'Due Nov 14');
  });

  test('snooze lands a week out at midnight, across DST', () {
    expect(snoozeWeek(now), DateTime(2026, 11, 7));
  });
}
