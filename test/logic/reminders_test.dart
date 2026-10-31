import 'package:canvas_route/core/logic/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 9); // after today's 8:30

  ReminderSource f(String id, DateTime due) => (id: id, title: 'Follow up: $id', body: '', due: due);

  test('schedules 8:30 on the due day, skips times already past, soonest first', () {
    final plan = planFollowUpReminders([
      f('later', DateTime(2026, 11, 9)),
      f('today', DateTime(2026, 10, 31)),
      f('overdue', DateTime(2026, 10, 28)),
      f('tomorrow', DateTime(2026, 11, 1)),
    ], now);
    expect(plan.map((p) => p.title), ['Follow up: tomorrow', 'Follow up: later']);
    expect(plan.first.at, DateTime(2026, 11, 1, 8, 30));
  });

  test('today still gets a reminder before 8:30', () {
    final plan = planFollowUpReminders([f('today', DateTime(2026, 10, 31))], DateTime(2026, 10, 31, 7));
    expect(plan.single.at, DateTime(2026, 10, 31, 8, 30));
  });

  test('ids are stable, positive and distinct', () {
    expect(reminderId('visit-1'), reminderId('visit-1'));
    expect(reminderId('visit-1'), isNot(reminderId('visit-2')));
    expect(reminderId('x'), greaterThanOrEqualTo(0));
  });

  test('caps pending reminders under the iOS limit', () {
    final many = [for (var i = 0; i < 80; i++) f('v$i', DateTime(2026, 11, 1).add(Duration(days: i)))];
    expect(planFollowUpReminders(many, now), hasLength(maxPendingReminders));
  });
}
