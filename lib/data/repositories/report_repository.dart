import '../models/report.dart';
import '../models/store_summary.dart';
import '../supabase_client.dart';

class ReportRepository {
  Future<Report> create(ReportDraft draft, String userId) async {
    final row = await sb.from('reports').insert(draft.toInsert(userId)).select('*, products(display_name)').single();
    return Report.fromRow(row);
  }

  Future<List<Report>> recentForPin(String pinId, {int limit = 10}) async {
    final rows = await sb
        .from('reports')
        .select('*, products(display_name)')
        .eq('pin_id', pinId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Report.fromRow).toList();
  }

  /// Latest report per pin, for freshness rings on the map.
  Future<Map<String, Report>> latestForPins(List<String> pinIds) async {
    if (pinIds.isEmpty) return {};
    final rows = await sb
        .from('reports')
        .select('*, products(display_name)')
        .inFilter('pin_id', pinIds)
        .gte('created_at', DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String())
        .order('created_at', ascending: false);
    final out = <String, Report>{};
    for (final r in rows) {
      final rep = Report.fromRow(r);
      out.putIfAbsent(rep.pinId, () => rep);
    }
    return out;
  }

  Future<StoreSummary> storeSummary(String pinId) async {
    final json = await sb.rpc('store_summary', params: {'p_pin': pinId});
    if (json == null) return StoreSummary.empty;
    return StoreSummary.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<Map<String, StoreSummary>> summaries(List<String> pinIds) async {
    final out = <String, StoreSummary>{};
    for (final id in pinIds) {
      out[id] = await storeSummary(id);
    }
    return out;
  }

  Future<void> delete(String reportId) => sb.from('reports').delete().eq('id', reportId);

  Stream<List<Map<String, dynamic>>> stream() =>
      sb.from('reports').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(50);
}
