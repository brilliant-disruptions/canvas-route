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

  test('empty string decodes to no points', () {
    expect(decodePolyline(''), isEmpty);
  });
}
