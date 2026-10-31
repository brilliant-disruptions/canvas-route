// Short labels that fit on a map pin.

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
