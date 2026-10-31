// Trust levels shown to reporters. Thresholds mirror the server: reports filed
// at trust 30+ count toward restock patterns (migration 006).

enum TrustLevel { newcomer, regular, trusted, pillar }

class TrustStanding {
  const TrustStanding({required this.level, required this.label, required this.floor, this.next, required this.unlock});
  final TrustLevel level;
  final String label;

  /// Score where this level starts, and where the next one does (null at the top).
  final int floor;
  final int? next;

  /// What this level means for the user's reports.
  final String unlock;

  /// 0–1 progress toward [next]; 1 at the top level.
  double progress(int score) => next == null ? 1 : ((score - floor) / (next! - floor)).clamp(0, 1).toDouble();
}

const patternThreshold = 30;

TrustStanding trustStanding(int score) {
  if (score >= 85) {
    return const TrustStanding(
      level: TrustLevel.pillar,
      label: 'Pillar',
      floor: 85,
      unlock: 'One of the most reliable reporters around. Your reports count toward restock patterns.',
    );
  }
  if (score >= 60) {
    return const TrustStanding(
      level: TrustLevel.trusted,
      label: 'Trusted',
      floor: 60,
      next: 85,
      unlock: 'A reliable reporter. Your reports count toward restock patterns.',
    );
  }
  if (score >= patternThreshold) {
    return const TrustStanding(
      level: TrustLevel.regular,
      label: 'Regular',
      floor: patternThreshold,
      next: 60,
      unlock: 'Your reports count toward restock patterns.',
    );
  }
  return const TrustStanding(
    level: TrustLevel.newcomer,
    label: 'New',
    floor: 0,
    next: patternThreshold,
    unlock: 'Keep reporting: at Regular, your reports start counting toward restock patterns.',
  );
}
