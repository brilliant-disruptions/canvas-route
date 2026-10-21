import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/env.dart';
import 'core/theme/kn_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/local_prefs.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.hasSupabase) {
    runApp(const _ConfigErrorApp());
    return;
  }
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  final prefs = await LocalPrefs.load();
  await AuthRepository().ensureSession();
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
