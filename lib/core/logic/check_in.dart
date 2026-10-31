// "Still going?" check-ins: the open listing you're standing at, if any. Pure.
import 'geo.dart';

typedef CheckInListing = ({String id, double lat, double lng, DateTime opensAt, DateTime? closesAt});

/// The nearest listing within [meters] that's open at [now] (from opening until
/// closing), or null. Close enough means you're at it, not driving past.
String? checkInCandidate(Iterable<CheckInListing> listings, double lat, double lng, DateTime now, {double meters = 100}) {
  String? best;
  var bestM = double.infinity;
  for (final l in listings) {
    if (now.isBefore(l.opensAt) || (l.closesAt != null && !now.isBefore(l.closesAt!))) continue;
    final m = haversineMeters(lat, lng, l.lat, l.lng);
    if (m <= meters && m < bestM) {
      best = l.id;
      bestM = m;
    }
  }
  return best;
}

/// The key that remembers "don't ask about this one again today".
String checkInKey(String id, DateTime now) => '$id@${now.year}-${now.month}-${now.day}';
