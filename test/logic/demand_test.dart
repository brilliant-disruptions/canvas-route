import 'package:canvas_route/data/models/app_mode.dart';
import 'package:canvas_route/data/repositories/demand_repository.dart';
import 'package:canvas_route/state/demand_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nearest live area names its city', () {
    expect(const NearestLive(lat: 0, lng: 0, miles: 240, address: '6120 Velasco Ave, Dallas, TX').city, 'Dallas');
    expect(const NearestLive(lat: 0, lng: 0, miles: 240, address: 'Lakewood Heights').city, isNull);
    expect(const NearestLive(lat: 0, lng: 0, miles: 240).city, isNull);
  });

  test('demand keys round to the server\'s ~7-mile cells', () {
    final a = demandKey(AppMode.yardSales, 36.1539, -95.9928);
    final b = demandKey(AppMode.yardSales, 36.1611, -95.9611);
    expect(a, b, reason: 'panning within a cell must not refetch');
    expect(a.lat, 36.2);
    expect(a.lng, -96.0);
  });
}
