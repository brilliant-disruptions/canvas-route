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

  /// Clears public identity. Plans and purchases are the store's to cancel, not ours to write.
  Future<Profile> deactivate(String userId) => update(userId, {'handle': null, 'name': null});

  Future<bool> handleAvailable(String handle) async {
    // Other users' rows aren't readable; the public view exposes only id, handle and trust.
    final row = await sb.from('profiles_public').select('id').eq('handle', handle).maybeSingle();
    return row == null;
  }
}
