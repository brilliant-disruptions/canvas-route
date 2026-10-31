import '../../core/logic/geo.dart';
import '../../core/logic/polyline.dart';
import '../models/directions.dart';
import 'directions_service.dart';

/// Free, offline drive estimates: straight-line distance × a road factor at city
/// speed plus a parking minute, drawn on a city-grid dogleg. Orders by nearest
/// neighbor when asked to optimize. Good enough to plan a morning of yard sales;
/// the turn-by-turn drive is handed to the phone's maps app anyway.
class EstimateDirectionsService implements DirectionsService {
  static const roadFactor = 1.3;
  static const metersPerSecond = 11.0; // ~25 mph
  static const parkSeconds = 90;

  static double _m(Waypoint a, Waypoint b) => haversineMeters(a.lat, a.lng, b.lat, b.lng) * roadFactor;
  static int _sec(double meters) => (meters / metersPerSecond + parkSeconds).round();

  @override
  Future<DirectionsResult> route(
    List<Waypoint> waypoints, {
    bool optimize = false,
    Waypoint? origin,
    Waypoint? destination,
  }) async {
    if (waypoints.length < 2 && origin == null) throw DirectionsException('At least two waypoints are required');
    if (waypoints.length > DirectionsService.maxWaypoints) {
      throw DirectionsException('Routes support up to ${DirectionsService.maxWaypoints} stops');
    }
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
    var order = [for (var i = 0; i < mids.length; i++) i];
    if (optimize && mids.length > 1) {
      final left = {...order};
      order = [];
      var cur = o;
      while (left.isNotEmpty) {
        final next = left.reduce((a, b) => _m(cur, mids[a]) <= _m(cur, mids[b]) ? a : b);
        order.add(next);
        left.remove(next);
        cur = mids[next];
      }
    }
    final pts = [o, for (final i in order) mids[i], d];
    final legs = [for (var i = 1; i < pts.length; i++) _m(pts[i - 1], pts[i])];
    final road = <({double lat, double lng})>[];
    for (var i = 0; i < pts.length; i++) {
      if (i > 0) road.add((lat: pts[i - 1].lat, lng: pts[i].lng));
      road.add((lat: pts[i].lat, lng: pts[i].lng));
    }
    return DirectionsResult(
      encodedPolyline: encodePolyline(road),
      totalDistanceMeters: legs.fold(0.0, (s, x) => s + x).round(),
      totalDurationSeconds: legs.fold(0, (s, x) => s + _sec(x)),
      legDurationSeconds: [for (final l in legs) _sec(l)],
      optimizedOrder: optimize ? order : null,
      estimated: true,
    );
  }
}

/// Google first, free estimate when Google can't answer (no key, daily quota hit,
/// offline). Repeat requests in a session are answered from memory, so reordering
/// in the builder or reopening a route doesn't bill twice.
class FallbackDirectionsService implements DirectionsService {
  FallbackDirectionsService({DirectionsService? primary, DirectionsService? fallback})
    : _primary = primary ?? DirectionsService(),
      _fallback = fallback ?? EstimateDirectionsService();
  final DirectionsService _primary;
  final DirectionsService _fallback;
  final _cache = <String, DirectionsResult>{};
  static const _cacheSize = 50;

  /// Coordinates rounded to ~10 m for stops and ~100 m for where you are now.
  static String _key(List<Waypoint> w, bool optimize, Waypoint? o, Waypoint? d) {
    String p(Waypoint x, int digits) => '${x.lat.toStringAsFixed(digits)},${x.lng.toStringAsFixed(digits)}';
    return [optimize, o == null ? '-' : p(o, 3), d == null ? '-' : p(d, 3), ...w.map((x) => p(x, 4))].join('|');
  }

  @override
  Future<DirectionsResult> route(
    List<Waypoint> waypoints, {
    bool optimize = false,
    Waypoint? origin,
    Waypoint? destination,
  }) async {
    final key = _key(waypoints, optimize, origin, destination);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    DirectionsResult r;
    try {
      r = await _primary.route(waypoints, optimize: optimize, origin: origin, destination: destination);
    } on Exception {
      // Bad input fails the same way locally, so the caller still sees the real reason.
      return _fallback.route(waypoints, optimize: optimize, origin: origin, destination: destination);
    }
    _cache[key] = r;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return r;
  }
}
