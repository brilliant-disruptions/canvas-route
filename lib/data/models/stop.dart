import 'business.dart';
import 'json_utils.dart';

enum StopSource {
  places('places'),
  manual('manual'),
  community('community'),
  listingLink('listing_link');

  const StopSource(this.id);
  final String id;
  static StopSource fromId(String? id) =>
      StopSource.values.firstWhere((s) => s.id == id, orElse: () => StopSource.places);
}

class Stop {
  const Stop({
    required this.id,
    required this.routeId,
    required this.source,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.stopOrder,
    required this.visited,
    this.placeId,
    this.pinId,
    this.opensAt,
    this.closesAt,
    this.listingUrl,
  });

  final String id;
  final String routeId;
  final String? placeId;
  final String? pinId;
  final StopSource source;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int stopOrder;
  final bool visited;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final String? listingUrl;

  Stop copyWith({bool? visited, int? stopOrder, String? name}) => Stop(
        id: id,
        routeId: routeId,
        placeId: placeId,
        pinId: pinId,
        source: source,
        name: name ?? this.name,
        address: address,
        lat: lat,
        lng: lng,
        stopOrder: stopOrder ?? this.stopOrder,
        visited: visited ?? this.visited,
        opensAt: opensAt,
        closesAt: closesAt,
        listingUrl: listingUrl,
      );

  factory Stop.fromRow(Map<String, dynamic> r) => Stop(
        id: r['id'] as String,
        routeId: r['route_id'] as String,
        placeId: r['place_id'] as String?,
        pinId: r['pin_id'] as String?,
        source: StopSource.fromId(r['source'] as String?),
        name: r['name'] as String,
        address: r['address'] as String? ?? '',
        lat: dbl(r['lat']),
        lng: dbl(r['lng']),
        stopOrder: intOr(r['stop_order'], 0),
        visited: r['visited'] as bool? ?? false,
        opensAt: dtOrNull(r['opens_at']),
        closesAt: dtOrNull(r['closes_at']),
        listingUrl: r['listing_url'] as String?,
      );
}

extension StopToBusiness on Stop {
  Business toBusiness() => Business(
        placeId: placeId,
        pinId: pinId,
        name: name,
        address: address,
        lat: lat,
        lng: lng,
        source: source,
        opensAt: opensAt,
        closesAt: closesAt,
        listingUrl: listingUrl,
      );
}
