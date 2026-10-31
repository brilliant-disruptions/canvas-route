import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/directions.dart';
import '../data/models/draft_stop.dart';
import '../data/models/route_model.dart';
import '../data/models/stop.dart';
import 'auth_state.dart';
import 'profile_state.dart';
import 'providers.dart';
import 'visits_state.dart';

class RoutesNotifier extends AsyncNotifier<List<RouteModel>> {
  @override
  Future<List<RouteModel>> build() async {
    final uid = ref.watch(currentUserIdProvider);
    final mode = ref.watch(activeModeProvider);
    if (uid == null) return const [];
    return ref.read(routeRepoProvider).loadRoutes(uid, mode);
  }

  List<RouteModel> get _list => state.value ?? const [];
  RouteModel? byId(String id) => _list.where((r) => r.id == id).firstOrNull;

  void _put(RouteModel r) {
    final list = [..._list];
    final i = list.indexWhere((x) => x.id == r.id);
    if (i == -1) {
      list.insert(0, r);
    } else {
      list[i] = r;
    }
    state = AsyncData(list);
  }

  Future<RouteModel> save(String name, List<DraftStop> drafts, {bool isOptimized = false, String? forkedFrom}) async {
    final uid = ref.read(currentUserIdProvider)!;
    final mode = ref.read(activeModeProvider);
    final r = await ref.read(routeRepoProvider).create(
          userId: uid,
          mode: mode,
          name: name,
          stops: drafts,
          isOptimized: isOptimized,
          forkedFrom: forkedFrom,
        );
    _put(r);
    return r;
  }

  Future<RouteModel> replaceStops(String routeId, String name, List<DraftStop> drafts, {bool isOptimized = true}) async {
    final existing = byId(routeId) ?? (await ref.read(routeRepoProvider).byId(routeId))!;
    final r = await ref.read(routeRepoProvider).replaceStops(existing, name, drafts, isOptimized: isOptimized);
    _put(r);
    return r;
  }

  Future<void> rename(String id, String name) async {
    await ref.read(routeRepoProvider).rename(id, name);
    final r = byId(id);
    if (r != null) _put(r.copyWith(name: name));
  }

  Future<void> delete(String id) async {
    await ref.read(routeRepoProvider).delete(id);
    state = AsyncData(_list.where((r) => r.id != id).toList());
  }

  Future<RouteModel> duplicate(String id) async {
    final src = byId(id)!;
    final r = await ref.read(routeRepoProvider).duplicate(src, ref.read(currentUserIdProvider)!);
    _put(r);
    return r;
  }

  Future<void> setStatus(String id, RouteStatus status) async {
    await ref.read(routeRepoProvider).setStatus(id, status);
    final r = byId(id);
    if (r != null) {
      _put(r.copyWith(status: status, lastRunAt: status == RouteStatus.inProgress ? DateTime.now() : null));
    }
  }

  Future<void> markVisited(String routeId, String stopId, {bool visited = true}) async {
    await ref.read(routeRepoProvider).markVisited(stopId, visited: visited);
    final r = byId(routeId);
    if (r == null) return;
    final stops = r.stops.map((s) => s.id == stopId ? s.copyWith(visited: visited) : s).toList();
    final allDone = stops.every((s) => s.visited);
    _put(r.copyWith(stops: stops, status: allDone ? RouteStatus.complete : r.status));
    if (allDone) await ref.read(routeRepoProvider).setStatus(routeId, RouteStatus.complete);
  }

  Future<void> restart(String routeId) async {
    await ref.read(routeRepoProvider).resetVisits(routeId);
    ref.invalidate(allVisitsProvider); // the deleted visits' follow-ups go too
    final r = byId(routeId);
    if (r != null) {
      _put(r.copyWith(stops: r.stops.map((s) => s.copyWith(visited: false)).toList(), status: RouteStatus.inProgress));
    }
  }

  Future<void> renameStop(String routeId, String stopId, String name) async {
    await ref.read(routeRepoProvider).renameStop(stopId, name);
    final r = byId(routeId);
    if (r != null) _put(r.copyWith(stops: r.stops.map((s) => s.id == stopId ? s.copyWith(name: name) : s).toList()));
  }

  /// Re-optimizes unvisited stops (or all) from the user's location to [destination].
  Future<void> optimize(String routeId, {required bool fromBeginning, required Waypoint destination}) async {
    final route = byId(routeId);
    if (route == null || route.stops.length < 2) return;
    final visited = fromBeginning ? <Stop>[] : route.stops.where((s) => s.visited).toList();
    final candidates = fromBeginning ? [...route.stops] : route.stops.where((s) => !s.visited).toList();
    if (candidates.length < 2) return;
    final origin = await ref.read(locationServiceProvider).current();
    final result = await ref.read(directionsServiceProvider).route(
          candidates.map((s) => Waypoint(s.lat, s.lng)).toList(),
          optimize: true,
          origin: origin,
          destination: origin == null ? null : destination,
        );
    final order = result.optimizedOrder;
    if (order == null) return;
    final List<Stop> reordered;
    if (origin != null) {
      reordered = order.map((i) => candidates[i]).toList();
    } else {
      reordered = [candidates.first, ...order.map((i) => candidates[i + 1]), candidates.last];
    }
    final finalStops = [...visited, ...reordered];
    await ref.read(routeRepoProvider).reorder(finalStops);
    _put(route.copyWith(stops: [for (var i = 0; i < finalStops.length; i++) finalStops[i].copyWith(stopOrder: i)]));
  }
}

final routesProvider = AsyncNotifierProvider<RoutesNotifier, List<RouteModel>>(RoutesNotifier.new);

final routeByIdProvider = Provider.family<RouteModel?, String>((ref, id) {
  return ref.watch(routesProvider).value?.where((r) => r.id == id).firstOrNull;
});
