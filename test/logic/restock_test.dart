import 'package:canvas_route/core/logic/restock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tiers by hit count', () {
    expect(tierForHits(0), RestockTier.unknown);
    expect(tierForHits(2), RestockTier.unknown);
    expect(tierForHits(3), RestockTier.emerging);
    expect(tierForHits(9), RestockTier.emerging);
    expect(tierForHits(10), RestockTier.established);
  });

  test('describes a window in local copy', () {
    expect(describeWindow(dow: 2, hour: 8, hits: 23), 'Tue 8–10am · 23 reports');
    expect(describeWindow(dow: 6, hour: 11, hits: 1), 'Sat 11am–1pm · 1 report');
  });

  test('windowOnDay picks the strongest window for that weekday', () {
    final sat = DateTime(2026, 10, 24);
    final w = windowOnDay([(dow: 6, hour: 8, hits: 4), (dow: 6, hour: 14, hits: 9), (dow: 2, hour: 8, hits: 30)], sat);
    expect(w!.start, DateTime(2026, 10, 24, 14));
    expect(w.end, DateTime(2026, 10, 24, 16));
    expect(windowOnDay([(dow: 2, hour: 8, hits: 30)], sat), isNull);
  });

  test('freshness and relative age', () {
    final now = DateTime(2026, 10, 24, 10);
    expect(isFresh(now.subtract(const Duration(minutes: 10)), now: now), isTrue);
    expect(isFresh(now.subtract(const Duration(minutes: 40)), now: now), isFalse);
    expect(relativeAge(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(relativeAge(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(relativeAge(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(relativeAge(now.subtract(const Duration(days: 2)), now: now), '2d ago');
  });

  group('nextLikelyWindow', () {
    final sat9 = DateTime(2026, 10, 31, 9); // Saturday
    test('picks the soonest window, including one in progress', () {
      final w = nextLikelyWindow([(dow: 2, hour: 8, hits: 9), (dow: 6, hour: 8, hits: 3)], sat9);
      expect(w!.start, DateTime(2026, 10, 31, 8)); // Sat 8–10am is still open at 9
      expect(untilLabel(w.start, sat9), 'now');
    });
    test('rolls to next week once today\'s window has passed', () {
      final w = nextLikelyWindow([(dow: 6, hour: 6, hits: 3)], sat9);
      expect(w!.start, DateTime(2026, 11, 7, 6));
      expect(untilLabel(w.start, sat9), 'in 7 days');
    });
    test('a one-off sighting does not outrank an established window', () {
      final w = nextLikelyWindow([(dow: 2, hour: 8, hits: 12), (dow: 6, hour: 9, hits: 1)], sat9);
      expect(w!.start, DateTime(2026, 11, 3, 8)); // next Tuesday, not this morning's single report
    });
    test('labels', () {
      expect(untilLabel(sat9.add(const Duration(minutes: 45)), sat9), 'in 45 min');
      expect(untilLabel(sat9.add(const Duration(hours: 5)), sat9), 'in 5h');
      expect(untilLabel(DateTime(2026, 11, 1, 8), sat9), 'tomorrow');
      expect(nextLikelyWindow(const [], sat9), isNull);
    });
  });
}
