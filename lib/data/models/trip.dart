import 'json_utils.dart';

/// One run of a route, for the mileage log.
class Trip {
  const Trip({
    required this.id,
    required this.routeName,
    required this.day,
    required this.distanceMeters,
    required this.stopsVisited,
    this.routeId,
    this.estimated = false,
  });

  final String id;
  final String? routeId;
  final String routeName;
  final DateTime day;
  final int distanceMeters;
  final int stopsVisited;
  final bool estimated;

  factory Trip.fromRow(Map<String, dynamic> r) => Trip(
        id: r['id'] as String,
        routeId: r['route_id'] as String?,
        routeName: r['route_name'] as String,
        day: DateTime.parse(r['day'] as String),
        distanceMeters: intOr(r['distance_m'], 0),
        stopsVisited: intOr(r['stops_visited'], 0),
        estimated: r['estimated'] as bool? ?? false,
      );

  static Map<String, dynamic> insert({
    required String userId,
    required String routeId,
    required String mode,
    required String routeName,
    required DateTime day,
    required int distanceMeters,
    required int stopsVisited,
    required bool estimated,
  }) => {
        'user_id': userId,
        'route_id': routeId,
        'mode': mode,
        'route_name': routeName,
        'day': dateOnly(day),
        'distance_m': distanceMeters,
        'stops_visited': stopsVisited,
        'estimated': estimated,
      };
}
