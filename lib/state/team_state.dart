import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/team.dart';
import 'auth_state.dart';
import 'profile_state.dart';
import 'providers.dart';

/// The caller's team, or null. Only modes with a Team plan look.
final myTeamProvider = FutureProvider<Team?>((ref) async {
  ref.watch(currentUserIdProvider);
  if (!ref.watch(modePackProvider).teamPlan || ref.watch(isAnonymousProvider)) return null;
  return ref.read(teamRepoProvider).mine();
});

final teamRosterProvider = FutureProvider<List<TeamMember>>((ref) async {
  if (await ref.watch(myTeamProvider.future) == null) return const [];
  return ref.read(teamRepoProvider).roster();
});

final teamActivityProvider = FutureProvider.family<List<RepActivity>, int>((ref, days) async {
  if (await ref.watch(myTeamProvider.future) == null) return const [];
  return ref.read(teamRepoProvider).activity(days);
});

/// Teammates' recent outcomes at one business (empty when not on a team).
// autoDispose: reopening a business sheet fetches fresh outcomes.
final teammateVisitsProvider = FutureProvider.autoDispose.family<List<TeammateVisit>, String>((ref, placeId) async {
  if (await ref.watch(myTeamProvider.future) == null) return const [];
  return ref.read(teamRepoProvider).visitsAt(placeId);
});
