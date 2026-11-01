import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/reminders.dart';
import '../core/logic/weekend_digest.dart';
import 'community_state.dart';
import 'location_state.dart';
import 'profile_state.dart';
import 'providers.dart';

/// Whether the user wants the Friday heads-up: null until asked.
class WeekendDigestOptIn extends Notifier<bool?> {
  @override
  bool? build() => ref.read(localPrefsProvider).weekendDigest;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(localPrefsProvider).setWeekendDigest(on);
  }
}

final weekendDigestOptInProvider = NotifierProvider<WeekendDigestOptIn, bool?>(WeekendDigestOptIn.new);

/// The digest to keep scheduled: built from the listings near the user, so it's
/// refreshed every time the app has fresh data. Null while loading (leave what's
/// scheduled alone); empty when off or there's nothing to say.
final weekendDigestPlanProvider = Provider<List<PlannedReminder>?>((ref) {
  final pack = ref.watch(modePackProvider);
  if (!pack.community.weekendDigest || ref.watch(weekendDigestOptInProvider) != true) return const [];
  final at = ref.watch(mapCenterProvider);
  final key = (
    mode: pack.id,
    lat: double.parse(at.lat.toStringAsFixed(2)),
    lng: double.parse(at.lng.toStringAsFixed(2)),
    radiusMi: 20.0,
  );
  final pins = ref.watch(nearbyPinsProvider(key)).value;
  if (pins == null) return null;
  final r = weekendDigest(
    [for (final p in pins) if (p.opensAt != null) (opensAt: p.opensAt!, categories: p.categories)],
    DateTime.now(),
    noun: pack.stopNoun,
    wildcard: pack.community.categoryWildcard,
  );
  return r == null ? const [] : [r];
});
