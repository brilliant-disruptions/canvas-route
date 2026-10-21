import '../../core/logic/restock.dart';
import 'json_utils.dart';

class StoreSummary {
  const StoreSummary({
    required this.totalHits,
    required this.totalReports,
    required this.tier,
    required this.bestWindows,
    required this.recent,
    this.lastSeen,
  });

  final int totalHits;
  final int totalReports;
  final DateTime? lastSeen;
  final RestockTier tier;
  final List<({int dow, int hour, int hits})> bestWindows;
  final List<Map<String, dynamic>> recent;

  static const empty = StoreSummary(totalHits: 0, totalReports: 0, tier: RestockTier.unknown, bestWindows: [], recent: []);

  String? get bestWindowLabel => bestWindows.isEmpty
      ? null
      : describeWindow(dow: bestWindows.first.dow, hour: bestWindows.first.hour, hits: bestWindows.first.hits);

  factory StoreSummary.fromJson(Map<String, dynamic> j) {
    final hits = intOr(j['total_hits'], 0);
    return StoreSummary(
      totalHits: hits,
      totalReports: intOr(j['total_reports'], 0),
      lastSeen: dtOrNull(j['last_seen']),
      tier: tierForHits(hits),
      bestWindows: ((j['best_windows'] as List?) ?? const [])
          .map((w) => (dow: (w['dow'] as num).toInt(), hour: (w['hour'] as num).toInt(), hits: (w['hits'] as num).toInt()))
          .toList(),
      recent: ((j['recent'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}
