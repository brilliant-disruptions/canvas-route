import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers.dart';

final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authRepoProvider).changes);

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepoProvider).user?.id;
});

/// True until the anonymous user links an email or OAuth identity.
final isAnonymousProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepoProvider).isAnonymous;
});
