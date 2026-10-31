import 'dart:async';

import 'package:canvas_route/core/logic/errors.dart';
import 'package:flutter_test/flutter_test.dart';

class _Ex implements Exception {
  _Ex(this.s);
  final String s;
  @override
  String toString() => s;
}

void main() {
  test('network and timeouts read as such', () {
    expect(friendlyError(_Ex('ClientException: Failed host lookup: x.supabase.co')), contains('offline'));
    expect(friendlyError(TimeoutException('t')), 'That took too long. Try again.');
  });

  test('app-authored messages pass through', () {
    expect(
      friendlyError(StateError('You can report this place 3 times an hour.')),
      'You can report this place 3 times an hour.',
    );
    expect(friendlyError(_Ex('Routes support up to 25 stops')), 'Routes support up to 25 stops');
  });

  test('permission failures use the screen\'s explanation', () {
    final rls = _Ex(
      'PostgrestException(message: new row violates row-level security policy for table "reports", code: 42501)',
    );
    expect(friendlyError(rls, denied: 'Hourly limit reached.'), 'Hourly limit reached.');
    expect(friendlyError(rls), 'You can\'t do that right now.');
  });

  test('anything else is generic, never raw', () {
    final out = friendlyError(_Ex('PostgrestException(message: duplicate key value, code: 23505)'));
    expect(out, 'Something went wrong. Try again.');
  });
}
