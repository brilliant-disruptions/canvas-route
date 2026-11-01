// Time-window-aware route planning. A greedy pre-pass that runs before the
// Google Directions call; it is deliberately not a VRP solver (see spec §3.6).

class PlannerStop {
  const PlannerStop({
    required this.id,
    required this.lat,
    required this.lng,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final double lat;
  final double lng;
  final DateTime? opensAt;
  final DateTime? closesAt;


  DateTime? get deadline => closesAt;
}

enum ArrivalFlag { ok, beforeOpen, late, unknown }

class PlannedArrival {
  const PlannedArrival({
    required this.stop,
    required this.eta,
    required this.flag,
    required this.minutesLate,
  });

  final PlannerStop stop;
  final DateTime eta;
  final ArrivalFlag flag;

  /// Positive when arriving after the deadline; zero otherwise.
  final int minutesLate;
}

/// Orders stops for a time-window mode: by closing time (the hard deadline)
/// ascending, then opening time.
/// Stops without windows go last, preserving their relative order.
List<PlannerStop> orderByWindows(List<PlannerStop> stops) {
  final indexed = stops.asMap().entries.toList();
  int cmp(MapEntry<int, PlannerStop> a, MapEntry<int, PlannerStop> b) {
    final ka = a.value.deadline, kb = b.value.deadline;
    if (ka == null && kb == null) return a.key.compareTo(b.key);
    if (ka == null) return 1;
    if (kb == null) return -1;
    final c = ka.compareTo(kb);
    if (c != 0) return c;
    final oa = a.value.opensAt;
    final ob = b.value.opensAt;
    if (oa != null && ob != null) {
      final o = oa.compareTo(ob);
      if (o != 0) return o;
    }
    return a.key.compareTo(b.key);
  }

  indexed.sort(cmp);
  return indexed.map((e) => e.value).toList();
}

/// Walks an ordered stop list with per-leg drive seconds and a dwell time,
/// producing an ETA and a red/amber flag for each stop.
///
/// [legSeconds] has one entry per stop: drive time from the previous point
/// (start location for index 0) to that stop.
List<PlannedArrival> simulateArrivals({
  required List<PlannerStop> ordered,
  required List<int> legSeconds,
  required DateTime startAt,
  Duration dwell = const Duration(minutes: 15),
}) {
  assert(legSeconds.length == ordered.length);
  final out = <PlannedArrival>[];
  var clock = startAt;
  for (var i = 0; i < ordered.length; i++) {
    final stop = ordered[i];
    clock = clock.add(Duration(seconds: legSeconds[i]));
    var eta = clock;
    var flag = ArrivalFlag.unknown;
    var late = 0;
    final opens = stop.opensAt;
    final deadline = stop.deadline;
    if (opens != null && eta.isBefore(opens)) {
      // Waiting at the door until it opens is allowed; shift the clock.
      flag = ArrivalFlag.beforeOpen;
      eta = opens;
    }
    if (deadline != null) {
      if (eta.isAfter(deadline)) {
        flag = ArrivalFlag.late;
        late = eta.difference(deadline).inMinutes;
      } else if (flag == ArrivalFlag.unknown) {
        flag = ArrivalFlag.ok;
      }
    } else if (flag == ArrivalFlag.unknown && opens != null) {
      flag = ArrivalFlag.ok;
    }
    out.add(PlannedArrival(stop: stop, eta: eta, flag: flag, minutesLate: late));
    clock = eta.add(dwell);
  }
  return out;
}
