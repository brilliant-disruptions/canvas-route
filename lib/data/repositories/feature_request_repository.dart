import '../models/feature_request.dart';
import '../supabase_client.dart';

class FeatureRequestRepository {
  Future<List<FeatureRequest>> all({String sort = 'upvotes', String? category}) async {
    var q = sb.from('feature_requests').select().not('status', 'in', '("queued","discarded")');
    if (category != null) q = q.eq('category', category);
    final rows = switch (sort) {
      'status' => await q.order('status'),
      'date' => await q.order('created_at', ascending: false),
      _ => await q.order('upvote_count', ascending: false),
    };
    return rows.map(FeatureRequest.fromRow).toList();
  }

  Future<List<FeatureRequest>> mine(String userId) async {
    final rows = await sb.from('feature_requests').select().eq('user_id', userId).order('created_at', ascending: false);
    return rows.map(FeatureRequest.fromRow).toList();
  }

  Future<List<FeatureRequest>> adminQueue() async {
    final rows = await sb.from('feature_requests').select().order('created_at', ascending: false);
    return rows.map(FeatureRequest.fromRow).toList();
  }

  Future<FeatureRequest> create(Map<String, dynamic> insert) async {
    final row = await sb.from('feature_requests').insert(insert).select().single();
    return FeatureRequest.fromRow(row);
  }

  Future<Set<String>> myUpvotes(String userId) async {
    final rows = await sb.from('upvotes').select('request_id').eq('user_id', userId);
    return rows.map((r) => r['request_id'] as String).toSet();
  }

  Future<void> upvote(String userId, String requestId) =>
      sb.from('upvotes').upsert({'user_id': userId, 'request_id': requestId});

  Future<void> unvote(String userId, String requestId) =>
      sb.from('upvotes').delete().eq('user_id', userId).eq('request_id', requestId);

  Future<void> setStatus(String id, String status, {String? summary, String? parentId}) =>
      sb.from('feature_requests').update({
        'status': status,
        'summary': ?summary,
        'parent_id': ?parentId,
      }).eq('id', id);

  Future<List<Map<String, dynamic>>> comments(String requestId) =>
      sb.from('feature_request_comments').select().eq('request_id', requestId).order('created_at');

  Future<void> comment(String userId, String requestId, String body) =>
      sb.from('feature_request_comments').insert({'user_id': userId, 'request_id': requestId, 'body': body});
}
