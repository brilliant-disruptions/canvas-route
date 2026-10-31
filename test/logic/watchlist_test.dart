import 'package:canvas_route/core/logic/watchlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 31, 9);
  Sighting s(String pin, String? product, {bool positive = true, int minsAgo = 0, String status = 'in_stock'}) =>
      Sighting(
        pinId: pin,
        pinName: pin,
        productId: product,
        status: status,
        positive: positive,
        at: t0.subtract(Duration(minutes: minsAgo)),
      );

  test('live products first, newest sighting first, one entry per store', () {
    final out = watchStatuses(
      ['etb', 'box', 'tin'],
      [
        s('Target', 'box', minsAgo: 30),
        s('GameStop', 'etb', minsAgo: 9),
        s('GameStop', 'etb', minsAgo: 50),
        s('Walmart', 'etb', minsAgo: 20),
        s('Costco', 'tin', positive: false, status: 'sold_out', minsAgo: 5),
      ],
    );
    expect(out.map((w) => w.productId), ['etb', 'box', 'tin']);
    expect(out.first.inStock.map((x) => x.pinId), ['GameStop', 'Walmart']);
    expect(out.last.live, isFalse);
    expect(out.last.lastSeen!.status, 'sold_out');
  });

  test('quiet products keep the user\'s order', () {
    final out = watchStatuses(['a', 'b'], const []);
    expect(out.map((w) => w.productId), ['a', 'b']);
    expect(out.first.lastSeen, isNull);
  });

  test('trending ranks unfollowed products by store count', () {
    final t = trendingProducts(
      [s('Target', 'x'), s('Walmart', 'x'), s('Target', 'y'), s('Target', 'etb'), s('Costco', 'z', positive: false)],
      {'etb'},
    );
    expect(t, ['x', 'y']);
  });

  test('whereLabel caps names', () {
    expect(whereLabel([s('Target', 'x'), s('GameStop', 'x'), s('Walmart', 'x')]), 'Target, GameStop +1');
    expect(whereLabel([s('Target', 'x')]), 'Target');
  });
}
