import 'package:canvas_route/core/logic/check_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 9);
  const lat = 32.8000, lng = -96.8000;
  CheckInListing sale(String id, double dLat, {int open = 7, int close = 13}) =>
      (id: id, lat: lat + dLat, lng: lng, opensAt: DateTime(2026, 11, 7, open), closesAt: DateTime(2026, 11, 7, close));

  test('picks the open sale you are standing at', () {
    expect(checkInCandidate([sale('far', 0.01), sale('here', 0.0003)], lat, lng, now), 'here'); // ~33 m vs ~1.1 km
  });

  test('ignores sales not open yet or already closed', () {
    expect(checkInCandidate([sale('later', 0.0002, open: 10), sale('done', 0.0002, open: 6, close: 9)], lat, lng, now), isNull);
  });

  test('driving past at 300 m does not count', () {
    expect(checkInCandidate([sale('street', 0.0027)], lat, lng, now), isNull);
  });

  test('nearest wins when two are close', () {
    expect(checkInCandidate([sale('a', 0.0008), sale('b', 0.0004)], lat, lng, now), 'b');
  });

  test('dismissals are per sale per day', () {
    expect(checkInKey('p1', now), 'p1@2026-11-7');
    expect(checkInKey('p1', now.add(const Duration(days: 1))), isNot(checkInKey('p1', now)));
  });
}
