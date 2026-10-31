import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/directions.dart';
import '../data/models/route_model.dart';
import '../data/models/trip.dart';
import '../data/models/visit.dart';
import 'auth_state.dart';
import 'profile_state.dart';
import 'providers.dart';

/// The active mode's trips, newest first.
final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  final mode = ref.watch(activeModeProvider);
  if (uid == null) return const [];
  return ref.read(tripRepoProvider).forUser(uid, mode.id);
});

class TripLogger {
  TripLogger(this.ref);
  final Ref ref;

  /// Records the drive between this run's visited stops, in the order they were
  /// visited. Skips modes without a mileage log, runs under two stops, and runs
  /// already logged with the same number of stops (so reopening a summary is free).
  Future<void> logRun(RouteModel route, List<Visit> visits) async {
    final pack = ref.read(modePackProvider);
    final uid = ref.read(currentUserIdProvider);
    if (!pack.mileageLog || uid == null) return;
    final stops = {for (final s in route.stops) s.id: s};
    final done = [...visits.where((v) => stops.containsKey(v.stopId))]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (done.length < 2) return;
    final existing = (await ref.read(tripsProvider.future)).where((t) => t.routeId == route.id).firstOrNull;
    if (existing != null && existing.stopsVisited == done.length) return;

    final result = await ref.read(directionsServiceProvider).route([
      for (final v in done) Waypoint(stops[v.stopId]!.lat, stops[v.stopId]!.lng),
    ]);
    await ref.read(tripRepoProvider).upsert(Trip.insert(
      userId: uid,
      routeId: route.id,
      mode: pack.id.id,
      routeName: route.name,
      day: done.first.createdAt,
      distanceMeters: result.totalDistanceMeters,
      stopsVisited: done.length,
      estimated: result.estimated,
    ));
    ref.invalidate(tripsProvider);
  }
}

final tripLoggerProvider = Provider((ref) => TripLogger(ref));
