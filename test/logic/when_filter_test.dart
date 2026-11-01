import 'package:canvas_route/core/logic/when_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> labels(DateTime now) => whenOptions(now).map((o) => o.label).toList();

  test('a weekday offers this weekend and next Saturday', () {
    final wed = DateTime(2026, 11, 4, 18);
    expect(labels(wed), ['Open now', 'Any day', 'Sat 11/7', 'Sun 11/8', 'Next Sat']);
    expect(whenOptions(wed)[4].day, DateTime(2026, 11, 14));
  });

  test("on a Sunday, today's sales come first instead of hiding behind next week", () {
    final sun = DateTime(2026, 11, 1, 8);
    expect(labels(sun), ['Open now', 'Any day', 'Today', 'Next Sat', 'Next Sun']);
    expect(whenOptions(sun)[2].day, DateTime(2026, 11, 1));
    expect(whenOptions(sun)[3].day, DateTime(2026, 11, 7));
  });

  test('on a Saturday: today, tomorrow, next Saturday', () {
    final sat = DateTime(2026, 10, 31, 7);
    expect(labels(sat), ['Open now', 'Any day', 'Today', 'Tomorrow', 'Next Sat']);
  });

  test('across the fall-back weekend, days stay on midnight', () {
    // US DST ends Sunday Nov 1, 2026; dayPlus keeps calendar days.
    final fri = DateTime(2026, 10, 30, 23);
    for (final o in whenOptions(fri).skip(2)) {
      expect((o.day!.hour, o.day!.minute), (0, 0));
    }
  });

  test('the chip label follows the selection', () {
    final wed = DateTime(2026, 11, 4, 18);
    expect(whenLabel(openNow: true, now: wed), 'Open now');
    expect(whenLabel(openNow: false, now: wed), 'Any day');
    expect(whenLabel(openNow: false, day: DateTime(2026, 11, 8), now: wed), 'Sun 11/8');
    // Picked last week, no longer in the menu.
    expect(whenLabel(openNow: false, day: DateTime(2026, 10, 24), now: wed), '10/24');
  });

  test('exactly one option is selected', () {
    final wed = DateTime(2026, 11, 4, 18);
    for (final (openNow, day) in [(true, null), (false, null), (false, DateTime(2026, 11, 7))]) {
      expect(whenOptions(wed).where((o) => whenSelected(o, openNow: openNow, day: day)), hasLength(1));
    }
  });
}
