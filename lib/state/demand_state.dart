import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_mode.dart';
import '../data/repositories/demand_repository.dart';
import 'providers.dart';

/// An area for demand counts: the ~7-mile cell the server groups by, so panning
/// within it doesn't refetch.
typedef DemandKey = ({AppMode mode, double lat, double lng});

DemandKey demandKey(AppMode mode, double lat, double lng) =>
    (mode: mode, lat: double.parse(lat.toStringAsFixed(1)), lng: double.parse(lng.toStringAsFixed(1)));

final huntersWaitingProvider = FutureProvider.autoDispose.family<int, DemandKey>(
  (ref, k) => ref.read(demandRepoProvider).waiting(k.mode, k.lat, k.lng),
);

final myHuntInterestProvider = FutureProvider.autoDispose.family<bool, DemandKey>(
  (ref, k) => ref.read(demandRepoProvider).mine(k.mode, k.lat, k.lng),
);

final nearestLiveProvider = FutureProvider.autoDispose.family<NearestLive?, DemandKey>(
  (ref, k) => ref.read(demandRepoProvider).nearestLive(k.mode, k.lat, k.lng),
);

final demandCellsProvider = FutureProvider.autoDispose.family<List<DemandCell>, AppMode>(
  (ref, mode) => ref.read(demandRepoProvider).cells(mode),
);

class DemandActions {
  DemandActions(this.ref);
  final Ref ref;

  /// Raises the user's hand for an area; returns how many are waiting there now.
  Future<int> register(DemandKey k) async {
    final n = await ref.read(demandRepoProvider).register(k.mode, k.lat, k.lng);
    ref.invalidate(huntersWaitingProvider(k));
    ref.invalidate(myHuntInterestProvider(k));
    return n;
  }
}

final demandActionsProvider = Provider((ref) => DemandActions(ref));
