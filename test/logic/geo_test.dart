import 'package:canvas_route/core/logic/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('haversine: Dallas to Fort Worth is about 50 km', () {
    final m = haversineMeters(32.7767, -96.7970, 32.7555, -97.3308);
    expect(m, closeTo(50000, 2500));
  });

  test('formatting', () {
    expect(formatDistance(50), '50 m');
    expect(formatDistance(1609.344 * 2.5), '2.5 mi');
    expect(formatDistance(1609.344 * 12), '12 mi');
    expect(formatDuration(540), '9 min');
    expect(formatDuration(3660), '1h 01m');
  });
}
