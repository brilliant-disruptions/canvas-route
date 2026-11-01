import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../data/models/app_mode.dart';
import '../data/models/profile.dart';
import '../data/models/settings.dart';
import '../data/models/visit_field.dart';
import '../modes/mode_pack.dart';
import '../modes/registry.dart';
import 'auth_state.dart';
import 'providers.dart';
import 'team_state.dart';

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return null;
    final repo = ref.read(profileRepoProvider);
    // The auth trigger creates the row; on a cold race, retry once.
    var p = await repo.fetch(uid);
    if (p == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      p = await repo.fetch(uid);
    }
    return p;
  }

  Future<void> patch(Map<String, dynamic> fields) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    state = AsyncData(await ref.read(profileRepoProvider).update(uid, fields));
  }

  Future<void> setMode(AppMode mode) async {
    await ref.read(localPrefsProvider).setCachedMode(mode);
    await patch({'active_mode': mode.id});
  }

  Future<void> markOnboarded() async {
    await ref.read(localPrefsProvider).setHasOnboarded(true);
    await patch({'has_onboarded': true});
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

final activeModeProvider = Provider<AppMode>((ref) {
  final p = ref.watch(profileProvider).value;
  return launchable(p?.activeMode ?? ref.watch(localPrefsProvider).cachedMode);
});

final modePackProvider = Provider<ModePack>((ref) => packFor(ref.watch(activeModeProvider)));

final isAdminProvider = Provider<bool>((ref) => ref.watch(profileProvider).value?.isAdmin ?? false);
/// Has paid for the active vertical. A Season Pass doesn't unlock Field Sales Pro.
final isPayingProvider = Provider<bool>((ref) {
  final pack = ref.watch(modePackProvider);
  final own = ref.watch(profileProvider).value?.owns(pack.pro.productId, includedInPlan: pack.pro.includedInPlan) ?? false;
  // Reps on a manager's Team plan are covered without buying their own.
  return own || (pack.tools.teamPlan && (ref.watch(myTeamProvider).value?.covered ?? false));
});

/// The active vertical's paid tier can be bought here: web-billed plans where
/// Stripe Checkout is allowed on this platform. In-app purchase isn't built yet,
/// so store-billed passes can't be bought anywhere for now.
final canBuyProProvider = Provider<bool>((ref) {
  final pack = ref.watch(modePackProvider);
  return pack.pro.productId != null && pack.pro.webBilling && Env.webCheckoutHere;
});

/// What gates features. Nothing is locked behind a tier the user can't buy here:
/// an unpurchasable paywall gets apps rejected and helps no one.
final hasProAccessProvider = Provider<bool>((ref) => ref.watch(isPayingProvider) || !ref.watch(canBuyProProvider));

/// Has paid for any vertical, e.g. to file feature requests.
final paysForAnythingProvider = Provider<bool>((ref) => ref.watch(profileProvider).value?.isPaying ?? false);

class SettingsNotifier extends AsyncNotifier<Settings?> {
  @override
  Future<Settings?> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return null;
    return ref.read(settingsRepoProvider).fetch(uid);
  }

  Future<void> save(Settings s) async {
    state = AsyncData(await ref.read(settingsRepoProvider).save(s));
  }

  Future<void> updateOverride(AppMode mode, ModeOverride Function(ModeOverride) fn) async {
    final s = state.value;
    if (s == null) return;
    final next = Map<AppMode, ModeOverride>.from(s.modeOverrides);
    next[mode] = fn(s.overrideFor(mode));
    await save(s.copyWith(modeOverrides: next));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, Settings?>(SettingsNotifier.new);

/// Effective config = user override for the active mode, else pack default.
final effectiveOutcomesProvider = Provider<List<String>>((ref) {
  final pack = ref.watch(modePackProvider);
  final s = ref.watch(settingsProvider).value;
  return s?.overrideFor(pack.id).outcomes ?? pack.defaultOutcomes;
});

final effectiveVisitFieldsProvider = Provider<List<VisitFieldDefinition>>((ref) {
  final pack = ref.watch(modePackProvider);
  final s = ref.watch(settingsProvider).value;
  return s?.overrideFor(pack.id).visitFields ?? pack.defaultVisitFields;
});

final effectiveExportFieldsProvider = Provider<List<String>>((ref) {
  final pack = ref.watch(modePackProvider);
  final s = ref.watch(settingsProvider).value;
  return s?.overrideFor(pack.id).exportFields ?? pack.defaultExportFields;
});
