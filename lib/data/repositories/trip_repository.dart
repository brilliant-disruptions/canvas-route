import '../models/trip.dart';
import '../supabase_client.dart';

class TripRepository {
  Future<List<Trip>> forUser(String userId, String mode) async {
    final rows = await sb.from('trips').select().eq('user_id', userId).eq('mode', mode).order('day', ascending: false);
    return rows.map(Trip.fromRow).toList();
  }

  /// One trip per route; logging the same run again updates it.
  Future<Trip> upsert(Map<String, dynamic> insert) async {
    final row = await sb.from('trips').upsert(insert, onConflict: 'route_id').select().single();
    return Trip.fromRow(row);
  }
}
