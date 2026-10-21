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

/// Google Places Text Search + Details, and Geocoding. Pure async I/O.
class PlacesService {
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://maps.googleapis.com/maps/api';
  static const _closed = {'CLOSED_TEMPORARILY', 'CLOSED_PERMANENTLY'};

  String _key() {
    if (!Env.hasGoogleKey) throw PlacesException('GOOGLE_MAPS_API_KEY is not set');
    return Env.googleMapsApiKey;
  }

  Future<List<Business>> textSearch(String query, double lat, double lng, {int radiusMeters = 5000}) async {
    final uri = Uri.parse('$_base/place/textsearch/json').replace(queryParameters: {
      'query': query,
      'location': '$lat,$lng',
      'radius': '$radiusMeters',
      'key': _key(),
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw PlacesException('Places API error ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final status = data['status'] as String;
    if (status != 'OK' && status != 'ZERO_RESULTS') throw PlacesException('Places API: $status');
    final results = (data['results'] as List? ?? const []).cast<Map<String, dynamic>>();
    return results
        .where((r) => !_closed.contains(r['business_status']))
        .map((r) => Business(
              placeId: r['place_id'] as String,
              name: r['name'] as String,
              address: r['formatted_address'] as String? ?? '',
              lat: (r['geometry']['location']['lat'] as num).toDouble(),
              lng: (r['geometry']['location']['lng'] as num).toDouble(),
              rating: (r['rating'] as num?)?.toDouble(),
              types: (r['types'] as List? ?? const []).map((e) => e.toString()).toList(),
              source: StopSource.places,
            ))
        .toList();
  }

  Future<({String? phone, String? website, List<String> hours})> details(String placeId) async {
    final uri = Uri.parse('$_base/place/details/json').replace(queryParameters: {
      'place_id': placeId,
      'fields': 'formatted_phone_number,website,opening_hours',
      'key': _key(),
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw PlacesException('Place Details error ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') throw PlacesException('Place Details: ${data['status']}');
    final r = data['result'] as Map<String, dynamic>;
    return (
      phone: r['formatted_phone_number'] as String?,
      website: r['website'] as String?,
      hours: ((r['opening_hours'] as Map?)?['weekday_text'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_base/geocode/json').replace(queryParameters: {'latlng': '$lat,$lng', 'key': _key()});
    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? const [];
    if (results.isEmpty) return null;
    return results.first['formatted_address'] as String?;
  }

  Future<({double lat, double lng, String formatted})?> geocode(String address) async {
    final uri = Uri.parse('$_base/geocode/json').replace(queryParameters: {'address': address, 'key': _key()});
    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
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
