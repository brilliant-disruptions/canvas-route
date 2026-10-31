// The Friday-evening "what's on this weekend" reminder. Pure; no Flutter.
import 'dates.dart';
import 'reminders.dart';

typedef DigestListing = ({DateTime opensAt, List<String> categories});

/// Fixed ids: the digest replaces itself rather than stacking.
const weekendDigestId = 7001;

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h${t.minute == 0 ? '' : ':${t.minute.toString().padLeft(2, '0')}'}${t.hour < 12 ? 'am' : 'pm'}';
}

/// One reminder about the coming weekend's [listings], or null if there's
/// nothing to say. Friday 5:30pm normally; after that and until Saturday 6:30am
/// it becomes a Saturday-morning "today" note instead. [noun] is singular
/// ("sale"); [wildcard] is the catch-all category not worth naming.
PlannedReminder? weekendDigest(List<DigestListing> listings, DateTime now, {required String noun, String? wildcard}) {
  final friday = dayPlus(now, (DateTime.friday - now.weekday) % 7);
  final saturday = dayPlus(friday, 1);
  final fridayEvening = DateTime(friday.year, friday.month, friday.day, 17, 30);

  // Friday after 5:30 or Saturday before 6:30: talk about today instead. (On a
  // Saturday, `friday` above is next week's, so look back a day for this one.)
  final thisSaturday = now.weekday == DateTime.saturday ? dayPlus(now, 0) : saturday;
  final todayMode = (now.weekday == DateTime.friday && !now.isBefore(fridayEvening)) ||
      (now.weekday == DateTime.saturday && now.isBefore(DateTime(now.year, now.month, now.day, 6, 30)));

  final DateTime at, from, to;
  if (todayMode) {
    at = DateTime(thisSaturday.year, thisSaturday.month, thisSaturday.day, 6, 30);
    from = thisSaturday;
    to = dayPlus(thisSaturday, 1);
  } else {
    at = fridayEvening;
    from = friday;
    to = dayPlus(friday, 3); // Fri, Sat, Sun
  }
  if (!at.isAfter(now)) return null;

  final mine = listings.where((l) => !l.opensAt.isBefore(from) && l.opensAt.isBefore(to)).toList()
    ..sort((a, b) => a.opensAt.compareTo(b.opensAt));
  if (mine.isEmpty) return null;

  final counts = <String, int>{};
  for (final l in mine) {
    for (final c in l.categories) {
      if (c != wildcard) counts[c] = (counts[c] ?? 0) + 1;
    }
  }
  // Most common first; ties alphabetical so the wording doesn't flicker between refreshes.
  final top = counts.entries.where((e) => e.value >= 2).toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  final first = mine.first.opensAt;
  final n = mine.length;
  final plural = '$n $noun${n == 1 ? '' : 's'}';
  return (
    notificationId: weekendDigestId,
    at: at,
    title: todayMode ? '$plural near you today' : '$plural this weekend near you',
    body: [
      if (top.isNotEmpty) '${top.first.value} with ${top.first.key.toLowerCase()}',
      'first opens ${todayMode ? '' : '${_days[first.weekday - 1]} '}${_clock(first)}',
      'plan your morning in one tap',
    ].join(' · '),
  );
}

