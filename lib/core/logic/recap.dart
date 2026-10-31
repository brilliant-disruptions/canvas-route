// End-of-run recap numbers for the shareable summary card. Pure; no Flutter.

class RecapStop {
  const RecapStop({required this.name, required this.lat, required this.lng, this.outcome, this.at});
  final String name;
  final double lat;
  final double lng;
  final String? outcome;
  final DateTime? at;
}

class RunRecap {
  const RunRecap({
    required this.stops,
    required this.visited,
    required this.wins,
    required this.outcomeCounts,
    this.duration,
  });

  final List<RecapStop> stops;
  final int visited;

  /// Visits whose outcome is one of the mode's wins (in stock, bought, interested).
  final int wins;

  /// Non-zero outcome counts, most frequent first.
  final List<MapEntry<String, int>> outcomeCounts;

  /// First to last logged visit; null with fewer than two.
  final Duration? duration;
}

RunRecap buildRecap(List<RecapStop> stops, {required Set<String> winOutcomes}) {
  final counts = <String, int>{};
  final times = <DateTime>[];
  for (final s in stops) {
    if (s.outcome != null) counts[s.outcome!] = (counts[s.outcome!] ?? 0) + 1;
    if (s.at != null) times.add(s.at!);
  }
  times.sort();
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return RunRecap(
    stops: stops,
    visited: stops.where((s) => s.outcome != null).length,
    wins: stops.where((s) => winOutcomes.contains(s.outcome)).length,
    outcomeCounts: sorted,
    duration: times.length < 2 ? null : times.last.difference(times.first),
  );
}

/// "1 find", "3 finds".
String countNoun(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// Fits lat/lng points into a [w]×[h] box with [pad], preserving aspect.
/// North is up. A single point (or all identical) lands in the center.
List<({double x, double y})> fitPoints(List<({double lat, double lng})> pts, double w, double h, {double pad = 0}) {
  if (pts.isEmpty) return const [];
  final lats = pts.map((p) => p.lat), lngs = pts.map((p) => p.lng);
  final minLat = lats.reduce((a, b) => a < b ? a : b), maxLat = lats.reduce((a, b) => a > b ? a : b);
  final minLng = lngs.reduce((a, b) => a < b ? a : b), maxLng = lngs.reduce((a, b) => a > b ? a : b);
  final spanLat = maxLat - minLat, spanLng = maxLng - minLng;
  final iw = w - pad * 2, ih = h - pad * 2;
  final scale = spanLat == 0 && spanLng == 0
      ? 0.0
      : [if (spanLng > 0) iw / spanLng, if (spanLat > 0) ih / spanLat].reduce((a, b) => a < b ? a : b);
  final ox = pad + (iw - spanLng * scale) / 2, oy = pad + (ih - spanLat * scale) / 2;
  return [for (final p in pts) (x: ox + (p.lng - minLng) * scale, y: oy + (maxLat - p.lat) * scale)];
}

/// Items in a one-per-line field ("Items bought"), ignoring blank lines.
int countLines(Object? text) => text is String ? text.split('\n').where((l) => l.trim().isNotEmpty).length : 0;
