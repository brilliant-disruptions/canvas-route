import '../models/visit.dart';
import '../supabase_client.dart';

class VisitRepository {
  Future<List<Visit>> forRoute(String routeId) async {
    final rows = await sb.from('visits').select().eq('route_id', routeId);
    return rows.map(Visit.fromRow).toList();
  }

  Future<List<Visit>> forUser(String userId) async {
    final rows = await sb.from('visits').select().eq('user_id', userId).order('updated_at', ascending: false);
    return rows.map(Visit.fromRow).toList();
  }

  /// One visit per stop; re-logging overwrites.
  Future<Visit> upsert(Map<String, dynamic> insert) async {
    final row = await sb.from('visits').upsert(insert, onConflict: 'stop_id').select().single();
    return Visit.fromRow(row);
  }

  Future<void> delete(String visitId) => sb.from('visits').delete().eq('id', visitId);
}
