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

  Future<Team> join(String code) async =>
      Team.fromRow(Map<String, dynamic>.from(await sb.rpc('join_team', params: {'p_code': code}) as Map));

  Future<void> leave() => sb.rpc('leave_team');

  Future<void> remove(String userId) => sb.rpc('remove_teammate', params: {'p_user': userId});
}
