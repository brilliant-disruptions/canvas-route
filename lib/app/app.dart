import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/kn_theme.dart';
import '../state/appearance_state.dart';
import 'router.dart';

class CanvasRouteApp extends ConsumerWidget {
  const CanvasRouteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
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
