import '../models/app_mode.dart';
import '../supabase_client.dart';

/// The closest live listing to a point, for "Sales are live in Dallas, 240 mi away".
class NearestLive {
  const NearestLive({required this.lat, required this.lng, required this.miles, this.address});
  final double lat;
  final double lng;
  final double miles;
  final String? address;

  /// "Dallas" from "6120 Velasco Ave, Dallas, TX".
  String? get city {
    final parts = (address ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts.length >= 3 ? parts[parts.length - 2] : null;
  }
}

class DemandCell {
  const DemandCell({required this.lat, required this.lng, required this.hunters, required this.liveSales, this.newest});
  final double lat;
  final double lng;
  final int hunters;
  final int liveSales;
  final DateTime? newest;
}

/// Hunters waiting for listings in an area (migration 020). Locations go to the
/// server only as points; it keeps a rounded ~7-mile cell and returns counts.
class DemandRepository {
  Future<int> register(AppMode mode, double lat, double lng) async =>
      await sb.rpc('register_hunt_interest', params: {'p_mode': mode.id, 'p_lat': lat, 'p_lng': lng}) as int;

  Future<int> waiting(AppMode mode, double lat, double lng) async =>
      await sb.rpc('hunters_waiting', params: {'p_mode': mode.id, 'p_lat': lat, 'p_lng': lng}) as int;

  Future<bool> mine(AppMode mode, double lat, double lng) async =>
      await sb.rpc('my_hunt_interest', params: {'p_mode': mode.id, 'p_lat': lat, 'p_lng': lng}) as bool;

  Future<NearestLive?> nearestLive(AppMode mode, double lat, double lng) async {
    final rows = await sb.rpc('nearest_live_pin', params: {'p_mode': mode.id, 'p_lat': lat, 'p_lng': lng}) as List;
    if (rows.isEmpty) return null;
    final r = rows.first as Map;
    return NearestLive(
      lat: (r['lat'] as num).toDouble(),
      lng: (r['lng'] as num).toDouble(),
      miles: (r['miles'] as num).toDouble(),
      address: r['address'] as String?,
    );
  }

  Future<List<DemandCell>> cells(AppMode mode) async {
    final rows = await sb.rpc('demand_by_cell', params: {'p_mode': mode.id}) as List;
    return [
      for (final r in rows.cast<Map>())
        DemandCell(
          lat: (r['cell_lat'] as num).toDouble(),
          lng: (r['cell_lng'] as num).toDouble(),
          hunters: (r['hunters'] as num).toInt(),
          liveSales: (r['live_sales'] as num).toInt(),
          newest: r['newest'] == null ? null : DateTime.parse(r['newest'] as String).toLocal(),
        ),
    ];
  }
}
