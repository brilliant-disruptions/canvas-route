import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/logic/freshness.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/theme/kn_colors.dart';
import '../../data/models/business.dart';
import '../../data/models/pin.dart';
import '../../data/models/report.dart';
import '../../modes/mode_pack.dart';
import '../../state/map_state.dart';
import '../../ui/map/pin_icons.dart';
import '../community/pin_sheet.dart';

/// Every marker on the map: search results, picked stops that aren't otherwise
/// shown, and community listings styled by their live status. Picked stops
/// become numbered dots, so route order reads at a glance.
Set<Marker> buildMapMarkers({
  required KnColors c,
  required ModePack pack,
  required MapState map,
  required List<Pin> pins,
  required Map<String, Report> latest,
  required Set<String> visited,
  required BitmapDescriptor? Function(PinSpec) iconFor,
  required void Function(Business) onBusiness,
  required void Function(Pin) onPin,
  required DateTime now,
}) {
  final markers = <Marker>{};
  void add(String id, Business b, PinSpec spec, VoidCallback onTap, {int z = 0, double alpha = 1}) {
    final i = map.draftIndex(b);
    final s = i < 0 ? spec : PinSpec.number(i + 1, fill: c.primary, ink: c.onPrimary);
    final icon = iconFor(s);
    markers.add(
      Marker(
        markerId: MarkerId(id),
        position: LatLng(b.lat, b.lng),
        icon: icon ?? BitmapDescriptor.defaultMarker,
        visible: icon != null,
        anchor: s.anchor,
        alpha: alpha,
        zIndexInt: i < 0 ? z : 10,
        infoWindow: InfoWindow(title: b.name),
        onTap: onTap,
      ),
    );
  }

  for (final b in map.results) {
    add(
      'r:${b.identity}',
      b,
      // A leading dot marks places you've already been.
      PinSpec.pill(
        shortPlaceName(b.name),
        fill: c.surfaceHighest,
        ink: c.onSurface,
        border: c.primary,
        dot: visited.contains(b.identity) ? c.tertiary : null,
      ),
      () => onBusiness(b),
    );
  }
  for (final d in map.draftStops) {
    if (map.results.any((r) => r.identity == d.business.identity)) continue;
    if (pins.any((p) => p.id == d.business.pinId)) continue;
    add(
      'd:${d.id}',
      d.business,
      PinSpec.pill(shortPlaceName(d.business.name), fill: c.surfaceHighest, ink: c.onSurface),
      () => onBusiness(d.business),
    );
  }
  for (final p in pins) {
    final (spec, z, alpha) = _pinStyle(c, pack, p, latest[p.id], now);
    add('p:${p.id}', businessFromPin(p), spec, () => onPin(p), z: z, alpha: alpha);
  }
  return markers;
}

/// Saturday-morning truth beats posted hours: a recent report decides the look.
(PinSpec, int, double) _pinStyle(KnColors c, ModePack pack, Pin p, Report? rep, DateTime now) {
  final st = rep == null ? null : pack.reportStatuses.where((s) => s.value == rep.status).firstOrNull;
  final age = rep == null ? null : now.difference(rep.createdAt);
  if (p.opensAt == null) {
    final live = st != null && st.positive && isFresh(rep!.createdAt, now: now);
    return live
        ? (PinSpec.pill('${shortPlaceName(p.name, max: 12)} · ${st.label}', fill: c.tertiary, ink: c.onTertiary, halo: true), 5, 1)
        : (PinSpec.pill(shortPlaceName(p.name), fill: c.surfaceHighest, ink: c.onSurface), 0, 1);
  }
  final ended = p.closesAt != null && !p.closesAt!.isAfter(now);
  final open = !now.isBefore(p.opensAt!) && !ended;
  if (st != null && st.ends && age! <= const Duration(hours: 6)) {
    return (PinSpec.pill(st.label, fill: c.surfaceHighest, ink: c.onSurfaceVariant, border: c.outline), 0, 0.45);
  }
  if (st != null && st.positive && open && age! <= const Duration(hours: 1)) {
    return (PinSpec.pill('${st.label} · ${compactTime(rep!.createdAt)}', fill: c.tertiary, ink: c.onTertiary, halo: true), 5, 1);
  }
  if (st != null && st.caution && !ended && age! <= const Duration(hours: 1)) {
    return (PinSpec.pill(st.label, fill: c.warning, ink: Colors.black, border: c.warning), 4, 1);
  }
  return (
    PinSpec.pill(
      compactWindow(p.opensAt!, p.closesAt),
      fill: c.surfaceHighest,
      ink: c.onSurface,
      border: open ? c.tertiary : c.outline,
      dot: open ? c.tertiary : null,
    ),
    0,
    ended ? 0.45 : 1,
  );
}
