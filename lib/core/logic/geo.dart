import 'dart:math';

const double _earthRadiusMeters = 6371000;

/// Great-circle distance in meters.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return _earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double metersToMiles(double m) => m / 1609.344;

String formatDistance(double meters) {
  final mi = metersToMiles(meters);
  if (mi < 0.1) return '${meters.round()} m';
  return '${mi.toStringAsFixed(mi < 10 ? 1 : 0)} mi';
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
