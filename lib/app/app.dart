import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/kn_theme.dart';
import '../state/appearance_state.dart';
import '../state/follow_ups_state.dart';
import '../state/profile_state.dart';
import '../state/team_state.dart';
import '../state/providers.dart';
import 'router.dart';

class CanvasRouteApp extends ConsumerStatefulWidget {
  const CanvasRouteApp({super.key});

  @override
  ConsumerState<CanvasRouteApp> createState() => _CanvasRouteAppState();
}

class _CanvasRouteAppState extends ConsumerState<CanvasRouteApp> {
  // Plans change server-side (checkout in the browser, store webhooks), so
  // re-read the profile whenever the app comes back to the foreground.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () async {
        // Retry the guest sign-in if launch happened offline.
        await ref.read(authRepoProvider).ensureSession().catchError((_) {});
        // Plans, team coverage and "due today" can all change while the app is away.
        ref.invalidate(profileProvider);
        ref.invalidate(myTeamProvider);
        ref.invalidate(followUpsDueProvider);
      },
    );
    // Tapping a follow-up reminder opens the list.
    // A tap may arrive before the first frame (app launched from the notification).
    ref
        .read(reminderServiceProvider)
        .init(
          onTap: (path) => WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(routerProvider).push(path ?? '/follow-ups'),
          ),
        )
        .catchError((_) {});
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Keep the device's reminders in step with the follow-up list.
    ref.listen(followUpReminderPlanProvider, (_, plan) {
      if (plan != null) ref.read(reminderServiceProvider).replaceAll(plan, payload: '/follow-ups').catchError((_) {});
    });
    return MaterialApp.router(
      title: 'CanvasRoute',
      debugShowCheckedModeBanner: false,
      theme: knTheme(Brightness.light),
      darkTheme: knTheme(Brightness.dark),
      themeMode: ref.watch(appearanceProvider),
      routerConfig: router,
      // Let mouse and trackpad drags scroll lists and sheets too (web and desktop testing).
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: PointerDeviceKind.values.toSet()),
    );
  }
}
