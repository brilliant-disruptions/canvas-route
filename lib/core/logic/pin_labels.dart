// Short labels that fit on a map pin.
import 'dates.dart';

/// "7a", "12:30p".
String compactTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute == 0 ? '' : ':${t.minute.toString().padLeft(2, '0')}';
  return '$h$m${t.hour < 12 ? 'a' : 'p'}';
}

/// "7a–1p", or "From 7a" without a close.
String compactWindow(DateTime opens, DateTime? closes) =>
    closes == null ? 'From ${compactTime(opens)}' : '${compactTime(opens)}–${compactTime(closes)}';

/// Drops parentheticals and dash suffixes and caps the length:
/// "Collectors Cave (card shop)" → "Collectors Cave".
String shortPlaceName(String name, {int max = 16}) {
  var s = name.split(RegExp(r' [(—–-] ?')).first.trim();
  if (s.isEmpty) s = name.trim();
  return s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';
}

/// Sign-style window, read from across a street: "7AM–1PM", "FROM 8AM".
String signWindow(DateTime opens, DateTime? closes) {
  String time(DateTime t) => '${compactTime(t).toUpperCase()}M';
  return closes == null ? 'FROM ${time(opens)}' : '${time(opens)}–${time(closes)}';
}

/// Whether a sale tagged [tags] fits what the user is hunting. Nothing wanted
/// means everything fits; a sale tagged [wildcard] ("Everything") always fits.
bool matchesHunt(List<String> tags, Set<String> wanted, {String? wildcard}) =>
    wanted.isEmpty || tags.any((t) => t == wildcard || wanted.contains(t));

/// Chip label for the hunt filter: "Any", "Tools", "Tools +2".
String huntLabel(Set<String> wanted) => wanted.isEmpty
    ? 'Any'
    : wanted.length == 1
    ? wanted.first
    : '${wanted.first} +${wanted.length - 1}';

/// Where a time-boxed sale is relative to now.
enum SalePhase { upcoming, startingSoon, open, closingSoon, ended }

SalePhase salePhase(DateTime opens, DateTime? closes, DateTime now) {
  if (closes != null && !now.isBefore(closes)) return SalePhase.ended;
  if (now.isBefore(opens)) {
    return opens.difference(now) <= const Duration(hours: 2) ? SalePhase.startingSoon : SalePhase.upcoming;
  }
  if (closes != null && closes.difference(now) <= const Duration(hours: 1)) return SalePhase.closingSoon;
  return SalePhase.open;
}

/// "Still going?" reports only mean something while the sale is on.
bool salePhaseTakesReports(SalePhase p) => p == SalePhase.open || p == SalePhase.closingSoon;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Opens Sat 7a · in 6 days", "Opens in 45 min", "Open now · until 11a", "Ended".
String saleStatus(DateTime opens, DateTime? closes, DateTime now) {
  final until = closes == null ? '' : ' · until ${compactTime(closes)}';
  switch (salePhase(opens, closes, now)) {
    case SalePhase.upcoming:
      final days = calendarDaysBetween(now, opens);
      final day = switch (days) {
        0 => 'today',
        1 => 'tomorrow',
        _ => _weekdays[opens.weekday - 1],
      };
      return 'Opens $day ${compactTime(opens)}${days > 1 ? ' · in $days days' : ''}';
    case SalePhase.startingSoon:
      final m = opens.difference(now).inMinutes;
      return 'Opens in ${m < 60 ? '$m min' : '${(m / 60).round()}h'}';
    case SalePhase.open:
      return 'Open now$until';
    case SalePhase.closingSoon:
      return 'Closing soon$until';
    case SalePhase.ended:
      return 'Ended';
  }
}

/// The Saturday a new sale defaults to: this one, unless its usual window
/// (closing at [closesHour]) is already over, then next week's.
DateTime nextSaleDay(DateTime now, {int closesHour = 13}) {
  final add = (DateTime.saturday - now.weekday) % 7;
  return dayPlus(now, add == 0 && now.hour >= closesHour ? 7 : add);
}

/// Why a sale window can't be posted, or null if it can.
String? saleWindowError(DateTime opens, DateTime closes, DateTime now) {
  if (!closes.isAfter(opens)) return 'Closing time has to be after opening time.';
  if (!closes.isAfter(now)) return 'That time has already passed. Pick a later day or hours.';
  return null;
}

/// A sale someone is looking at right now: from this hour, for four hours
/// (not past 11pm).
({DateTime opens, DateTime closes}) spottedWindow(DateTime now) {
  final opens = DateTime(now.year, now.month, now.day, now.hour);
  final end = DateTime(now.year, now.month, now.day, 23);
  final closes = opens.add(const Duration(hours: 4));
  return (opens: opens, closes: closes.isAfter(end) ? end : closes);
}
