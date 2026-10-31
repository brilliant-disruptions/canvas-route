import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/env.dart';
import '../models/directions.dart';

class DirectionsException implements Exception {
  DirectionsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google Routes API (computeRoutes). Mirrors the v2 origin/destination semantics:
///  - origin + destination + optimize → all [waypoints] reorderable
///  - origin + optimize → last waypoint is destination, rest reorderable
///  - otherwise → first/last pinned, middle reorderable
///
/// Billing: up to 10 intermediates without optimization or traffic bills as Routes
/// Essentials; more stops or `optimize` bills as Pro. Yard-sale days are ordered by
/// closing time on the device, so they never ask Google to optimize.
class DirectionsService {
  DirectionsService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? Env.googleMapsApiKey;
  final http.Client _client;
  final String _apiKey;
  static const _url = 'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const maxWaypoints = 25;
  static const _fields = 'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,'
      'routes.legs.distanceMeters,routes.legs.duration,routes.optimizedIntermediateWaypointIndex';

  Future<DirectionsResult> route(
    List<Waypoint> waypoints, {
    bool optimize = false,
    Waypoint? origin,
    Waypoint? destination,
  }) async {
    if (_apiKey.isEmpty) throw DirectionsException('GOOGLE_MAPS_API_KEY is not set');
    if (waypoints.length < 2 && origin == null) throw DirectionsException('At least two waypoints are required');
    if (waypoints.length > maxWaypoints) throw DirectionsException('Routes support up to $maxWaypoints stops');

    final Waypoint o, d;
    final List<Waypoint> mids;
    if (origin != null && destination != null && optimize) {
      o = origin;
      d = destination;
      mids = waypoints;
    } else if (origin != null) {
      o = origin;
      d = waypoints.last;
      mids = waypoints.sublist(0, waypoints.length - 1);
    } else {
      o = waypoints.first;
      d = waypoints.last;
      mids = waypoints.sublist(1, waypoints.length - 1);
    }

    final body = {
      'origin': _loc(o),
      'destination': _loc(d),
      if (mids.isNotEmpty) 'intermediates': [for (final w in mids) _loc(w)],
      'travelMode': 'DRIVE',
      if (optimize && mids.length > 1) 'optimizeWaypointOrder': true,
    };
    final res = await _client.post(
      Uri.parse(_url),
      headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': _apiKey, 'X-Goog-FieldMask': _fields},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw DirectionsException('Routes API error ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final routes = data['routes'] as List? ?? const [];
    if (routes.isEmpty) throw DirectionsException('No drivable route between these stops');
    final r = routes.first as Map<String, dynamic>;
    // Proto3 JSON omits zero values, so a zero-length leg has no distance at all.
    final legs = (r['legs'] as List? ?? const []).cast<Map<String, dynamic>>();
    final legSeconds = [for (final l in legs) _seconds(l['duration'])];
    final order = (r['optimizedIntermediateWaypointIndex'] as List?)?.map((e) => (e as num).toInt()).toList();
    return DirectionsResult(
      encodedPolyline: (r['polyline'] as Map?)?['encodedPolyline'] as String? ?? '',
      totalDistanceMeters: (r['distanceMeters'] as num?)?.toInt() ??
          legs.fold(0, (s, l) => s + ((l['distanceMeters'] as num?)?.toInt() ?? 0)),
      totalDurationSeconds: r['duration'] == null ? legSeconds.fold(0, (a, b) => a + b) : _seconds(r['duration']),
      legDurationSeconds: legSeconds,
      // Routes returns [-1] when there was nothing to reorder.
      optimizedOrder: optimize && order != null && !order.contains(-1)
          ? order
          : (optimize ? [for (var i = 0; i < mids.length; i++) i] : null),
    );
  }

  static Map<String, dynamic> _loc(Waypoint w) => {
        'location': {
          'latLng': {'latitude': w.lat, 'longitude': w.lng},
        },
      };

  /// "754s" → 754.
  static int _seconds(Object? v) => v is String ? (double.tryParse(v.replaceAll('s', '')) ?? 0).round() : 0;
}
