import 'package:cross_file/cross_file.dart';

import '../models/app_mode.dart';
import '../models/business.dart';
import '../models/pin.dart';
import '../services/storage_service.dart';
import '../supabase_client.dart';

class PinRepository {
  PinRepository(this._storage);
  final StorageService _storage;

  Future<List<Pin>> nearby(AppMode mode, double lat, double lng, {double radiusMi = 15}) async {
    final rows = (await sb.rpc('nearby_pins', params: {
      'p_mode': mode.id,
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_mi': radiusMi,
    }) as List)
        .cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final photos = await sb.from('pin_photos').select('pin_id, storage_path').inFilter('pin_id', ids);
    final byPin = <String, List<String>>{};
    for (final p in photos) {
      byPin
          .putIfAbsent(p['pin_id'] as String, () => [])
          .add(_storage.publicUrl(StorageService.pinPhotos, p['storage_path'] as String));
    }
    return rows.map((r) => Pin.fromRow(r, photos: byPin[r['id']] ?? const [])).toList();
  }

  Future<Pin?> byId(String id) async {
    final row = await sb.from('pins').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Pin.fromRow(row, photos: await _photoUrls(id));
  }

  Future<Pin?> byShareToken(String token) async {
    final row = await sb.from('pins').select().eq('share_token', token).maybeSingle();
    if (row == null) return null;
    return Pin.fromRow(row, photos: await _photoUrls(row['id'] as String));
  }

  Future<List<Pin>> mine(String userId) async {
    final rows = await sb.from('pins').select().eq('owner_id', userId).order('created_at', ascending: false);
    return rows.map(Pin.fromRow).toList();
  }

  Future<List<String>> _photoUrls(String pinId) async {
    final photos = await sb.from('pin_photos').select('storage_path').eq('pin_id', pinId);
    return photos.map((p) => _storage.publicUrl(StorageService.pinPhotos, p['storage_path'] as String)).toList();
  }

  /// Host-posted yard sale: live immediately (consent by definition).
  Future<Pin> createHosted({
    required String ownerId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required DateTime opensAt,
    required DateTime closesAt,
    required List<String> categories,
    String? notes,
    String? earlyBirds,
    List<XFile> photos = const [],
  }) async {
    final row = await sb
        .from('pins')
        .insert({
          'mode': AppMode.yardSales.id,
          'kind': 'yard_sale',
          'origin': 'host',
          'owner_id': ownerId,
          'name': name,
          'address': address,
          'lat': lat,
          'lng': lng,
          'opens_at': opensAt.toUtc().toIso8601String(),
          'closes_at': closesAt.toUtc().toIso8601String(),
          'categories': categories,
          'notes': notes,
          'early_birds': earlyBirds,
          'status': 'live',
        })
        .select()
        .single();
    final id = row['id'] as String;
    for (final f in photos) {
      await addPhoto(id, ownerId, f);
    }
    return Pin.fromRow(row, photos: await _photoUrls(id));
  }

  /// User-spotted sale: pending until a second report or admin approval (§7).
  Future<Pin> createSpotted({
    required String userId,
    required AppMode mode,
    required String name,
    required String? address,
    required double lat,
    required double lng,
    DateTime? opensAt,
    DateTime? closesAt,
    String? listingUrl,
    List<String> categories = const [],
    required XFile signPhoto,
  }) async {
    final row = await sb
        .from('pins')
        .insert({
          'mode': mode.id,
          'kind': mode == AppMode.cardDrops ? 'store' : 'yard_sale',
          'origin': 'spotted',
          'owner_id': userId,
          'name': name,
          'address': address,
          'lat': lat,
          'lng': lng,
          'opens_at': opensAt?.toUtc().toIso8601String(),
          'closes_at': closesAt?.toUtc().toIso8601String(),
          'listing_url': listingUrl,
          'categories': categories,
          'status': 'pending',
        })
        .select()
        .single();
    final id = row['id'] as String;
    await addPhoto(id, userId, signPhoto);
    return Pin.fromRow(row, photos: await _photoUrls(id));
  }

  /// Promote a Places result to a persistent store pin so intel can attach to it.
  Future<Pin> ensureStorePin(Business b) async {
    final existing = b.placeId == null
        ? null
        : await sb.from('pins').select().eq('mode', AppMode.cardDrops.id).eq('place_id', b.placeId!).maybeSingle();
    if (existing != null) return Pin.fromRow(existing);
    final row = await sb
        .from('pins')
        .insert({
          'mode': AppMode.cardDrops.id,
          'kind': 'store',
          'origin': 'places',
          'place_id': b.placeId,
          'name': b.name,
          'address': b.address,
          'lat': b.lat,
          'lng': b.lng,
          'status': 'live',
        })
        .select()
        .single();
    return Pin.fromRow(row);
  }

  Future<void> addPhoto(String pinId, String userId, XFile file) async {
    final path = await _storage.upload(StorageService.pinPhotos, file);
    await sb.from('pin_photos').insert({'pin_id': pinId, 'user_id': userId, 'storage_path': path});
  }

  Future<void> setStatus(String pinId, PinStatus status) =>
      sb.from('pins').update({'status': status.name}).eq('id', pinId);

  Future<void> update(String pinId, Map<String, dynamic> patch) => sb.from('pins').update(patch).eq('id', pinId);

  Future<List<Pin>> pendingForAdmin() async {
    final rows = await sb.from('pins').select().inFilter('status', ['pending', 'removed']).order('created_at');
    // Reviewers need the sign photo: it's the evidence for a spotted sale.
    return [for (final r in rows) Pin.fromRow(r, photos: await _photoUrls(r['id'] as String))];
  }
}
