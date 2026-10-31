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

  test('snooze moves a week later, never earlier', () {
    expect(snoozeWeek(now, DateTime(2026, 10, 30)), DateTime(2026, 11, 7), reason: 'overdue: a week from today');
    expect(snoozeWeek(now, DateTime(2026, 10, 31)), DateTime(2026, 11, 7), reason: 'due today: a week from today');
    expect(snoozeWeek(now, DateTime(2026, 11, 20)), DateTime(2026, 11, 27), reason: 'future: a week after it was due');
  });

  test('day counts survive DST changes', () {
    // US spring-forward 2027-03-14 and fall-back 2026-11-01 are 23- and 25-hour days.
    expect(calendarDaysBetween(DateTime(2027, 3, 14), DateTime(2027, 3, 15)), 1);
    expect(calendarDaysBetween(DateTime(2027, 3, 15), DateTime(2027, 3, 13)), -2);
    expect(calendarDaysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
    expect(followUpDueLabel(DateTime(2027, 3, 15), DateTime(2027, 3, 14, 9)), 'Due tomorrow');
  });
}
