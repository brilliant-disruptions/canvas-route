class Waypoint {
  const Waypoint(this.lat, this.lng);
  final double lat;
  final double lng;
  String get param => '$lat,$lng';
}

class DirectionsResult {
  const DirectionsResult({
    required this.encodedPolyline,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.legDurationSeconds,
    this.optimizedOrder,
    this.estimated = false,
  });

  final String encodedPolyline;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final List<int> legDurationSeconds;

  /// Present only when optimize was requested; indexes into the intermediates.
  final List<int>? optimizedOrder;

  /// Computed on the device from straight-line distance, not by Google.
  final bool estimated;
}
