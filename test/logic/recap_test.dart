import 'package:canvas_route/core/logic/recap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 31, 9);

  test('counts wins, visits, outcomes and duration', () {
    final r = buildRecap(
      [
        RecapStop(name: 'A', lat: 0, lng: 0, outcome: 'In stock', at: t0),
        RecapStop(name: 'B', lat: 0, lng: 0, outcome: 'Sold out', at: t0.add(const Duration(minutes: 20))),
        RecapStop(name: 'C', lat: 0, lng: 0, outcome: 'In stock', at: t0.add(const Duration(minutes: 47))),
        const RecapStop(name: 'D', lat: 0, lng: 0),
      ],
      winOutcomes: {'In stock', 'Restocking now'},
    );
    expect(r.visited, 3);
    expect(r.wins, 2);
    expect(r.outcomeCounts.map((e) => '${e.key}:${e.value}'), ['In stock:2', 'Sold out:1']);
    expect(r.duration, const Duration(minutes: 47));
  });

  test('a single visit has no duration', () {
    final r = buildRecap(
      [RecapStop(name: 'A', lat: 0, lng: 0, outcome: 'Bought', at: t0)],
      winOutcomes: {'Bought'},
    );
    expect(r.duration, isNull);
    expect(r.wins, 1);
  });

  test('countLines counts non-blank lines', () {
    expect(countLines('Lounge chair\nCast iron skillet\n\n  '), 2);
    expect(countLines(null), 0);
    expect(countLines(3), 0);
  });

  test('countNoun pluralizes', () {
    expect(countNoun(1, 'find'), '1 find');
    expect(countNoun(0, 'lead'), '0 leads');
    expect(countNoun(3, 'buy'), '3 buys');
  });

  test('fitPoints keeps north up, aspect, and padding', () {
    final pts = fitPoints([(lat: 1, lng: 0), (lat: 0, lng: 2)], 100, 100, pad: 10);
    // Wider than tall: x spans the inner 80px, y is centered.
    expect(pts[0].x, 10);
    expect(pts[1].x, 90);
    expect(pts[0].y, lessThan(pts[1].y)); // north (lat 1) is higher on screen
    expect(pts[1].y - pts[0].y, closeTo(40, 1e-9));
    final one = fitPoints([(lat: 5, lng: 5)], 100, 60);
    expect((one.single.x, one.single.y), (50.0, 30.0));
  });
}
