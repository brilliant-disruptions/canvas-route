import 'package:canvas_route/core/logic/weekend_digest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Week of Mon Nov 2 2026: Fri Nov 6, Sat Nov 7, Sun Nov 8.
  DigestListing sale(int day, int hour, [List<String> cats = const []]) => (opensAt: DateTime(2026, 11, day, hour), categories: cats);
  final weekend = [
    sale(7, 7, ['Furniture', 'Everything']),
    sale(7, 8, ['Furniture', 'Kids']),
    sale(8, 9, ['Tools']),
    sale(6, 16, ['Kids']), // Friday afternoon sale counts
    sale(14, 7, ['Furniture']), // next weekend: not this one
  ];
  String? title(DateTime now) => weekendDigest(weekend, now, noun: 'sale', wildcard: 'Everything')?.title;

  test('midweek: Friday 5:30pm about Fri–Sun', () {
    final r = weekendDigest(weekend, DateTime(2026, 11, 4, 12), noun: 'sale', wildcard: 'Everything')!;
    expect(r.at, DateTime(2026, 11, 6, 17, 30));
    expect(r.title, '4 sales this weekend near you');
    expect(r.body, '2 with furniture · first opens Fri 4pm · plan your morning in one tap');
    expect(r.notificationId, weekendDigestId);
  });

  test('Friday before 5:30 still schedules today\'s evening note', () {
    expect(weekendDigest(weekend, DateTime(2026, 11, 6, 9), noun: 'sale')!.at, DateTime(2026, 11, 6, 17, 30));
  });

  test('Friday evening and early Saturday switch to a Saturday 6:30am "today" note', () {
    final fri = weekendDigest(weekend, DateTime(2026, 11, 6, 20), noun: 'sale', wildcard: 'Everything')!;
    expect(fri.at, DateTime(2026, 11, 7, 6, 30));
    expect(fri.title, '2 sales near you today');
    expect(fri.body, startsWith('2 with furniture · first opens 7am'));
    expect(weekendDigest(weekend, DateTime(2026, 11, 7, 5), noun: 'sale')!.at, DateTime(2026, 11, 7, 6, 30));
  });

  test('later Saturday and Sunday look ahead to next weekend', () {
    final sat = weekendDigest(weekend, DateTime(2026, 11, 7, 10), noun: 'sale')!;
    expect(sat.at, DateTime(2026, 11, 13, 17, 30));
    expect(sat.title, '1 sale this weekend near you');
    expect(title(DateTime(2026, 11, 8, 12)), '1 sale this weekend near you');
  });

  test('nothing listed, nothing sent; a single sale names no category', () {
    expect(weekendDigest(const [], DateTime(2026, 11, 4), noun: 'sale'), isNull);
    final one = weekendDigest([sale(7, 7, ['Books'])], DateTime(2026, 11, 4), noun: 'sale')!;
    expect(one.body, 'first opens Sat 7am · plan your morning in one tap');
  });
}
