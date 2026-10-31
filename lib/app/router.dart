import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/builder/builder_screen.dart';
import '../features/feature_requests/feature_requests_screen.dart';
import '../features/host/host_sale_screen.dart';
import '../features/host/my_sales_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/mode_picker_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/profile_capture_screen.dart';
import '../features/routes/routes_screen.dart';
import '../features/runner/runner_screen.dart';
import '../features/runner/summary_screen.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/advanced_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shared/shared_route_screen.dart';
import '../features/visit/visit_logger_screen.dart';
import '../state/providers.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(localPrefsProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/map',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!prefs.hasOnboarded && !loc.startsWith('/onboarding') && !loc.startsWith('/shared')) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen(), routes: [
        GoRoute(path: 'profile', builder: (_, _) => const ProfileCaptureScreen()),
      ]),
      GoRoute(path: '/mode', builder: (_, _) => const ModePickerScreen()),
      GoRoute(path: '/signin', builder: (_, s) => SignInScreen(reason: s.uri.queryParameters['reason'])),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/map', builder: (_, _) => const MapScreen()),
          GoRoute(path: '/routes', builder: (_, _) => const RoutesScreen()),
        ],
      ),
      GoRoute(path: '/route/builder', builder: (_, s) => BuilderScreen(autoPlan: s.uri.queryParameters['plan'] == '1')),
      GoRoute(
        path: '/route/:id',
        pageBuilder: (_, s) => MaterialPage(fullscreenDialog: true, child: RunnerScreen(routeId: s.pathParameters['id']!)),
        routes: [
          GoRoute(path: 'summary', builder: (_, s) => SummaryScreen(routeId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(
        path: '/visit/:routeId/:stopId',
        pageBuilder: (_, s) => MaterialPage(
          fullscreenDialog: true,
          child: VisitLoggerScreen(routeId: s.pathParameters['routeId']!, stopId: s.pathParameters['stopId']!),
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen(), routes: [
        GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
        GoRoute(path: 'advanced', builder: (_, _) => const AdvancedScreen()),
      ]),
      GoRoute(path: '/feature-requests', builder: (_, _) => const FeatureRequestsScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
      GoRoute(path: '/host', builder: (_, _) => const MySalesScreen(), routes: [
        GoRoute(path: 'new', builder: (_, _) => const HostSaleScreen()),
      ]),
      GoRoute(path: '/shared/:token', builder: (_, s) => SharedRouteScreen(token: s.pathParameters['token']!)),
    ],
  );
});
