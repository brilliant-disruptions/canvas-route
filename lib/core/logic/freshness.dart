// How recent a report is. Pure; no Flutter.

/// A report counts as live news for [window] (30 minutes by default).
bool isFresh(DateTime reportedAt, {DateTime? now, Duration window = const Duration(minutes: 30)}) =>
    (now ?? DateTime.now()).difference(reportedAt) <= window;

/// "just now", "12 min ago", "3h ago", "2d ago", "1w ago".
String relativeAge(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}
