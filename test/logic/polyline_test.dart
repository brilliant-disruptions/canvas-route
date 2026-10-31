import 'package:canvas_route/core/logic/polyline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the Google reference polyline', () {
    // From Google's Encoded Polyline Algorithm Format docs.
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].lat, closeTo(38.5, 1e-5));
    expect(pts[0].lng, closeTo(-120.2, 1e-5));
    expect(pts[1].lat, closeTo(40.7, 1e-5));
    expect(pts[1].lng, closeTo(-120.95, 1e-5));
    expect(pts[2].lat, closeTo(43.252, 1e-5));
    expect(pts[2].lng, closeTo(-126.453, 1e-5));
  });

  test('negative deltas decode correctly (regression: `~` is unsigned on web)', () {
    // Dallas → one block west → one block south; both deltas negative.
    final pts = decodePolyline(r'o~ggEnhwmQ?jHjH?');
    expect(pts.length, 3);
    expect(pts[1].lng, lessThan(pts[0].lng));
    expect(pts[2].lat, lessThan(pts[1].lat));
    for (final p in pts) {
      expect(p.lat, inInclusiveRange(32, 34));
      expect(p.lng, inInclusiveRange(-98, -96));
    }
  });

  test('empty string decodes to no points', () {
    expect(decodePolyline(''), isEmpty);
  });

  test('encode round-trips through decode, including negative deltas', () {
    const pts = [(lat: 32.7767, lng: -96.797), (lat: 32.7555, lng: -97.3308), (lat: 33.0, lng: -96.5)];
    final back = decodePolyline(encodePolyline(pts));
    expect(back, hasLength(3));
    for (var i = 0; i < pts.length; i++) {
      expect(back[i].lat, closeTo(pts[i].lat, 1e-5));
      expect(back[i].lng, closeTo(pts[i].lng, 1e-5));
    }
  });
}
