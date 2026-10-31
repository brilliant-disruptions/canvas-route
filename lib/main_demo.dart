import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'app/app.dart';
import 'data/services/local_prefs.dart';
import 'demo/demo_db.dart';
import 'demo/demo_map.dart';
import 'demo/demo_repositories.dart';
import 'demo/demo_services.dart';
import 'state/auth_state.dart';
import 'state/providers.dart';

/// Demo entry point: the real app on an in-memory backend with sample Dallas
/// data and a drawn map. No Supabase, no Google keys, nothing leaves the device.
///
///   flutter run -t lib/main_demo.dart
///   flutter build web -t lib/main_demo.dart --no-web-resources-cdn
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths on the web: shared links and sign QRs are <origin>/s/<token>, not /#/s/.
  usePathUrlStrategy();
  GoogleMapsFlutterPlatform.instance = DemoMapsPlatform(myLocation: LatLng(DemoDb.user.lat, DemoDb.user.lng));
  final prefs = LocalPrefs.memory(); // fresh onboarding on every load
  final db = DemoDb.seeded();
  final storage = DemoStorageService();

  runApp(ProviderScope(
    overrides: [
      localPrefsProvider.overrideWithValue(prefs),
      currentUserIdProvider.overrideWithValue(DemoDb.userId),
      isAnonymousProvider.overrideWithValue(false),
      authStateProvider.overrideWithValue(const AsyncLoading()),
      authRepoProvider.overrideWithValue(DemoAuthRepository()),
      profileRepoProvider.overrideWithValue(DemoProfileRepository(db)),
      settingsRepoProvider.overrideWithValue(DemoSettingsRepository(db)),
      routeRepoProvider.overrideWithValue(DemoRouteRepository(db)),
      visitRepoProvider.overrideWithValue(DemoVisitRepository(db)),
      pinRepoProvider.overrideWithValue(DemoPinRepository(db, storage)),
      reportRepoProvider.overrideWithValue(DemoReportRepository(db)),
      productRepoProvider.overrideWithValue(DemoProductRepository(db)),
      featureRequestRepoProvider.overrideWithValue(DemoFeatureRequestRepository(db)),
      alertRepoProvider.overrideWithValue(DemoAlertRepository(db)),
      shareRepoProvider.overrideWithValue(DemoShareRepository(db)),
      tripRepoProvider.overrideWithValue(DemoTripRepository(db)),
      teamRepoProvider.overrideWithValue(DemoTeamRepository(db)),
      demandRepoProvider.overrideWithValue(DemoDemandRepository(db)),
      placesServiceProvider.overrideWithValue(DemoPlacesService()),
      directionsServiceProvider.overrideWithValue(DemoDirectionsService()),
      locationServiceProvider.overrideWithValue(DemoLocationService()),
      storageServiceProvider.overrideWithValue(storage),
      shareServiceProvider.overrideWithValue(DemoShareService()),
    ],
    child: const CanvasRouteApp(),
  ));
}
