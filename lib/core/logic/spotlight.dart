// Spotlight ranking: which nearby stops are worth going to right now.
// Pure so the map's deck and one-tap planner stay testable.

import 'geo.dart';
import 'restock.dart';

/// Why a spot ranked where it did; drives the card's headline and tone.
enum SpotReason { liveStock, recentPositive, restockNow, restockLater, openNow, opensSoon, upcoming, soldOut, nearby }

enum SpotTone { hot, good, neutral, warn }

class SpotCandidate {
  const SpotCandidate({
    required this.id,
    required this.lat,
    required this.lng,
    this.opensAt,
    this.closesAt,
    this.reportStatus,
    this.reportPositive = false,
    this.reportedAt,
    this.reportProduct,
    this.tier = RestockTier.unknown,
    this.restockToday,
  });

  final String id;
  final double lat;
  final double lng;
  final DateTime? opensAt;
  final DateTime? closesAt;

  /// Latest community report, if any.
  final String? reportStatus;
  final bool reportPositive;
  final DateTime? reportedAt;
  final String? reportProduct;
  final RestockTier tier;

  /// The store's best restock window on the planned day.
  final ({DateTime start, DateTime end})? restockToday;
}

class Spot {
  const Spot({required this.candidate, required this.score, required this.reason, required this.distanceMeters});
  final SpotCandidate candidate;
  final double score;
  final SpotReason reason;
  final double distanceMeters;

  /// Worth auto-adding to a plan; a recent sell-out is shown but not planned.
  bool get plannable => reason != SpotReason.soldOut;
}

/// Ranks candidates around ([fromLat], [fromLng]). Ended windows are dropped.
List<Spot> rankSpots(
  List<SpotCandidate> candidates, {
  required double fromLat,
  required double fromLng,
  required DateTime now,
}) {
  final out = <Spot>[];
  for (final c in candidates) {
    if (c.closesAt != null && !c.closesAt!.isAfter(now)) continue;
    final meters = haversineMeters(fromLat, fromLng, c.lat, c.lng);
    var score = -metersToMiles(meters) * 4;
    var reason = SpotReason.nearby;
    var best = 0.0;

    void consider(double s, SpotReason r) {
      if (s > best) {
        best = s;
        reason = r;
      }
    }

    final age = c.reportedAt == null ? null : now.difference(c.reportedAt!);
    if (age != null && c.reportPositive) {
      if (isFresh(c.reportedAt!, now: now)) {
        consider(100, SpotReason.liveStock);
      } else if (age <= const Duration(hours: 3)) {
        consider(60, SpotReason.recentPositive);
      }
    }
    final w = c.restockToday;
    if (w != null) {
      if (!now.isBefore(w.start) && now.isBefore(w.end)) {
        consider(70, SpotReason.restockNow);
      } else if (now.isBefore(w.start)) {
        consider(45, SpotReason.restockLater);
      }
    }
    if (c.opensAt != null) {
      if (!now.isBefore(c.opensAt!)) {
        consider(40, SpotReason.openNow);
      } else if (c.opensAt!.difference(now) <= const Duration(hours: 3)) {
        consider(35, SpotReason.opensSoon);
      } else {
        consider(25, SpotReason.upcoming);
      }
    }
    score += best;
    score += switch (c.tier) {
      RestockTier.established => 15,
      RestockTier.emerging => 8,
      RestockTier.unknown => 0,
    };
    if (age != null && !c.reportPositive && age <= const Duration(hours: 6) && best < 60) {
      score -= 40;
      reason = SpotReason.soldOut;
    }
    out.add(Spot(candidate: c, score: score, reason: reason, distanceMeters: meters));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}

/// Top [max] plannable spots, best first.
List<Spot> pickPlan(List<Spot> ranked, int max) => ranked.where((s) => s.plannable).take(max).toList();

SpotTone toneFor(SpotReason r) => switch (r) {
  SpotReason.liveStock || SpotReason.restockNow => SpotTone.hot,
  SpotReason.recentPositive || SpotReason.openNow || SpotReason.opensSoon || SpotReason.restockLater => SpotTone.good,
  SpotReason.soldOut => SpotTone.warn,
  SpotReason.upcoming || SpotReason.nearby => SpotTone.neutral,
};

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute == 0 ? '' : ':${t.minute.toString().padLeft(2, '0')}';
  return '$h$m${t.hour < 12 ? 'am' : 'pm'}';
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// One-line card headline, e.g. "In stock · 9 min ago" or "Opens Sat 7am".
/// [statusLabel] maps a report status value to the mode's label.
String spotHeadline(Spot s, {required DateTime now, required String Function(String status) statusLabel}) {
  final c = s.candidate;
  String day(DateTime t) =>
      t.year == now.year && t.month == now.month && t.day == now.day ? 'today' : _days[t.weekday - 1];
  return switch (s.reason) {
    SpotReason.liveStock ||
    SpotReason.recentPositive ||
    SpotReason.soldOut => '${statusLabel(c.reportStatus!)} · ${relativeAge(c.reportedAt!, now: now)}',
    SpotReason.restockNow => 'Restock window now · until ${_clock(c.restockToday!.end)}',
    SpotReason.restockLater => 'Restocks ${_clock(c.restockToday!.start)}–${_clock(c.restockToday!.end)}',
    SpotReason.openNow => c.closesAt == null ? 'Open now' : 'Open now · until ${_clock(c.closesAt!)}',
    SpotReason.opensSoon =>
      'Opens in ${c.opensAt!.difference(now).inMinutes < 60 ? '${c.opensAt!.difference(now).inMinutes} min' : '${(c.opensAt!.difference(now).inMinutes / 60).round()}h'}',
    SpotReason.upcoming =>
      'Opens ${day(c.opensAt!)} ${_clock(c.opensAt!)}${c.closesAt == null ? '' : '–${_clock(c.closesAt!)}'}',
    SpotReason.nearby => formatDistance(s.distanceMeters),
  };
}
