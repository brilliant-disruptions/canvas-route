import 'app_mode.dart';
import 'json_utils.dart';

enum PinKind { yardSale, store }

/// Where a pin came from. `permit` is imported nightly from a city's public
/// garage-sale permits (migration 012).
enum PinOrigin { host, spotted, places, permit }

enum PinStatus { draft, pending, live, ended, removed }

class Pin {
  const Pin({
    required this.id,
    required this.mode,
    required this.kind,
    required this.origin,
    required this.name,
    required this.lat,
    required this.lng,
    required this.categories,
    required this.status,
    required this.confirmations,
    required this.createdAt,
    this.ownerId,
    this.placeId,
    this.address,
    this.opensAt,
    this.closesAt,
    this.notes,
    this.listingUrl,
    this.earlyBirds,
    this.shareToken,
    this.photoPaths = const [],
  });

  final String id;
  final AppMode mode;
  final PinKind kind;
  final PinOrigin origin;
  final String? ownerId;
  final String? placeId;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final List<String> categories;
  final String? notes;
  final String? listingUrl;
  final String? earlyBirds;
  final PinStatus status;
  final int confirmations;
  final String? shareToken;
  final DateTime createdAt;
  final List<String> photoPaths;

  bool get isLive => status == PinStatus.live;

  factory Pin.fromRow(Map<String, dynamic> r, {List<String> photos = const []}) => Pin(
        id: r['id'] as String,
        mode: AppMode.fromId(r['mode'] as String?),
        kind: r['kind'] == 'store' ? PinKind.store : PinKind.yardSale,
        origin: PinOrigin.values.firstWhere((o) => o.name == r['origin'], orElse: () => PinOrigin.spotted),
        ownerId: r['owner_id'] as String?,
        placeId: r['place_id'] as String?,
        name: r['name'] as String,
        address: r['address'] as String?,
        lat: dbl(r['lat']),
        lng: dbl(r['lng']),
        opensAt: dtOrNull(r['opens_at']),
        closesAt: dtOrNull(r['closes_at']),
        categories: strList(r['categories']),
        notes: r['notes'] as String?,
        listingUrl: r['listing_url'] as String?,
        earlyBirds: r['early_birds'] as String?,
        status: PinStatus.values.firstWhere((s) => s.name == r['status'], orElse: () => PinStatus.live),
        confirmations: intOr(r['confirmations'], 0),
        shareToken: r['share_token'] as String?,
        createdAt: dt(r['created_at']),
        photoPaths: photos,
      );
}
