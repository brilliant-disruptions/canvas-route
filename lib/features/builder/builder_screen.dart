import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/logic/geo.dart';
import '../../core/logic/polyline.dart';
import '../../core/logic/restock.dart';
import '../../core/logic/time_window_planner.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/directions.dart';
import '../../data/models/draft_stop.dart';
import '../../data/models/settings.dart';
import '../../modes/mode_pack.dart';
import '../../state/community_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../map/manual_stop_sheet.dart';

enum _Order { preserve, optimize }

/// Finalize draft stops into a named route. Time-window modes run the planner
/// pre-pass (spec §3.6) and flag late arrivals before Google Directions is asked.
class BuilderScreen extends ConsumerStatefulWidget {
  const BuilderScreen({super.key});
  @override
  ConsumerState<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends ConsumerState<BuilderScreen> {
  final _name = TextEditingController();
  _Order _order = _Order.preserve;
  DirectionsResult? _preview;
  List<PlannedArrival> _arrivals = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final map = ref.read(mapProvider);
    _name.text = map.editingRouteName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(modePackProvider).usesTimeWindows) _orderByWindows();
      _refreshPreview();
    });
  }

  String _autoName() => '${ref.read(modePackProvider).routeNamePrefix} · ${DateFormat.MMMd().format(DateTime.now())}';

  Future<Waypoint?> _origin() => ref.read(locationServiceProvider).current();

  Waypoint? _destination(Waypoint? origin) {
    final s = ref.read(settingsProvider).value;
    final p = ref.read(profileProvider).value;
    return switch (s?.routeEndPreference) {
      RouteEndPreference.office when p?.officeLat != null => Waypoint(p!.officeLat!, p.officeLng!),
      RouteEndPreference.custom when s?.customEndLat != null => Waypoint(s!.customEndLat!, s.customEndLng!),
      _ => origin,
    };
  }

  Future<Map<String, StoreWindow>> _restockWindows(List<DraftStop> drafts) async {
    final ids = drafts.map((d) => d.business.pinId).whereType<String>().toList();
    if (ids.isEmpty) return {};
    final summaries = await ref.read(storeSummariesProvider(ids.join(',')).future);
    final day = DateTime.now().hour >= 20 ? DateTime.now().add(const Duration(days: 1)) : DateTime.now();
    final out = <String, StoreWindow>{};
    for (final e in summaries.entries) {
      final w = windowOnDay(e.value.bestWindows, day);
      out[e.key] = StoreWindow(tier: e.value.tier, start: w?.start, end: w?.end, label: e.value.bestWindowLabel);
    }
    return out;
  }

  Future<void> _orderByWindows() async {
    final pack = ref.read(modePackProvider);
    final drafts = ref.read(mapProvider).draftStops;
    final windows = pack.optimizer == OptimizerKind.restockWindow ? await _restockWindows(drafts) : <String, StoreWindow>{};
    final planner = drafts.map((d) {
      final w = d.business.pinId == null ? null : windows[d.business.pinId];
      return PlannerStop(
        id: d.id,
        lat: d.business.lat,
        lng: d.business.lng,
        opensAt: d.business.opensAt,
        closesAt: d.business.closesAt,
        restockStart: w?.start,
        restockEnd: w?.end,
      );
    }).toList();
    final ordered = orderByWindows(planner, preferRestockStart: pack.optimizer == OptimizerKind.restockWindow);
    final byId = {for (final d in drafts) d.id: d};
    ref.read(mapProvider.notifier).setDrafts(ordered.map((p) => byId[p.id]!).toList());
    if (mounted) setState(() => _windows = windows);
  }

  Map<String, StoreWindow> _windows = {};

  Future<void> _refreshPreview() async {
    final drafts = ref.read(mapProvider).draftStops;
    if (drafts.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final origin = await _origin();
      final dest = _destination(origin);
      final wps = drafts.map((d) => Waypoint(d.business.lat, d.business.lng)).toList();
      if (wps.length == 1 && origin == null) {
        setState(() => _busy = false);
        return;
      }
      final result = await ref.read(directionsServiceProvider).route(
            wps,
            optimize: _order == _Order.optimize,
            origin: origin,
            destination: _order == _Order.optimize ? dest : null,
          );
      var ordered = drafts;
      if (_order == _Order.optimize && result.optimizedOrder != null) {
        final o = result.optimizedOrder!;
        ordered = origin != null ? o.map((i) => drafts[i]).toList() : [drafts.first, ...o.map((i) => drafts[i + 1]), drafts.last];
        ref.read(mapProvider.notifier).setDrafts(ordered);
      }
      // Leg list: with an origin there is one leg per stop; otherwise prepend 0.
      final legs = origin != null && result.legDurationSeconds.length >= ordered.length
          ? result.legDurationSeconds.sublist(0, ordered.length)
          : [0, ...result.legDurationSeconds.take(ordered.length - 1)];
      final planner = ordered.map((d) {
        final w = d.business.pinId == null ? null : _windows[d.business.pinId];
        return PlannerStop(id: d.id, lat: d.business.lat, lng: d.business.lng, opensAt: d.business.opensAt, closesAt: d.business.closesAt, restockStart: w?.start, restockEnd: w?.end);
      }).toList();
      final start = _plannedStart(ordered);
      setState(() {
        _preview = result;
        _arrivals = ref.read(modePackProvider).usesTimeWindows ? simulateArrivals(ordered: planner, legSeconds: legs, startAt: start) : const [];
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// Yard sales are planned for the sale day: leave 15 min before the earliest open.
  DateTime _plannedStart(List<DraftStop> drafts) {
    final opens = drafts.map((d) => d.business.opensAt).whereType<DateTime>().toList()..sort();
    final now = DateTime.now();
    if (opens.isNotEmpty && opens.first.isAfter(now)) return opens.first.subtract(const Duration(minutes: 15));
    return now;
  }

  Future<void> _save() async {
    final map = ref.read(mapProvider);
    if (map.draftStops.isEmpty) return;
    final name = _name.text.trim().isEmpty ? _autoName() : _name.text.trim();
    setState(() => _busy = true);
    try {
      final n = ref.read(routesProvider.notifier);
      final route = map.editingRouteId != null
          ? await n.replaceStops(map.editingRouteId!, name, map.draftStops, isOptimized: _order == _Order.optimize)
          : await n.save(name, map.draftStops, isOptimized: _order == _Order.optimize);
      ref.read(mapProvider.notifier).clearDrafts();
      if (!mounted) return;
      final start = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Saved "${route.name}"'),
          content: map.draftStops.length == 1 ? const Text('Routes work best with 2 or more stops.') : null,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back to routes')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start route')),
          ],
        ),
      );
      if (!mounted) return;
      if (start == true) {
        context.pushReplacement('/route/${route.id}');
      } else {
        context.go('/routes');
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final map = ref.watch(mapProvider);
    final drafts = map.draftStops;
    final polyline = _preview == null ? const <LatLng>[] : decodePolyline(_preview!.encodedPolyline).map((p) => LatLng(p.lat, p.lng)).toList();
    final flagById = {for (final a in _arrivals) a.stop.id: a};

    return Scaffold(
      appBar: AppBar(
        title: Text(map.editingRouteId != null ? 'Edit route' : 'Route builder'),
        actions: [
          if (pack.usesTimeWindows)
            TextButton.icon(onPressed: _busy ? null : () async {
              await _orderByWindows();
              await _refreshPreview();
            }, icon: const Icon(Icons.schedule), label: const Text('By window')),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: drafts.isEmpty
                ? const SizedBox()
                : GoogleMap(
                    initialCameraPosition: CameraPosition(target: LatLng(drafts.first.business.lat, drafts.first.business.lng), zoom: 11),
                    zoomGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    liteModeEnabled: true,
                    markers: {
                      for (var i = 0; i < drafts.length; i++)
                        Marker(markerId: MarkerId(drafts[i].id), position: LatLng(drafts[i].business.lat, drafts[i].business.lng), icon: BitmapDescriptor.defaultMarkerWithHue(270)),
                    },
                    polylines: polyline.isEmpty ? const {} : {Polyline(polylineId: const PolylineId('p'), points: polyline, color: c.primary, width: 4)},
                    onMapCreated: (ctl) {
                      if (drafts.length > 1) {
                        final lats = drafts.map((d) => d.business.lat);
                        final lngs = drafts.map((d) => d.business.lng);
                        ctl.moveCamera(CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                            southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
                            northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
                          ),
                          40,
                        ));
                      }
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s4, 0),
            child: Column(children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: 'Route name', hintText: _autoName()), textCapitalization: TextCapitalization.sentences),
              const SizedBox(height: Sp.s3),
              SegmentedButton<_Order>(
                segments: const [
                  ButtonSegment(value: _Order.preserve, label: Text('Preserve my order'), icon: Icon(Icons.format_list_numbered)),
                  ButtonSegment(value: _Order.optimize, label: Text('Shortest drive'), icon: Icon(Icons.bolt)),
                ],
                selected: {_order},
                onSelectionChanged: (s) {
                  setState(() => _order = s.first);
                  _refreshPreview();
                },
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(_error!, style: t.bodySmall?.copyWith(color: c.error))),
            ]),
          ),
          Expanded(
            child: drafts.isEmpty
                ? EmptyState(icon: Icons.add_location_alt_outlined, title: 'No ${pack.stopNoun}s in this route', action: OutlinedButton(onPressed: () => context.go('/map'), child: const Text('Add from the map')))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: Sp.s2),
                    itemCount: drafts.length,
                    onReorderItem: (o, n) {
                      ref.read(mapProvider.notifier).reorderDrafts(o, n);
                      setState(() => _order = _Order.preserve);
                      _refreshPreview();
                    },
                    itemBuilder: (_, i) {
                      final d = drafts[i];
                      final a = flagById[d.id];
                      final w = d.business.pinId == null ? null : _windows[d.business.pinId];
                      return _StopRow(
                        key: ValueKey(d.id),
                        index: i,
                        draft: d,
                        arrival: a,
                        window: w,
                        pack: pack,
                        onRemove: () {
                          ref.read(mapProvider.notifier).removeDraft(d.id);
                          _refreshPreview();
                        },
                        onEdit: () async {
                          final r = await showManualStopSheet(context, address: d.business.address, requiresWindow: pack.usesTimeWindows && pack.requiresTimeWindow, initialName: d.business.name, initialOpens: d.business.opensAt, initialCloses: d.business.closesAt);
                          if (r == null) return;
                          ref.read(mapProvider.notifier).updateDraft(d.id, (b) => b.copyWith(name: r.name, opensAt: r.opensAt, closesAt: r.closesAt));
                          _refreshPreview();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s4, Sp.s4),
          color: c.surfaceLow,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_preview == null ? (_busy ? 'Calculating…' : '—') : '${formatDuration(_preview!.totalDurationSeconds)} · ${formatDistance(_preview!.totalDistanceMeters.toDouble())}', style: t.headlineSmall),
                Text('${drafts.length} ${pack.stopNoun}${drafts.length == 1 ? '' : 's'}${_arrivals.any((a) => a.flag == ArrivalFlag.late) ? ' · ${_arrivals.where((a) => a.flag == ArrivalFlag.late).length} too late' : ''}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ]),
            ),
            SizedBox(width: 160, child: KnButton(label: 'Save route', lime: true, compact: true, loading: _busy, onPressed: drafts.isEmpty ? null : _save)),
          ]),
        ),
      ),
    );
  }
}

