// The public sale page's helpers: what else is on that day nearby, and an
// "Add to calendar" link that works without installing anything. Pure; no Flutter.
import 'geo.dart';

typedef PageListing = ({String id, double lat, double lng, DateTime? opensAt, DateTime? closesAt});

/// Other listings on the same calendar day as [anchor], within [maxMiles] of it,
/// not yet over at [now], nearest first.
List<String> sameDayNearby(PageListing anchor, Iterable<PageListing> others, DateTime now, {double maxMiles = 3}) {
  final day = anchor.opensAt;
  if (day == null) return const [];
  final hits = <(String, double)>[];
  for (final o in others) {
    if (o.id == anchor.id || o.opensAt == null) continue;
    if (o.opensAt!.year != day.year || o.opensAt!.month != day.month || o.opensAt!.day != day.day) continue;
    if (o.closesAt != null && !o.closesAt!.isAfter(now)) continue;
    final miles = metersToMiles(haversineMeters(anchor.lat, anchor.lng, o.lat, o.lng));
    if (miles <= maxMiles) hits.add((o.id, miles));
  }
  hits.sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final h in hits) h.$1];
}

String _utc(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// A Google Calendar "add event" link (opens in any browser, signed in or not).
Uri googleCalendarLink({
  required String title,
  required DateTime start,
  DateTime? end,
  String? location,
  String? details,
}) =>
    Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${_utc(start)}/${_utc(end ?? start.add(const Duration(hours: 2)))}',
      'location': ?location,
      'details': ?details,
    });
