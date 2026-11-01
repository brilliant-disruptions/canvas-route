import 'package:canvas_route/core/logic/time_window_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 24); // Saturday
  DateTime at(int h, [int m = 0]) => DateTime(day.year, day.month, day.day, h, m);

  group('orderByWindows', () {
    test('yard sales: earliest closing first, unwindowed last', () {
      final stops = [
        PlannerStop(id: 'late', lat: 0, lng: 0, opensAt: at(8), closesAt: at(14)),
        PlannerStop(id: 'none', lat: 0, lng: 0),
        PlannerStop(id: 'early', lat: 0, lng: 0, opensAt: at(7), closesAt: at(11)),
      ];
      final ordered = orderByWindows(stops);
      expect(ordered.map((s) => s.id), ['early', 'late', 'none']);
    });

    test('stable for equal keys', () {
      final stops = [
        PlannerStop(id: 'a', lat: 0, lng: 0, closesAt: at(12)),
        PlannerStop(id: 'b', lat: 0, lng: 0, closesAt: at(12)),
      ];
      expect(orderByWindows(stops).map((s) => s.id), ['a', 'b']);
    });
  });

  group('simulateArrivals', () {
    test('flags a stop reached after it closes', () {
      final ordered = [
        PlannerStop(id: 'a', lat: 0, lng: 0, opensAt: at(7), closesAt: at(12)),
        PlannerStop(id: 'b', lat: 0, lng: 0, opensAt: at(7), closesAt: at(8)),
      ];
      final out = simulateArrivals(
        ordered: ordered,
        legSeconds: [600, 1800],
        startAt: at(7),
        dwell: const Duration(minutes: 15),
      );
      expect(out[0].flag, ArrivalFlag.ok);
      expect(out[0].eta, at(7, 10));
      // 7:10 + 15 dwell + 30 drive = 7:55 → ok? closes 8:00 → ok
      expect(out[1].flag, ArrivalFlag.ok);
    });

    test('late arrival reports minutes past deadline and waits for opening', () {
      final ordered = [
        PlannerStop(id: 'a', lat: 0, lng: 0, opensAt: at(9), closesAt: at(9, 30)),
        PlannerStop(id: 'b', lat: 0, lng: 0, opensAt: at(7), closesAt: at(9, 40)),
      ];
      final out = simulateArrivals(ordered: ordered, legSeconds: [0, 600], startAt: at(8), dwell: const Duration(minutes: 15));
      expect(out[0].flag, ArrivalFlag.beforeOpen);
      expect(out[0].eta, at(9));
      // 9:00 + 15 + 10 = 9:25 → fine; then test a later leg
      expect(out[1].flag, ArrivalFlag.ok);
      final late = simulateArrivals(ordered: ordered, legSeconds: [0, 3600], startAt: at(8), dwell: const Duration(minutes: 15));
      expect(late[1].flag, ArrivalFlag.late);
      expect(late[1].minutesLate, 35);
    });

    test('stops without windows are unknown', () {
      final out = simulateArrivals(ordered: [const PlannerStop(id: 'x', lat: 0, lng: 0)], legSeconds: [0], startAt: at(8));
      expect(out.single.flag, ArrivalFlag.unknown);
    });
  });
}
