import 'package:canvas_route/core/logic/visit_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 15);

  test('groups by place and keeps the latest outcome and notes', () {
    final h = buildVisitHistory([
      VisitMark(key: 'a', at: DateTime(2026, 10, 1), outcome: 'No Answer'),
      VisitMark(key: 'a', at: DateTime(2026, 10, 19), outcome: 'Interested', notes: 'Wants pricing'),
      VisitMark(key: 'a', at: DateTime(2026, 10, 10), outcome: 'Contacted'),
      VisitMark(key: 'b', at: DateTime(2026, 10, 30), outcome: 'Not Interested'),
    ]);
    expect(h['a']!.count, 3);
    expect(h['a']!.lastOutcome, 'Interested');
    expect(h['a']!.lastNotes, 'Wants pricing');
    expect(h['b']!.count, 1);
    expect(h['c'], isNull);
  });

  test('history line reads naturally', () {
    VisitHistory at(DateTime d, int n) => VisitHistory(count: n, lastAt: d);
    expect(visitHistoryLine(at(DateTime(2026, 10, 31, 9), 1), now), 'Visited today');
    expect(visitHistoryLine(at(DateTime(2026, 10, 30, 23), 1), now), 'Visited yesterday');
    expect(visitHistoryLine(at(DateTime(2026, 10, 19), 3), now), 'Visited 3× · last 12 days ago');
  });
}
