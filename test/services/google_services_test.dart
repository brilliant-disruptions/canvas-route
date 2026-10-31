import 'dart:convert';

import 'package:canvas_route/data/models/directions.dart';
import 'package:canvas_route/data/services/directions_service.dart';
import 'package:canvas_route/data/services/places_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Routes API', () {
    late http.Request sent;
    DirectionsService svc(Map<String, dynamic> reply, {int status = 200}) => DirectionsService(
          apiKey: 'k',
          client: MockClient((req) async {
            sent = req;
            return http.Response.bytes(utf8.encode(jsonEncode(reply)), status);
          }),
        );
    const a = Waypoint(32.8, -96.8), b = Waypoint(32.81, -96.79), c = Waypoint(32.82, -96.78);

    test('sends a key, a field mask and pinned ends without asking Google to optimize', () async {
      await svc({
        'routes': [
          {'polyline': {'encodedPolyline': 'abc'}, 'legs': []},
        ],
      }).route([a, b, c]);
      expect(sent.url.host, 'routes.googleapis.com');
      expect(sent.headers['X-Goog-Api-Key'], 'k');
      expect(sent.headers['X-Goog-FieldMask'], contains('routes.legs.duration'));
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['origin']['location']['latLng'], {'latitude': 32.8, 'longitude': -96.8});
      expect(body['destination']['location']['latLng']['latitude'], 32.82);
      expect((body['intermediates'] as List).length, 1);
      expect(body.containsKey('optimizeWaypointOrder'), isFalse);
    });

    test('parses legs, tolerating zero-length legs with no distance', () async {
      final r = await svc({
        'routes': [
          {
            'polyline': {'encodedPolyline': 'xyz'},
            'distanceMeters': 1500,
            'duration': '300s',
            'legs': [
              {'distanceMeters': 1500, 'duration': '240s'},
              {'duration': '60s'},
            ],
          },
        ],
      }).route([a, b, c]);
      expect(r.encodedPolyline, 'xyz');
      expect(r.totalDistanceMeters, 1500);
      expect(r.totalDurationSeconds, 300);
      expect(r.legDurationSeconds, [240, 60]);
      expect(r.optimizedOrder, isNull);
    });

    test('optimizes intermediates between an origin and destination', () async {
      final r = await svc({
        'routes': [
          {
            'legs': [],
            'optimizedIntermediateWaypointIndex': [1, 0],
          },
        ],
      }).route([b, c], origin: a, destination: a, optimize: true);
      expect(jsonDecode(sent.body)['optimizeWaypointOrder'], isTrue);
      expect(r.optimizedOrder, [1, 0]);
    });

    test('nothing to reorder reads as the given order', () async {
      final r = await svc({
        'routes': [
          {
            'legs': [],
            'optimizedIntermediateWaypointIndex': [-1],
          },
        ],
      }).route([b], origin: a, destination: a, optimize: true);
      expect(jsonDecode(sent.body).containsKey('optimizeWaypointOrder'), isFalse);
      expect(r.optimizedOrder, [0]);
    });

    test('no route and HTTP errors throw', () async {
      expect(() => svc({}).route([a, b]), throwsA(isA<DirectionsException>()));
      expect(() => svc({}, status: 403).route([a, b]), throwsA(isA<DirectionsException>()));
      expect(() => DirectionsService(apiKey: '').route([a, b]), throwsA(isA<DirectionsException>()));
    });
  });

  group('Places API (New)', () {
    late http.Request sent;
    PlacesService svc(Map<String, dynamic> reply) => PlacesService(
          apiKey: 'k',
          client: MockClient((req) async {
            sent = req;
            return http.Response.bytes(utf8.encode(jsonEncode(reply)), 200);
          }),
        );

    test('text search asks for Pro fields only and drops closed places', () async {
      final list = await svc({
        'places': [
          {
            'id': 'p1',
            'displayName': {'text': 'Acme'},
            'formattedAddress': '1 Main St',
            'location': {'latitude': 32.8, 'longitude': -96.8},
            'types': ['store'],
            'businessStatus': 'OPERATIONAL',
          },
          {
            'id': 'p2',
            'displayName': {'text': 'Gone'},
            'location': {'latitude': 32.8, 'longitude': -96.8},
            'businessStatus': 'CLOSED_PERMANENTLY',
          },
        ],
      }).textSearch('coffee', 32.8, -96.8, radiusMeters: 80000);
      final mask = sent.headers['X-Goog-FieldMask']!;
      expect(mask, isNot(contains('rating')));
      expect(mask, isNot(contains('Hours')));
      expect(jsonDecode(sent.body)['locationBias']['circle']['radius'], 50000);
      expect(list.map((b) => b.placeId), ['p1']);
      expect(list.single.name, 'Acme');
      expect(list.single.lat, 32.8);
    });

    test('no results is an empty list', () async {
      expect(await svc({}).textSearch('zzz', 0, 0), isEmpty);
    });

    test('details reads phone, site and weekday hours', () async {
      final d = await svc({
        'nationalPhoneNumber': '(214) 555-0100',
        'websiteUri': 'https://acme.test',
        'regularOpeningHours': {
          'weekdayDescriptions': ['Monday: 9 AM – 5 PM'],
        },
      }).details('p1');
      expect(sent.url.path, '/v1/places/p1');
      expect(d.phone, '(214) 555-0100');
      expect(d.website, 'https://acme.test');
      expect(d.hours, ['Monday: 9 AM – 5 PM']);
    });
  });
}
