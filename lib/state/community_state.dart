import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_mode.dart';
import '../data/models/pin.dart';
import '../data/models/report.dart';
import 'auth_state.dart';
import 'providers.dart';

typedef NearbyKey = ({AppMode mode, double lat, double lng, double radiusMi});

final nearbyPinsProvider = FutureProvider.family<List<Pin>, NearbyKey>((ref, k) async {
  return ref.read(pinRepoProvider).nearby(k.mode, k.lat, k.lng, radiusMi: k.radiusMi);
});

final pinByIdProvider = FutureProvider.family<Pin?, String>((ref, id) => ref.read(pinRepoProvider).byId(id));

/// How many other people have a pin you own in their route (hosts only).
final pinInterestProvider = FutureProvider.family<int?, String>(
  (ref, pinId) => ref.read(pinRepoProvider).interest(pinId),
);

final myPinsProvider = FutureProvider<List<Pin>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.read(pinRepoProvider).mine(uid);
});

/// Keyed by a joined id string so the family key has value equality.
final latestReportsProvider = FutureProvider.family<Map<String, Report>, String>((ref, joinedIds) async {
  final ids = joinedIds.isEmpty ? const <String>[] : joinedIds.split(',');
  return ref.read(reportRepoProvider).latestForPins(ids);
});

final recentReportsProvider = FutureProvider.family<List<Report>, String>(
  (ref, pinId) => ref.read(reportRepoProvider).recentForPin(pinId),
);

/// Live report feed for the freshness ring; emits raw rows, consumers refresh.
final reportStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) => ref.read(reportRepoProvider).stream());

