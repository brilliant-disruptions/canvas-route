import '../models/settings.dart';
import '../supabase_client.dart';

class SettingsRepository {
  Future<Settings> fetch(String userId) async {
    final row = await sb.from('settings').select().eq('user_id', userId).maybeSingle();
    if (row != null) return Settings.fromRow(row);
    final created = await sb.from('settings').insert({'user_id': userId}).select().single();
    return Settings.fromRow(created);
  }

  Future<Settings> save(Settings s) async {
    final row = await sb.from('settings').update(s.toUpdate()).eq('user_id', s.userId).select().single();
    return Settings.fromRow(row);
  }
}
