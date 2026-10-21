import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/directions.dart';
import 'profile_state.dart';
import 'providers.dart';

/// Current GPS, falling back to the profile's home/office point, then a US centroid.
final currentLocationProvider = FutureProvider<Waypoint?>((ref) async {
  return ref.read(locationServiceProvider).current();
});

final mapCenterProvider = Provider<Waypoint>((ref) {
  final gps = ref.watch(currentLocationProvider).value;
  if (gps != null) return gps;
  final p = ref.watch(profileProvider).value;
  if (p?.homeLat != null && p?.homeLng != null) return Waypoint(p!.homeLat!, p.homeLng!);
  if (p?.officeLat != null && p?.officeLng != null) return Waypoint(p!.officeLat!, p.officeLng!);
  return const Waypoint(39.8283, -98.5795);
});
