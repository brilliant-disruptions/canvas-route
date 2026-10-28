import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../state/profile_state.dart';
import '../../state/tour_state.dart';
import '../../ui/widgets/spotlight.dart';

/// What the spotlight tour lights up. Each key sits on one widget.
abstract final class TourKeys {
  static final search = GlobalKey(debugLabel: 'tour:search');
  static final filters = GlobalKey(debugLabel: 'tour:filters');
  static final draft = GlobalKey(debugLabel: 'tour:draft');
  static final routesTab = GlobalKey(debugLabel: 'tour:routes');
  static final menu = GlobalKey(debugLabel: 'tour:menu');
}

/// The stops, in the active mode's words. Only the menu reads the same in
/// every mode.
List<SpotlightStep> tourSteps(ModePack pack) => [
  SpotlightStep(target: TourKeys.search, title: pack.tour.search.title, body: pack.tour.search.body),
  SpotlightStep(
    target: TourKeys.filters,
    radius: Rad.full,
    title: pack.tour.filters.title,
    body: pack.tour.filters.body,
  ),
  SpotlightStep(target: TourKeys.draft, title: pack.tour.draft.title, body: pack.tour.draft.body),
  SpotlightStep(target: TourKeys.routesTab, title: pack.tour.routes.title, body: pack.tour.routes.body),
  SpotlightStep(
    target: TourKeys.menu,
    title: 'Modes and more',
    body: 'Switch mode, sign in, or change preferences. You can replay this tour from Preferences.',
  ),
];

/// Show the tour on the map, then remember they've seen it. If something
/// else is on top by the time the map is ready, it waits for next time.
Future<void> startTour(BuildContext context, WidgetRef ref) async {
  ref.read(tourRequestProvider.notifier).clear();
  GoRouter.of(context).go('/map');
  // Let the profile (and so the mode) load and the map lay out before
  // lighting anything up; a stop whose target never shows is left out.
  try {
    await ref.read(profileProvider.future);
  } catch (_) {}
  await Future<void>.delayed(const Duration(milliseconds: 800));
  if (!context.mounted) return;
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
  await showSpotlight(context, tourSteps(ref.read(modePackProvider)));
  await ref.read(touredProvider.notifier).markSeen();
}
