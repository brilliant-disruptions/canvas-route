import 'json_utils.dart';

class Team {
  const Team({required this.id, required this.name, required this.joinCode, required this.ownerId, this.covered = false});
  final String id;
  final String name;
  final String joinCode;
  final String ownerId;

  /// The owner holds the Team plan, so every member gets the paid tier.
  final bool covered;

  factory Team.fromRow(Map<String, dynamic> r, {bool covered = false}) => Team(
        covered: covered,
        id: r['id'] as String,
        name: r['name'] as String,
        joinCode: r['join_code'] as String,
        ownerId: r['owner_id'] as String,
      );
}

class TeamMember {
  const TeamMember({required this.userId, required this.name, required this.isManager});
  final String userId;
  final String name;
  final bool isManager;

  factory TeamMember.fromRow(Map<String, dynamic> r) =>
      TeamMember(userId: r['user_id'] as String, name: r['name'] as String, isManager: r['role'] == 'manager');
}

/// One rep's numbers over a period, for the manager's view.
class RepActivity {
  const RepActivity({
    required this.userId,
    required this.name,
    required this.visits,
    required this.outcomes,
    required this.meters,
    this.lastVisitAt,
  });
  final String userId;
  final String name;
  final int visits;
  final Map<String, int> outcomes;
  final int meters;
  final DateTime? lastVisitAt;

  int count(Iterable<String> outcomeNames) => outcomeNames.fold(0, (s, o) => s + (outcomes[o] ?? 0));

  factory RepActivity.fromRow(Map<String, dynamic> r) => RepActivity(
        userId: r['user_id'] as String,
        name: r['name'] as String,
        visits: intOr(r['visits'], 0),
        outcomes: {for (final e in ((r['outcomes'] as Map?) ?? const {}).entries) e.key as String: intOr(e.value, 0)},
        meters: intOr(r['meters'], 0),
        lastVisitAt: r['last_visit_at'] == null ? null : DateTime.parse(r['last_visit_at'] as String).toLocal(),
      );
}

/// A teammate's latest outcome at a business (no notes), to avoid double knocks.
class TeammateVisit {
  const TeammateVisit({required this.name, required this.visitedAt, this.outcome});
  final String name;
  final String? outcome;
  final DateTime visitedAt;

  factory TeammateVisit.fromRow(Map<String, dynamic> r) => TeammateVisit(
        name: r['name'] as String,
        outcome: r['outcome'] as String?,
        visitedAt: DateTime.parse(r['visited_at'] as String).toLocal(),
      );
}
