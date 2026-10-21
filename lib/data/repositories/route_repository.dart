import '../models/business.dart';
import '../models/app_mode.dart';
import '../models/draft_stop.dart';
import '../models/route_model.dart';
import '../models/stop.dart';
import '../supabase_client.dart';

class RouteRepository {
  Future<List<RouteModel>> loadRoutes(String userId, AppMode mode) async {
    final routeRows = await sb
        .from('routes')
        .select()
        .eq('user_id', userId)
        .eq('mode', mode.id)
        .order('created_at', ascending: false);
    if (routeRows.isEmpty) return const [];
    final ids = routeRows.map((r) => r['id'] as String).toList();
    final stopRows = await sb.from('stops').select().inFilter('route_id', ids).order('stop_order');
    final byRoute = <String, List<Stop>>{};
    for (final s in stopRows) {
      byRoute.putIfAbsent(s['route_id'] as String, () => []).add(Stop.fromRow(s));
    }
    return routeRows.map((r) => RouteModel.fromRow(r, byRoute[r['id']] ?? const [])).toList();
  }

  Future<RouteModel?> byId(String id) async {
    final r = await sb.from('routes').select().eq('id', id).maybeSingle();
    if (r == null) return null;
    final stops = await sb.from('stops').select().eq('route_id', id).order('stop_order');
    return RouteModel.fromRow(r, stops.map(Stop.fromRow).toList());
  }

  Map<String, dynamic> _stopInsert(String routeId, DraftStop d, int i) => {
        'route_id': routeId,
        'place_id': d.business.placeId,
        'pin_id': d.business.pinId,
        'source': d.business.source.id,
        'name': d.business.name,
        'address': d.business.address,
        'lat': d.business.lat,
        'lng': d.business.lng,
        'stop_order': i,
        'visited': false,
        'opens_at': d.business.opensAt?.toUtc().toIso8601String(),
        'closes_at': d.business.closesAt?.toUtc().toIso8601String(),
        'listing_url': d.business.listingUrl,
      };

  Future<RouteModel> create({
    required String userId,
    required AppMode mode,
    required String name,
    required List<DraftStop> stops,
    bool isOptimized = false,
    String? forkedFrom,
  }) async {
    final routeRow = await sb
        .from('routes')
        .insert({
          'user_id': userId,
          'mode': mode.id,
          'name': name,
          'stop_count': stops.length,
          'is_optimized': isOptimized,
          'status': 'not_started',
          'forked_from': forkedFrom,
        })
        .select()
        .single();
    final id = routeRow['id'] as String;
    final stopRows = await sb
        .from('stops')
        .insert([for (var i = 0; i < stops.length; i++) _stopInsert(id, stops[i], i)])
        .select()
        .order('stop_order');
    return RouteModel.fromRow(routeRow, stopRows.map(Stop.fromRow).toList());
  }

  Future<RouteModel> replaceStops(RouteModel route, String name, List<DraftStop> stops, {bool isOptimized = true}) async {
    await sb.from('routes').update({
      'name': name,
      'stop_count': stops.length,
      'status': 'updated',
      'is_optimized': isOptimized,
    }).eq('id', route.id);
    await sb.from('stops').delete().eq('route_id', route.id);
    final stopRows = await sb
        .from('stops')
        .insert([for (var i = 0; i < stops.length; i++) _stopInsert(route.id, stops[i], i)])
        .select()
        .order('stop_order');
    return route.copyWith(
      name: name,
      stops: stopRows.map(Stop.fromRow).toList(),
      isOptimized: isOptimized,
      status: RouteStatus.updated,
    );
  }

  Future<void> rename(String routeId, String name) => sb.from('routes').update({'name': name}).eq('id', routeId);

  Future<void> delete(String routeId) => sb.from('routes').delete().eq('id', routeId);

  Future<RouteModel> duplicate(RouteModel source, String userId) => create(
        userId: userId,
        mode: source.mode,
        name: '${source.name} (copy)',
        isOptimized: source.isOptimized,
        stops: source.stops
            .map((s) => DraftStop(
                  id: s.id,
                  business: _businessFromStop(s),
                ))
            .toList(),
      );

  Future<void> setStatus(String routeId, RouteStatus status) async {
    final patch = <String, dynamic>{'status': status.id};
    if (status == RouteStatus.inProgress) patch['last_run_at'] = DateTime.now().toUtc().toIso8601String();
    await sb.from('routes').update(patch).eq('id', routeId);
  }

  Future<void> reorder(List<Stop> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].stopOrder != i) {
        await sb.from('stops').update({'stop_order': i}).eq('id', ordered[i].id);
      }
    }
  }

  Future<void> markVisited(String stopId, {bool visited = true}) =>
      sb.from('stops').update({'visited': visited}).eq('id', stopId);

  Future<void> resetVisits(String routeId) async {
    await sb.from('stops').update({'visited': false}).eq('route_id', routeId);
    await sb.from('visits').delete().eq('route_id', routeId);
  }

  Future<void> renameStop(String stopId, String name) => sb.from('stops').update({'name': name}).eq('id', stopId);
}

// Kept here so DraftStop → Stop → DraftStop round-trips in one place.
Business _businessFromStop(Stop s) => s.toBusiness();
