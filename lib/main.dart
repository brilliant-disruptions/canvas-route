import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/env.dart';
import 'core/theme/kn_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/local_prefs.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths on the web: shared links and sign QRs are <origin>/s/<token>, not /#/s/.
  usePathUrlStrategy();
  if (!Env.hasSupabase) {
    runApp(const _ConfigErrorApp());
    return;
  }
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  final prefs = await LocalPrefs.load();
  // First launch with no signal mustn't strand the user on a blank screen: start
  // without a session and sign in when the app next comes to the foreground.
  try {
    await AuthRepository().ensureSession();
  } catch (_) {}
  runApp(ProviderScope(
    overrides: [localPrefsProvider.overrideWithValue(prefs)],
    child: const CanvasRouteApp(),
  ));
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: knTheme(Brightness.dark),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'CanvasRoute needs SUPABASE_URL and SUPABASE_ANON_KEY.\n\n'
                'Run with --dart-define-from-file=.env.json (see README).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
