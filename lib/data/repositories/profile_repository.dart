import '../models/app_mode.dart';
import '../models/profile.dart';
import '../supabase_client.dart';

class ProfileRepository {
  Future<Profile?> fetch(String userId) async {
    final row = await sb.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  Future<Profile> update(String userId, Map<String, dynamic> patch) async {
    final row = await sb.from('profiles').update(patch).eq('id', userId).select().single();
    return Profile.fromRow(row);
  }

  Future<Profile> setActiveMode(String userId, AppMode mode) => update(userId, {'active_mode': mode.id});

  Future<Profile> setOnboarded(String userId) => update(userId, {'has_onboarded': true});

  Future<Profile> setHome(String userId, double lat, double lng) =>
      update(userId, {'home_lat': lat, 'home_lng': lng});


  Future<bool> handleAvailable(String handle) async {
    // A yes/no answer only: handles must not resolve to user ids (migration 019).
    return await sb.rpc('handle_available', params: {'p_handle': handle}) as bool? ?? false;
  }
}
