import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Whether this device has had the spotlight tour. Skipping counts as seen.
class TouredNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(localPrefsProvider).hasToured;

  Future<void> markSeen() async {
    state = true;
    await ref.read(localPrefsProvider).setHasToured(true);
  }
}

final touredProvider = NotifierProvider<TouredNotifier, bool>(TouredNotifier.new);

/// Asks the tab shell to show the tour again (from Preferences, which sits on
/// top of it). Stays true until the shell picks it up, so a shell that is
/// rebuilt on the way back still sees it.
class TourRequest extends Notifier<bool> {
  @override
  bool build() => false;
  void request() => state = true;
  void clear() => state = false;
}

final tourRequestProvider = NotifierProvider<TourRequest, bool>(TourRequest.new);
