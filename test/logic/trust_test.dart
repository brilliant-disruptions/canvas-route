import 'package:canvas_route/core/logic/trust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels match the pattern threshold and above', () {
    expect(trustStanding(0).level, TrustLevel.newcomer);
    expect(trustStanding(patternThreshold - 1).level, TrustLevel.newcomer);
    expect(trustStanding(patternThreshold).level, TrustLevel.regular);
    expect(trustStanding(62).level, TrustLevel.trusted);
    expect(trustStanding(85).level, TrustLevel.pillar);
  });

  test('progress runs from the level floor to the next level', () {
    expect(trustStanding(45).progress(45), 0.5);
    expect(trustStanding(30).progress(30), 0);
    expect(trustStanding(99).progress(99), 1);
    expect(trustStanding(99).next, isNull);
  });
}
