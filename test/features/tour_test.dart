import 'dart:io';

import 'package:canvas_route/app/app.dart';
import 'package:canvas_route/core/theme/kn_theme.dart';
import 'package:canvas_route/data/models/app_mode.dart';
import 'package:canvas_route/data/services/local_prefs.dart';
import 'package:canvas_route/demo/demo_db.dart';
import 'package:canvas_route/demo/demo_map.dart';
import 'package:canvas_route/demo/demo_repositories.dart';
import 'package:canvas_route/demo/demo_services.dart';
import 'package:canvas_route/modes/registry.dart';
import 'package:canvas_route/state/auth_state.dart';
import 'package:canvas_route/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// The whole app on the demo's in-memory backend and drawn map.
void main() {
  setUpAll(() async {
    // Real glyph widths: the test font's square glyphs overflow rows that fit on a phone.
    final manrope = FontLoader(kFontFamily);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/Manrope-$w.ttf').readAsBytesSync();
      manrope.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await manrope.load();
    GoogleMapsFlutterPlatform.instance = DemoMapsPlatform(myLocation: LatLng(DemoDb.home.lat, DemoDb.home.lng));
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpApp(WidgetTester t, LocalPrefs prefs) async {
    t.view.physicalSize = const Size(1179, 2556); // a phone, not the 800×600 default
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final db = DemoDb.seeded();
    final storage = DemoStorageService();
    await t.pumpWidget(
      ProviderScope(
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
          placesServiceProvider.overrideWithValue(DemoPlacesService()),
          directionsServiceProvider.overrideWithValue(DemoDirectionsService()),
          locationServiceProvider.overrideWithValue(DemoLocationService()),
          storageServiceProvider.overrideWithValue(storage),
          shareServiceProvider.overrideWithValue(DemoShareService()),
        ],
        child: const CanvasRouteApp(),
      ),
    );
    await settle(t);
  }

  Future<void> unmount(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  Future<LocalPrefs> onboarded({bool toured = false}) async {
    final prefs = LocalPrefs.memory();
    await prefs.setHasOnboarded(true);
    await prefs.setCachedMode(AppMode.fieldSales);
    if (toured) await prefs.setHasToured(true);
    return prefs;
  }

  testWidgets('an install past onboarding gets a five-stop tour once', (t) async {
    final prefs = await onboarded();
    await pumpApp(t, prefs);
    final tour = packFor(AppMode.fieldSales).tour;
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text(tour.search.title), findsOneWidget);

    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.text(tour.filters.title), findsOneWidget);
    // Tapping anywhere goes on too.
    await t.tapAt(const Offset(20, 400));
    await settle(t);
    expect(find.text(tour.draft.title), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text(tour.routes.title), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('5 of 5'), findsOneWidget);
    expect(find.text('Modes and more'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await t.tap(find.text('Got it'));
    await settle(t);
    expect(find.text('5 of 5'), findsNothing);
    expect(prefs.hasToured, isTrue);

    // Next launch: straight to the map.
    await unmount(t);
    await pumpApp(t, prefs);
    expect(find.textContaining(' of 5'), findsNothing);
    await unmount(t);
  });

  testWidgets('not during onboarding; once it is done, the tour follows', (t) async {
    final prefs = LocalPrefs.memory();
    await pumpApp(t, prefs);
    expect(find.text('What are you\nhere to do?'), findsOneWidget);
    expect(find.textContaining(' of 5'), findsNothing);

    await t.tap(find.text('Card Drops'));
    await settle(t);
    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Next'));
      await settle(t);
    }
    await t.tap(find.text('Get Started'));
    await settle(t);
    expect(find.text('Save & Start'), findsOneWidget);
    expect(find.textContaining(' of 5'), findsNothing);
    await t.tap(find.text('Skip'));
    await settle(t);
    // In the mode they picked.
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text(packFor(AppMode.cardDrops).tour.search.title), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    expect(prefs.hasToured, isTrue);
    await unmount(t);
  });

  testWidgets('skipping counts as seen; Preferences replays it from the start', (t) async {
    final prefs = await onboarded();
    await pumpApp(t, prefs);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('2 of 5'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    expect(find.textContaining(' of 5'), findsNothing);
    expect(prefs.hasToured, isTrue);

    await t.tap(find.byTooltip('Menu'));
    await settle(t);
    await t.tap(find.text('Preferences'));
    await settle(t);
    await t.tap(find.text('Show me around'));
    await settle(t);
    await settle(t);
    expect(find.text('Show me around'), findsNothing);
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.text(packFor(AppMode.fieldSales).tour.search.title), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    await unmount(t);
  });

  testWidgets('already toured: nothing on top of the map', (t) async {
    await pumpApp(t, await onboarded(toured: true));
    await settle(t);
    expect(find.textContaining(' of 5'), findsNothing);
    expect(find.text('Draft'), findsOneWidget);
    await unmount(t);
  });
}
