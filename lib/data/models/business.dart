import 'stop.dart';

/// A place found on the map that can become a stop. Source tells the UI how
/// to render the pin and whether a `place_id` exists.
class Business {
  const Business({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.source,
    this.placeId,
    this.pinId,
    this.phone,
    this.website,
    this.rating,
    this.openingHours = const [],
    this.types = const [],
    this.opensAt,
    this.closesAt,
    this.listingUrl,
  });

  final String? placeId;
  final String? pinId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final StopSource source;
  final String? phone;
  final String? website;
  final double? rating;
  final List<String> openingHours;
  final List<String> types;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final String? listingUrl;

  /// Stable identity for de-duplication across sources.
  String get identity => placeId ?? pinId ?? '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  Business copyWith({
    String? phone,
    String? website,
    List<String>? openingHours,
    String? name,
    DateTime? opensAt,
    DateTime? closesAt,
    String? listingUrl,
  }) =>
      Business(
        placeId: placeId,
        pinId: pinId,
        name: name ?? this.name,
        address: address,
        lat: lat,
        lng: lng,
        source: source,
        phone: phone ?? this.phone,
        website: website ?? this.website,
        rating: rating,
        openingHours: openingHours ?? this.openingHours,
        types: types,
        opensAt: opensAt ?? this.opensAt,
        closesAt: closesAt ?? this.closesAt,
        listingUrl: listingUrl ?? this.listingUrl,
      );

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'pinId': pinId,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'source': source.id,
        'phone': phone,
        'website': website,
        'rating': rating,
        'openingHours': openingHours,
        'types': types,
        'opensAt': opensAt?.toIso8601String(),
        'closesAt': closesAt?.toIso8601String(),
        'listingUrl': listingUrl,
      };

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        placeId: j['placeId'] as String?,
        pinId: j['pinId'] as String?,
        name: j['name'] as String,
        address: j['address'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        source: StopSource.fromId(j['source'] as String?),
        phone: j['phone'] as String?,
        website: j['website'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        openingHours: (j['openingHours'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        types: (j['types'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        opensAt: j['opensAt'] == null ? null : DateTime.parse(j['opensAt'] as String),
        closesAt: j['closesAt'] == null ? null : DateTime.parse(j['closesAt'] as String),
        listingUrl: j['listingUrl'] as String?,
      );
}
