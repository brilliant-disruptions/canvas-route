import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/pin_labels.dart';
import '../core/logic/watchlist.dart';
import '../data/models/alert_item.dart';
import '../data/models/app_mode.dart';
import '../data/models/pin.dart';
import '../data/models/product.dart';
import '../data/models/report.dart';
import '../data/models/store_summary.dart';
import 'auth_state.dart';
import 'location_state.dart';
import 'profile_state.dart';
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

final recentReportsProvider = FutureProvider.family<List<Report>, String>(
  (ref, pinId) => ref.read(reportRepoProvider).recentForPin(pinId),
);

final storeSummaryProvider = FutureProvider.family<StoreSummary, String>(
  (ref, pinId) => ref.read(reportRepoProvider).storeSummary(pinId),
);

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

/// The latest report at each store within the user's alert radius (last 24h),
/// as watchlist sightings. One report per store: the newest one.
final nearbySightingsProvider = FutureProvider<List<Sighting>>((ref) async {
  final pack = ref.watch(modePackProvider);
  if (!pack.communityReports) return const [];
  final c = ref.watch(mapCenterProvider);
  final radius = (ref.watch(profileProvider).value?.alertRadiusMi ?? 10).toDouble();
  final key = (
    mode: pack.id,
    lat: double.parse(c.lat.toStringAsFixed(2)),
    lng: double.parse(c.lng.toStringAsFixed(2)),
    radiusMi: radius,
  );
  final pins = await ref.watch(nearbyPinsProvider(key).future);
  if (pins.isEmpty) return const [];
  final latest = await ref.watch(latestReportsProvider(pins.map((p) => p.id).join(',')).future);
  final names = {for (final p in pins) p.id: shortPlaceName(p.name)};
  return [
    for (final r in latest.values)
      Sighting(
        pinId: r.pinId,
        pinName: names[r.pinId] ?? '',
        productId: r.productId,
        status: r.status,
        positive: pack.reportStatuses.any((s) => s.value == r.status && s.positive),
        at: r.createdAt,
      ),
  ];
});
