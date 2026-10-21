import 'dart:io';

import '../models/alert_item.dart';
import '../supabase_client.dart';

class AlertRepository {
  Future<List<AlertItem>> list(String userId) async {
    final rows = await sb.from('alerts').select().eq('user_id', userId).order('sent_at', ascending: false).limit(100);
    return rows.map(AlertItem.fromRow).toList();
  }

  Future<void> markOpened(String id) =>
      sb.from('alerts').update({'opened_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  Future<void> registerPushToken(String userId, String token) => sb.from('push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  Stream<List<Map<String, dynamic>>> stream(String userId) =>
      sb.from('alerts').stream(primaryKey: ['id']).eq('user_id', userId).order('sent_at', ascending: false).limit(50);
}
