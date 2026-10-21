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

/// Google Directions. Mirrors the v2 origin/destination semantics:
///  - origin + destination + optimize → all [waypoints] reorderable
///  - origin + optimize → last waypoint is destination, rest reorderable
///  - otherwise → first/last pinned, middle reorderable
class DirectionsService {
  DirectionsService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _url = 'https://maps.googleapis.com/maps/api/directions/json';
  static const maxWaypoints = 25;

  Future<DirectionsResult> route(
    List<Waypoint> waypoints, {
    bool optimize = false,
    Waypoint? origin,
    Waypoint? destination,
  }) async {
    if (!Env.hasGoogleKey) throw DirectionsException('GOOGLE_MAPS_API_KEY is not set');
    if (waypoints.length < 2 && origin == null) throw DirectionsException('At least two waypoints are required');
    if (waypoints.length > maxWaypoints) throw DirectionsException('Routes support up to $maxWaypoints stops');

    final String o, d;
    final List<Waypoint> mids;
    if (origin != null && destination != null && optimize) {
      o = origin.param;
      d = destination.param;
      mids = waypoints;
    } else if (origin != null && optimize) {
      o = origin.param;
      d = waypoints.last.param;
      mids = waypoints.sublist(0, waypoints.length - 1);
    } else if (origin != null) {
      o = origin.param;
      d = waypoints.last.param;
      mids = waypoints.sublist(0, waypoints.length - 1);
    } else {
      o = waypoints.first.param;
      d = waypoints.last.param;
      mids = waypoints.sublist(1, waypoints.length - 1);
    }

    final params = {'origin': o, 'destination': d, 'mode': 'driving', 'key': Env.googleMapsApiKey};
    if (mids.isNotEmpty) {
      params['waypoints'] = '${optimize ? 'optimize:true|' : ''}${mids.map((w) => w.param).join('|')}';
    }
    final res = await _client.get(Uri.parse(_url).replace(queryParameters: params));
    if (res.statusCode != 200) throw DirectionsException('Directions API error ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') throw DirectionsException('Directions API: ${data['status']}');
    final r = (data['routes'] as List).first as Map<String, dynamic>;
    final legs = (r['legs'] as List).cast<Map<String, dynamic>>();
    return DirectionsResult(
      encodedPolyline: r['overview_polyline']['points'] as String,
      totalDistanceMeters: legs.fold(0, (s, l) => s + (l['distance']['value'] as num).toInt()),
      totalDurationSeconds: legs.fold(0, (s, l) => s + (l['duration']['value'] as num).toInt()),
      legDurationSeconds: legs.map((l) => (l['duration']['value'] as num).toInt()).toList(),
      optimizedOrder: (r['waypoint_order'] as List?)?.map((e) => (e as num).toInt()).toList(),
    );
  }
}
