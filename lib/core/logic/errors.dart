// Turn exceptions into something a person can act on. Raw exception text
// (PostgrestException(...), ClientException...) never reaches the UI.

import 'dart:async';

/// [denied] is the screen's explanation for a permission failure, e.g. a
/// report rejected by the rate-limit policy.
String friendlyError(Object e, {String? denied}) {
  if (e is TimeoutException) return 'That took too long. Try again.';
  // App-authored messages are already written for people.
  if (e is StateError) return e.message;
  final s = e.toString().toLowerCase();
  const offline = [
    'socketexception',
    'failed host lookup',
    'clientexception',
    'xmlhttprequest',
    'connection refused',
    'network is unreachable',
  ];
  if (offline.any(s.contains)) return 'You look offline. Check your connection and try again.';
  if (s.contains('row-level security') || s.contains('42501') || s.contains('permission denied')) {
    return denied ?? 'You can\'t do that right now.';
  }
  if (s.contains('jwt') || s.contains('not authenticated') || s.contains('401')) {
    return 'Your session expired. Sign in again.';
  }
  if (s.contains('up to') && s.contains('stops')) return e.toString(); // the stop-limit message is already plain
  return 'Something went wrong. Try again.';
}
