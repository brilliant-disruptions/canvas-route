import 'package:canvas_route/core/logic/restock.dart';
import 'package:canvas_route/core/logic/spotlight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 9, 0); // Saturday
  const lat = 32.8140, lng = -96.7900;
  String label(String s) => {'in_stock': 'In stock', 'sold_out': 'Sold out'}[s] ?? s;
  List<Spot> rank(List<SpotCandidate> c) => rankSpots(c, fromLat: lat, fromLng: lng, now: now);

  test('a fresh in-stock report outranks a closer quiet store', () {
    final r = rank([
      const SpotCandidate(id: 'near', lat: lat + 0.001, lng: lng),
      SpotCandidate(
        id: 'live',
        lat: lat + 0.03,
        lng: lng,
        reportStatus: 'in_stock',
        reportPositive: true,
        reportedAt: now.subtract(const Duration(minutes: 9)),
      ),
    ]);
    expect(r.first.candidate.id, 'live');
    expect(r.first.reason, SpotReason.liveStock);
    expect(toneFor(r.first.reason), SpotTone.hot);
    expect(spotHeadline(r.first, now: now, statusLabel: label), 'In stock · 9 min ago');
  });

  test('a recent sell-out sinks and is never planned', () {
    final r = rank([
      SpotCandidate(
        id: 'gone',
        lat: lat,
        lng: lng,
        reportStatus: 'sold_out',
        reportedAt: now.subtract(const Duration(hours: 1)),
      ),
      const SpotCandidate(id: 'quiet', lat: lat + 0.02, lng: lng),
    ]);
    expect(r.last.candidate.id, 'gone');
    expect(r.last.reason, SpotReason.soldOut);
    expect(pickPlan(r, 5).map((s) => s.candidate.id), ['quiet']);
  });

  test('ended windows are dropped; open and upcoming sales are labeled', () {
    final r = rank([
      SpotCandidate(
        id: 'ended',
        lat: lat,
        lng: lng,
        opensAt: now.subtract(const Duration(hours: 3)),
        closesAt: now.subtract(const Duration(minutes: 1)),
      ),
      SpotCandidate(
        id: 'open',
        lat: lat,
        lng: lng,
        opensAt: DateTime(2026, 10, 31, 7),
        closesAt: DateTime(2026, 10, 31, 13),
      ),
      SpotCandidate(
        id: 'next',
        lat: lat,
        lng: lng,
        opensAt: DateTime(2026, 11, 7, 7),
        closesAt: DateTime(2026, 11, 7, 12),
      ),
    ]);
    expect(r.map((s) => s.candidate.id), ['open', 'next']);
    expect(spotHeadline(r[0], now: now, statusLabel: label), 'Open now · until 1pm');
    expect(spotHeadline(r[1], now: now, statusLabel: label), 'Opens Sat 7am–12pm');
  });

  test('restock windows: inside beats later; tier adds confidence', () {
    final day = DateTime(2026, 10, 31);
    final r = rank([
      SpotCandidate(
        id: 'later',
        lat: lat,
        lng: lng,
        tier: RestockTier.established,
        restockToday: (start: day.add(const Duration(hours: 11)), end: day.add(const Duration(hours: 13))),
      ),
      SpotCandidate(
        id: 'now',
        lat: lat,
        lng: lng,
        tier: RestockTier.emerging,
        restockToday: (start: day.add(const Duration(hours: 8)), end: day.add(const Duration(hours: 10))),
      ),
    ]);
    expect(r.map((s) => s.candidate.id), ['now', 'later']);
    expect(spotHeadline(r[0], now: now, statusLabel: label), 'Restock window now · until 10am');
    expect(spotHeadline(r[1], now: now, statusLabel: label), 'Restocks 11am–1pm');
  });

  test('with no signals, nearest wins and pickPlan caps the count', () {
    final r = rank([for (var i = 5; i > 0; i--) SpotCandidate(id: '$i', lat: lat + i * 0.01, lng: lng)]);
    expect(r.map((s) => s.candidate.id), ['1', '2', '3', '4', '5']);
    expect(pickPlan(r, 3), hasLength(3));
    expect(r.first.reason, SpotReason.nearby);
  });

  group('yard sales on a live Saturday', () {
    final open = now.subtract(const Duration(hours: 2)), closes = now.add(const Duration(hours: 4));
    SpotCandidate sale(String id, {double dLat = 0.01, String? status, bool caution = false, bool ends = false, bool positive = false, int minsAgo = 10}) =>
        SpotCandidate(
          id: id,
          lat: lat + dLat,
          lng: lng,
          opensAt: open,
          closesAt: closes,
          reportStatus: status,
          reportPositive: positive,
          reportCaution: caution,
          reportEnds: ends,
          reportedAt: status == null ? null : now.subtract(Duration(minutes: minsAgo)),
        );

    test('a packed-up sale drops to the bottom and is never planned, however close', () {
      final r = rank([sale('packed', dLat: 0.001, status: 'packed_up', ends: true), sale('quiet', dLat: 0.02)]);
      expect(r.first.candidate.id, 'quiet');
      expect(r.last.reason, SpotReason.packedUp);
      expect(pickPlan(r, 8).map((s) => s.candidate.id), ['quiet']);
      expect(spotHeadline(r.last, now: now, statusLabel: (s) => 'Packed up'), 'Packed up · 10 min ago');
    });

    test('closing soon is still planned, above a quiet open sale but below a confirmed one', () {
      final r = rank([
        sale('quiet', dLat: 0.001),
        sale('closing', status: 'closing_soon', caution: true),
        sale('going', status: 'still_open', positive: true),
      ]);
      expect(r.map((s) => s.candidate.id), ['going', 'closing', 'quiet']);
      expect(r[1].reason, SpotReason.closingSoon);
      expect(r[1].plannable, isTrue);
      expect(toneFor(r[1].reason), SpotTone.warn);
    });

    test('old reports stop counting', () {
      final r = rank([sale('stale', status: 'closing_soon', caution: true, minsAgo: 90)]);
      expect(r.single.reason, SpotReason.openNow);
    });
  });
}
