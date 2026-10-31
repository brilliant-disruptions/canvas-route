// Restock pattern helpers for Card Drops (spec §3.4).

enum RestockTier { unknown, emerging, established }

RestockTier tierForHits(int hits) {
  if (hits >= 10) return RestockTier.established;
  if (hits >= 3) return RestockTier.emerging;
  return RestockTier.unknown;
}

String tierLabel(RestockTier t) => switch (t) {
      RestockTier.unknown => 'Help map this store',
      RestockTier.emerging => 'Emerging pattern',
      RestockTier.established => 'Established pattern',
    };

const _dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String hourLabel(int hour) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12${hour < 12 ? 'am' : 'pm'}';
}

/// "Tue 8–10am · 23 reports"
String describeWindow({required int dow, required int hour, required int hits}) {
  final end = (hour + 2) % 24;
  final sameHalf = (hour < 12) == (end < 12);
  final start = sameHalf ? '${hour % 12 == 0 ? 12 : hour % 12}' : hourLabel(hour);
  return '${_dow[dow]} $start–${hourLabel(end)} · $hits report${hits == 1 ? '' : 's'}';
}

/// Given the planned day, returns the start/end DateTime of the best window
/// whose day-of-week matches, or null when the store has none for that day.
({DateTime start, DateTime end})? windowOnDay(
  List<({int dow, int hour, int hits})> bestWindows,
  DateTime day,
) {
  final match = bestWindows.where((w) => w.dow == day.weekday % 7).toList()
    ..sort((a, b) => b.hits.compareTo(a.hits));
  if (match.isEmpty) return null;
  final w = match.first;
  final start = DateTime(day.year, day.month, day.day, w.hour);
  return (start: start, end: start.add(const Duration(hours: 2)));
}

/// How fresh an in-stock report is for the map's freshness ring.
bool isFresh(DateTime reportedAt, {DateTime? now, Duration window = const Duration(minutes: 30)}) =>
    (now ?? DateTime.now()).difference(reportedAt) <= window;

String relativeAge(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}

/// The soonest upcoming (or current) occurrence of any best window, looking a
/// week ahead. Windows are two hours from their start hour.
({DateTime start, DateTime end})? nextLikelyWindow(List<({int dow, int hour, int hits})> best, DateTime now) {
  ({DateTime start, DateTime end})? soonest;
  for (final w in best) {
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 0; d <= 7; d++) {
      final day = today.add(Duration(days: d));
      if (day.weekday % 7 != w.dow) continue;
      final start = DateTime(day.year, day.month, day.day, w.hour);
      final end = start.add(const Duration(hours: 2));
      if (!end.isAfter(now)) continue;
      if (soonest == null || start.isBefore(soonest.start)) soonest = (start: start, end: end);
      break;
    }
  }
  return soonest;
}

/// "now", "in 45 min", "in 5h", "tomorrow", "in 3 days".
String untilLabel(DateTime start, DateTime now) {
  if (!start.isAfter(now)) return 'now';
  final d = start.difference(now);
  if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
  final days = DateTime(start.year, start.month, start.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'in ${d.inHours}h';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}
