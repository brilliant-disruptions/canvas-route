// Followed products × nearby reports → what to show on the watchlist. Pure.

class Sighting {
  const Sighting({
    required this.pinId,
    required this.pinName,
    required this.productId,
    required this.status,
    required this.positive,
    required this.at,
  });

  final String pinId;
  final String pinName;
  final String? productId;
  final String status;
  final bool positive;
  final DateTime at;
}

class WatchStatus {
  const WatchStatus({required this.productId, required this.inStock, this.lastSeen});
  final String productId;

  /// Positive sightings at distinct stores, newest first.
  final List<Sighting> inStock;

  /// Latest sighting of any status, when there's no positive one.
  final Sighting? lastSeen;

  bool get live => inStock.isNotEmpty;
}

/// One status per followed product, live ones first.
List<WatchStatus> watchStatuses(List<String> followed, List<Sighting> sightings) {
  final sorted = [...sightings]..sort((a, b) => b.at.compareTo(a.at));
  final out = <WatchStatus>[];
  for (final id in followed) {
    final mine = sorted.where((s) => s.productId == id).toList();
    final stores = <String>{};
    final inStock = [
      for (final s in mine.where((s) => s.positive))
        if (stores.add(s.pinId)) s,
    ];
    out.add(WatchStatus(productId: id, inStock: inStock, lastSeen: inStock.isEmpty ? mine.firstOrNull : null));
  }
  final order = {for (var i = 0; i < followed.length; i++) followed[i]: i};
  out.sort((a, b) {
    if (a.live != b.live) return a.live ? -1 : 1;
    if (a.live) return b.inStock.first.at.compareTo(a.inStock.first.at);
    return order[a.productId]!.compareTo(order[b.productId]!);
  });
  return out;
}

/// Products seen in stock nearby that the user doesn't follow, most stores first.
List<String> trendingProducts(List<Sighting> sightings, Set<String> followed, {int max = 6}) {
  final stores = <String, Set<String>>{};
  for (final s in sightings) {
    final id = s.productId;
    if (!s.positive || id == null || followed.contains(id)) continue;
    stores.putIfAbsent(id, () => {}).add(s.pinId);
  }
  final ranked = stores.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
  return ranked.take(max).map((e) => e.key).toList();
}

/// "In stock at Target, GameStop +1".
String whereLabel(List<Sighting> inStock, {int names = 2}) {
  final shown = inStock.take(names).map((s) => s.pinName).join(', ');
  final more = inStock.length - names;
  return more > 0 ? '$shown +$more' : shown;
}
