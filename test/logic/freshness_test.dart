import 'package:canvas_route/core/logic/freshness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 9);

  test('a report is live news for 30 minutes unless told otherwise', () {
    expect(isFresh(now.subtract(const Duration(minutes: 10)), now: now), isTrue);
    expect(isFresh(now.subtract(const Duration(minutes: 40)), now: now), isFalse);
    expect(isFresh(now.subtract(const Duration(minutes: 40)), now: now, window: const Duration(hours: 1)), isTrue);
  });

  test('relative ages', () {
    expect(relativeAge(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(relativeAge(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(relativeAge(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(relativeAge(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    expect(relativeAge(now.subtract(const Duration(days: 15)), now: now), '2w ago');
  });
}
