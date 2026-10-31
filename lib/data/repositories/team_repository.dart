import '../models/team.dart';
import '../supabase_client.dart';

/// Teams go through security-definer functions (migration 016); the tables are read-only here.
class TeamRepository {
  Future<Team?> mine() async {
    final row = await sb.from('teams').select().maybeSingle();
    if (row == null) return null;
    return Team.fromRow(row, covered: await sb.rpc('my_team_covered') as bool? ?? false);
  }

  Future<List<TeamMember>> roster() async {
    final rows = await sb.rpc('team_roster') as List;
    return [for (final r in rows) TeamMember.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  Future<List<RepActivity>> activity(int days) async {
    final rows = await sb.rpc('team_activity', params: {'p_days': days}) as List;
    return [for (final r in rows) RepActivity.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  Future<List<TeammateVisit>> visitsAt(String placeId) async {
    final rows = await sb.rpc('team_visits_at', params: {'p_place_id': placeId}) as List;
    return [for (final r in rows) TeammateVisit.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  Future<Team> create(String name) async =>
      Team.fromRow(Map<String, dynamic>.from(await sb.rpc('create_team', params: {'p_name': name}) as Map));

  /// Wrong codes come back empty rather than as an error (so the server's guess
  /// throttle can count them).
  Future<Team> join(String code) async {
    final res = await sb.rpc('join_team', params: {'p_code': code});
    if (res is! Map || res['id'] == null) throw StateError('No team with that code. Check it with your manager.');
    return Team.fromRow(Map<String, dynamic>.from(res));
  }

  Future<void> leave() => sb.rpc('leave_team');

  /// Managers only: a fresh join code, invalidating the old one.
  Future<String> rotateCode() async => await sb.rpc('rotate_join_code') as String;

  Future<void> remove(String userId) => sb.rpc('remove_teammate', params: {'p_user': userId});
}
