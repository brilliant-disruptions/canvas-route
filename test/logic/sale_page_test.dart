import 'package:canvas_route/core/logic/sale_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 9);
  PageListing at(String id, double dLat, {int day = 7, int open = 7, int close = 13}) =>
      (id: id, lat: 32.80 + dLat, lng: -96.79, opensAt: DateTime(2026, 11, day, open), closesAt: DateTime(2026, 11, day, close));
  final anchor = at('me', 0);

  test('same day, nearby, still on, nearest first', () {
    final ids = sameDayNearby(anchor, [
      at('far', 0.1), // ~7 mi
      at('near', 0.01),
      at('nearer', 0.005),
      at('next-week', 0.005, day: 14),
      at('over', 0.005, open: 6, close: 8),
      anchor,
    ], now);
    expect(ids, ['nearer', 'near']);
  });

  test('calendar link carries UTC times, place and details', () {
    final u = googleCalendarLink(
      title: 'Moving sale',
      start: DateTime.utc(2026, 11, 7, 13),
      end: DateTime.utc(2026, 11, 7, 19),
      location: '4431 Bryan St, Dallas, TX',
      details: 'https://canvasroute.app/s/abc',
    );
    expect(u.host, 'calendar.google.com');
    expect(u.queryParameters['action'], 'TEMPLATE');
    expect(u.queryParameters['dates'], '20261107T130000Z/20261107T190000Z');
    expect(u.queryParameters['location'], '4431 Bryan St, Dallas, TX');
  });

  test('no end time defaults to two hours', () {
    final u = googleCalendarLink(title: 'x', start: DateTime.utc(2026, 11, 7, 13));
    expect(u.queryParameters['dates'], '20261107T130000Z/20261107T150000Z');
    expect(u.queryParameters.containsKey('location'), isFalse);
  });
}
