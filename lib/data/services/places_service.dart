import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/env.dart';
import '../models/business.dart';
import '../models/stop.dart';

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google Places API (New) Text Search + Details, and Geocoding. Pure async I/O.
///
/// Field masks set the bill: search asks only for Pro fields (no rating or hours),
/// and the Enterprise hours field is fetched once, when a business sheet opens.
class PlacesService {
  PlacesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? Env.googleMapsApiKey;

  final http.Client _client;
  final String _apiKey;
  static const _base = 'https://maps.googleapis.com/maps/api';
  static const _places = 'https://places.googleapis.com/v1';
  static const _closed = {'CLOSED_TEMPORARILY', 'CLOSED_PERMANENTLY'};
  static const _searchFields = 'places.id,places.displayName,places.formattedAddress,places.location,'
      'places.types,places.businessStatus';

  String _key() {
    if (_apiKey.isEmpty) throw PlacesException('GOOGLE_MAPS_API_KEY is not set');
    return _apiKey;
  }

  Map<String, String> _headers(String fields) =>
      {'Content-Type': 'application/json', 'X-Goog-Api-Key': _key(), 'X-Goog-FieldMask': fields};

  Future<List<Business>> textSearch(String query, double lat, double lng, {int radiusMeters = 5000}) async {
    final res = await _client.post(
      Uri.parse('$_places/places:searchText'),
      headers: _headers(_searchFields),
      body: jsonEncode({
        'textQuery': query,
        'locationBias': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': radiusMeters.clamp(1, 50000).toDouble(),
          },
        },
      }),
    );
    if (res.statusCode != 200) throw PlacesException('Places API error ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = (data['places'] as List? ?? const []).cast<Map<String, dynamic>>();
    return results
        .where((r) => !_closed.contains(r['businessStatus']) && r['location'] != null)
        .map((r) => Business(
              placeId: r['id'] as String,
              name: (r['displayName'] as Map?)?['text'] as String? ?? '',
              address: r['formattedAddress'] as String? ?? '',
              lat: (r['location']['latitude'] as num).toDouble(),
              lng: (r['location']['longitude'] as num).toDouble(),
              types: (r['types'] as List? ?? const []).map((e) => e.toString()).toList(),
              source: StopSource.places,
            ))
        .toList();
  }

  Future<({String? phone, String? website, List<String> hours})> details(String placeId) async {
    final res = await _client.get(
      Uri.parse('$_places/places/${Uri.encodeComponent(placeId)}'),
      headers: _headers('nationalPhoneNumber,websiteUri,regularOpeningHours.weekdayDescriptions'),
    );
    if (res.statusCode != 200) throw PlacesException('Place Details error ${res.statusCode}');
    final r = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (
      phone: r['nationalPhoneNumber'] as String?,
      website: r['websiteUri'] as String?,
      hours: ((r['regularOpeningHours'] as Map?)?['weekdayDescriptions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_base/geocode/json').replace(queryParameters: {'latlng': '$lat,$lng', 'key': _key()});
    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = data['results'] as List? ?? const [];
    if (results.isEmpty) return null;
    return results.first['formatted_address'] as String?;
  }

  Future<({double lat, double lng, String formatted})?> geocode(String address) async {
    final uri = Uri.parse('$_base/geocode/json').replace(queryParameters: {'address': address, 'key': _key()});
    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = data['results'] as List? ?? const [];
    if (results.isEmpty) return null;
    final r = results.first as Map<String, dynamic>;
    final loc = r['geometry']['location'] as Map<String, dynamic>;
    return (
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
      formatted: r['formatted_address'] as String,
    );
  }
}
