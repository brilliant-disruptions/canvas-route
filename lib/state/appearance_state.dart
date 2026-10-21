import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_state.dart';
import 'providers.dart';

class AppearanceNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final remote = ref.watch(settingsProvider).value?.appearance;
    return _parse(remote ?? ref.read(localPrefsProvider).appearance);
  }

  ThemeMode _parse(String v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> set(String v) async {
    state = _parse(v);
    await ref.read(localPrefsProvider).setAppearance(v);
    final s = ref.read(settingsProvider).value;
    if (s != null) await ref.read(settingsProvider.notifier).save(s.copyWith(appearance: v));
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, ThemeMode>(AppearanceNotifier.new);
