/// Zigzag-decodes a value. Arithmetic, not `~`: on the web `~` yields an
/// unsigned 32-bit result, which turns every negative delta into garbage.
int _unzigzag(int v) => (v & 1) != 0 ? -(v >> 1) - 1 : v >> 1;

/// Decodes a Google encoded polyline (precision 5) into (lat, lng) pairs.
List<({double lat, double lng})> decodePolyline(String encoded) {
  final points = <({double lat, double lng})>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += _unzigzag(result);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += _unzigzag(result);
    points.add((lat: lat / 1e5, lng: lng / 1e5));
  }
  return points;
}

/// Encodes (lat, lng) pairs as a Google encoded polyline (precision 5).
String encodePolyline(Iterable<({double lat, double lng})> pts) {
  final sb = StringBuffer();
  var pLat = 0, pLng = 0;
  void enc(int v) {
    var x = v < 0 ? -2 * v - 1 : 2 * v; // arithmetic zigzag; `~` is unsigned on the web
    while (x >= 0x20) {
      sb.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    sb.writeCharCode(x + 63);
  }

  for (final p in pts) {
    final lat = (p.lat * 1e5).round(), lng = (p.lng * 1e5).round();
    enc(lat - pLat);
    enc(lng - pLng);
    pLat = lat;
    pLng = lng;
  }
  return sb.toString();
}
