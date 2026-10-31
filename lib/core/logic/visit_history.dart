// What happened the last times you visited a place. Pure; no Flutter.

class VisitMark {
  const VisitMark({required this.key, required this.at, this.outcome, this.notes});

  /// Identity of the place (a Places id, a pin id, or rounded coordinates).
  final String key;
  final DateTime at;
  final String? outcome;
  final String? notes;
}

class VisitHistory {
  const VisitHistory({required this.count, required this.lastAt, this.lastOutcome, this.lastNotes});
  final int count;
  final DateTime lastAt;
  final String? lastOutcome;
  final String? lastNotes;
}

/// Groups visits by place; the latest visit supplies outcome and notes.
Map<String, VisitHistory> buildVisitHistory(Iterable<VisitMark> marks) {
  final byKey = <String, List<VisitMark>>{};
  for (final m in marks) {
    byKey.putIfAbsent(m.key, () => []).add(m);
  }
  return {
    for (final e in byKey.entries)
      e.key: () {
        final last = e.value.reduce((a, b) => b.at.isAfter(a.at) ? b : a);
        return VisitHistory(
          count: e.value.length,
          lastAt: last.at,
          lastOutcome: last.outcome,
          lastNotes: last.notes,
        );
      }(),
  };
}

/// "Visited today", "Visited yesterday", "Visited 3× · last 12 days ago".
String visitHistoryLine(VisitHistory h, DateTime now) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(h.lastAt.year, h.lastAt.month, h.lastAt.day))
      .inDays;
  final when = switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    _ => '$days days ago',
  };
  return h.count == 1 ? 'Visited $when' : 'Visited ${h.count}× · last $when';
}
