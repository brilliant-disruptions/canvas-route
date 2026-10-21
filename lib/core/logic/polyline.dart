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
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    points.add((lat: lat / 1e5, lng: lng / 1e5));
  }
  return points;
}
