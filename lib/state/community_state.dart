import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/alert_item.dart';
import '../data/models/app_mode.dart';
import '../data/models/pin.dart';
import '../data/models/product.dart';
import '../data/models/report.dart';
import '../data/models/store_summary.dart';
import 'auth_state.dart';
import 'providers.dart';

typedef NearbyKey = ({AppMode mode, double lat, double lng, double radiusMi});

final nearbyPinsProvider = FutureProvider.family<List<Pin>, NearbyKey>((ref, k) async {
  return ref.read(pinRepoProvider).nearby(k.mode, k.lat, k.lng, radiusMi: k.radiusMi);
});

final pinByIdProvider = FutureProvider.family<Pin?, String>((ref, id) => ref.read(pinRepoProvider).byId(id));

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

final recentReportsProvider =
    FutureProvider.family<List<Report>, String>((ref, pinId) => ref.read(reportRepoProvider).recentForPin(pinId));

final storeSummaryProvider =
    FutureProvider.family<StoreSummary, String>((ref, pinId) => ref.read(reportRepoProvider).storeSummary(pinId));

final storeSummariesProvider = FutureProvider.family<Map<String, StoreSummary>, String>((ref, joinedIds) async {
  final ids = joinedIds.isEmpty ? const <String>[] : joinedIds.split(',');
  return ref.read(reportRepoProvider).summaries(ids);
});

final productsProvider = FutureProvider<List<Product>>((ref) => ref.read(productRepoProvider).canonical());

class FollowsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return {};
    return ref.read(productRepoProvider).follows(uid);
  }

  Future<void> toggle(String productId) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final cur = <String>{...state.value ?? <String>{}};
    if (cur.contains(productId)) {
      await ref.read(productRepoProvider).unfollow(uid, productId);
      cur.remove(productId);
    } else {
      await ref.read(productRepoProvider).follow(uid, productId);
      cur.add(productId);
    }
    state = AsyncData(cur);
  }
}

final followsProvider = AsyncNotifierProvider<FollowsNotifier, Set<String>>(FollowsNotifier.new);

final alertsProvider = FutureProvider<List<AlertItem>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.read(alertRepoProvider).list(uid);
});

/// Live report feed for the freshness ring; emits raw rows, consumers refresh.
final reportStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) => ref.read(reportRepoProvider).stream());
