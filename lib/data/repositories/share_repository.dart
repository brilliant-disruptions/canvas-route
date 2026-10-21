import '../../core/env.dart';
import '../models/stop.dart';
import '../supabase_client.dart';

class SharedRoute {
  const SharedRoute({required this.name, required this.mode, required this.stops, required this.canFork, this.ownerHandle});
  final String name;
  final String mode;
  final List<Stop> stops;
  final bool canFork;
  final String? ownerHandle;
}

class ShareRepository {
  Future<String> createLink(String routeId) async {
    final existing = await sb.from('route_shares').select('token').eq('route_id', routeId).maybeSingle();
    final token = existing?['token'] as String? ??
        (await sb.from('route_shares').insert({'route_id': routeId}).select('token').single())['token'] as String;
    return '${Env.webOrigin}/r/$token';
  }

  Future<SharedRoute?> fetch(String token) async {
    final json = await sb.rpc('shared_route', params: {'p_token': token});
    if (json == null) return null;
    final m = Map<String, dynamic>.from(json as Map);
    final route = Map<String, dynamic>.from(m['route'] as Map);
    return SharedRoute(
      name: route['name'] as String,
      mode: route['mode'] as String,
      stops: (m['stops'] as List).map((s) => Stop.fromRow(Map<String, dynamic>.from(s as Map))).toList(),
      canFork: m['can_fork'] as bool? ?? true,
      ownerHandle: m['owner_handle'] as String?,
    );
  }
}
