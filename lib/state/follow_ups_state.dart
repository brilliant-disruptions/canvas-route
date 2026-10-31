import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/visit_history.dart';
import '../data/models/route_model.dart';
import '../data/models/stop.dart';
import '../data/models/visit.dart';
import 'providers.dart';
import 'routes_state.dart';
import 'visits_state.dart';

/// A visit that asked to be revisited, with the stop and route it came from.
class FollowUp {
  const FollowUp({required this.visit, required this.stop, required this.route});
  final Visit visit;
  final Stop stop;
  final RouteModel route;
  DateTime get due => visit.followUpDate!;
}

/// Follow-ups in the active mode's routes, soonest first.
final followUpsProvider = FutureProvider<List<FollowUp>>((ref) async {
  final routes = await ref.watch(routesProvider.future);
  final visits = await ref.watch(allVisitsProvider.future);
  final stops = {
    for (final r in routes)
      for (final s in r.stops) s.id: (stop: s, route: r),
  };
  final out = [
    for (final v in visits)
      if (v.followUpDate != null && stops[v.stopId] != null)
        FollowUp(visit: v, stop: stops[v.stopId]!.stop, route: stops[v.stopId]!.route),
  ]..sort((a, b) => a.due.compareTo(b.due));
  return out;
});

/// Overdue plus today, for badges.
final followUpsDueProvider = Provider<int>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  return ref.watch(followUpsProvider).value?.where((f) => f.due.isBefore(today)).length ?? 0;
});

class FollowUpActions {
  FollowUpActions(this.ref);
  final Ref ref;

  /// Moves (or with null, clears) a follow-up and refreshes the list.
  Future<void> reschedule(FollowUp f, DateTime? date) async {
    await ref.read(visitRepoProvider).setFollowUp(f.visit.id, date);
    ref.invalidate(allVisitsProvider);
    ref.invalidate(visitsForRouteProvider(f.route.id));
  }
}

final followUpActionsProvider = Provider((ref) => FollowUpActions(ref));

/// Past visits per place in the active mode, keyed like [Business.identity].
final visitHistoryProvider = Provider<Map<String, VisitHistory>>((ref) {
  final routes = ref.watch(routesProvider).value ?? const <RouteModel>[];
  final visits = ref.watch(allVisitsProvider).value ?? const <Visit>[];
  final keyByStop = {
    for (final r in routes)
      for (final s in r.stops) s.id: s.toBusiness().identity,
  };
  return buildVisitHistory([
    for (final v in visits)
      if (keyByStop[v.stopId] != null && v.outcome != null)
        VisitMark(key: keyByStop[v.stopId]!, at: v.createdAt, outcome: v.outcome, notes: v.notes),
  ]);
});