class StoreWindow {
  const StoreWindow({required this.tier, this.start, this.end, this.label});
  final RestockTier tier;
  final DateTime? start;
  final DateTime? end;
  final String? label;
}

class _StopRow extends StatelessWidget {
  const _StopRow({super.key, required this.index, required this.draft, required this.pack, this.arrival, this.window, required this.onRemove, required this.onEdit});
  final int index;
  final DraftStop draft;
  final ModePack pack;
  final PlannedArrival? arrival;
  final StoreWindow? window;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final b = draft.business;
    final windowText = b.opensAt != null
        ? '${DateFormat.E().format(b.opensAt!)} ${DateFormat.jm().format(b.opensAt!)}–${b.closesAt == null ? '' : DateFormat.jm().format(b.closesAt!)}'
        : window?.label;
    Widget? flag;
    if (arrival != null) {
      final (label, color) = switch (arrival!.flag) {
        ArrivalFlag.late => ('Arrive ${arrival!.minutesLate} min after close', c.error),
        ArrivalFlag.beforeOpen => ('Early · opens ${DateFormat.jm().format(arrival!.eta)}', c.warning),
        ArrivalFlag.ok => ('ETA ${DateFormat.jm().format(arrival!.eta)}', c.statusDone),
        ArrivalFlag.unknown => ('ETA ${DateFormat.jm().format(arrival!.eta)}', c.onSurfaceVariant),
      };
      flag = Text(label, style: t.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700));
    }
    return ListTile(
      leading: NumberDot(index + 1, color: arrival?.flag == ArrivalFlag.late ? c.error : null),
      title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.address, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (windowText != null) Text(windowText, style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
        ?flag,
      ]),
      onTap: onEdit,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Remove stop', icon: const Icon(Icons.close), onPressed: onRemove, visualDensity: VisualDensity.compact),
        ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
      ]),
    );
  }
}
