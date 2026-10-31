import '../models/json_utils.dart';
import '../models/visit.dart';
import '../supabase_client.dart';

class VisitRepository {
  Future<List<Visit>> forRoute(String routeId) async {
    final rows = await sb.from('visits').select().eq('route_id', routeId);
    return rows.map(Visit.fromRow).toList();
  }

  /// Every visit, newest first. Paged: the API returns at most 1000 rows a call,
  /// and follow-ups and history must not silently lose older visits.
  Future<List<Visit>> forUser(String userId) async {
    const page = 1000;
    final out = <Visit>[];
    for (var from = 0;; from += page) {
      final rows = await sb
          .from('visits')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .order('id')
          .range(from, from + page - 1);
      out.addAll(rows.map(Visit.fromRow));
      if (rows.length < page) return out;
    }
  }

  /// One visit per stop; re-logging overwrites.
  Future<Visit> upsert(Map<String, dynamic> insert) async {
    final row = await sb.from('visits').upsert(insert, onConflict: 'stop_id').select().single();
    return Visit.fromRow(row);
  }

  /// Sets or clears (null) when to follow up on a visit.
  Future<void> setFollowUp(String visitId, DateTime? date) => sb
      .from('visits')
      .update({'follow_up_date': date == null ? null : dateOnly(date)})
      .eq('id', visitId);

  Future<void> delete(String visitId) => sb.from('visits').delete().eq('id', visitId);
}
