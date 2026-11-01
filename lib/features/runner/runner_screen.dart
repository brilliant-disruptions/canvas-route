import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/logic/errors.dart';
import '../../core/logic/polyline.dart';
import '../../core/logic/freshness.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/directions.dart';
import '../../data/models/route_model.dart';
import '../../data/models/stop.dart';
import '../../data/models/visit.dart';
import '../../modes/mode_pack.dart';
import '../../state/community_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../state/visits_state.dart';
import '../../ui/map/pin_icons.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Run a saved route stop-by-stop. Non-linear: tap any stop to jump.
class RunnerScreen extends ConsumerStatefulWidget {
  const RunnerScreen({super.key, required this.routeId});
  final String routeId;
  @override
  ConsumerState<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends ConsumerState<RunnerScreen> with PinIconsMixin {
  GoogleMapController? _map;
  String? _currentStopId;
  List<LatLng> _polyline = const [];
  String? _logging;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final route = ref.read(routeByIdProvider(widget.routeId));
    if (route == null) return;
    // Resuming is the default; starting over lives in the top bar menu.
    if (route.status == RouteStatus.inProgress && route.visitedCount > 0 && !route.allVisited) {
      toast(context, 'Picking up at stop ${route.visitedCount + 1}', icon: Icons.play_arrow_rounded);
    }
    if (route.status != RouteStatus.inProgress) {
      await ref.read(routesProvider.notifier).setStatus(route.id, RouteStatus.inProgress);
    }
    _loadPolyline(route);
  }

  Future<void> _loadPolyline(RouteModel route) async {
    if (route.stops.length < 2) return;
    try {
      final origin = await ref.read(locationServiceProvider).current();
      final r = await ref.read(directionsServiceProvider).route(route.stops.map((s) => Waypoint(s.lat, s.lng)).toList(), origin: origin);
      if (mounted) setState(() => _polyline = decodePolyline(r.encodedPolyline).map((p) => LatLng(p.lat, p.lng)).toList());
    } catch (_) {
      // Map still works without the overview polyline.
    }
  }

  /// One tap from the runner: log the outcome, share it, move to the next stop.
  Future<void> _quickLog(ModePack pack, RouteModel route, Stop stop, String outcome) async {
    HapticFeedback.mediumImpact();
    setState(() => _logging = outcome);
    try {
      final r = await ref.read(visitLoggerProvider).log(route: route, stop: stop, draft: VisitDraft(values: {'outcome': outcome}));
      if (!mounted) return;
      setState(() {
        _logging = null;
        _currentStopId = null;
      });
      final next = ref.read(routeByIdProvider(route.id))?.stops.where((s) => !s.visited).firstOrNull;
      if (next != null) _map?.animateCamera(CameraUpdate.newLatLng(LatLng(next.lat, next.lng)));
      final c = context.kn;
      final router = GoRouter.of(context); // the snackbar can outlive this screen
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(children: [
            Icon(pack.outcomeIcon(outcome), size: 18, color: c.tertiary),
            const SizedBox(width: Sp.s2),
            Expanded(child: Text('$outcome · ${stop.name}${r.shared ? '\nShared with nearby ${pack.community.noun}' : ''}')),
          ]),
          action: SnackBarAction(
            label: 'Add details',
            textColor: c.tertiary,
            onPressed: () => router.push('/visit/${route.id}/${stop.id}'),
          ),
        ));
    } catch (e) {
      if (mounted) {
        setState(() => _logging = null);
        toast(context, 'Couldn\'t save. ${friendlyError(e)}');
      }
    }
  }

  Stop? _current(RouteModel route) {
    final byId = route.stops.where((s) => s.id == _currentStopId).firstOrNull;
    return byId ?? route.stops.where((s) => !s.visited).firstOrNull ?? route.stops.lastOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final route = ref.watch(routeByIdProvider(widget.routeId));
    if (route == null) return const Scaffold(body: LoadingView());

    ref.listen(routeByIdProvider(widget.routeId), (prev, next) {
      if (next != null && next.allVisited && !(prev?.allVisited ?? false)) {
        context.pushReplacement('/route/${next.id}/summary');
      }
    });

    final current = _current(route);
    PinSpec spec(int i, Stop s) => s.id == current?.id
        ? PinSpec.number(i + 1, fill: c.tertiary, ink: c.onTertiary, done: s.visited)
        : s.visited
            ? PinSpec.number(i + 1, fill: c.pinVisited, ink: c.surface, done: true)
            : PinSpec.number(i + 1, fill: c.primary, ink: c.onPrimary);
    final markers = {
      for (var i = 0; i < route.stops.length; i++)
        if (pinIcon(spec(i, route.stops[i])) case final icon?)
          Marker(
            markerId: MarkerId(route.stops[i].id),
            position: LatLng(route.stops[i].lat, route.stops[i].lng),
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: route.stops[i].id == current?.id ? 2 : (route.stops[i].visited ? 0 : 1),
            alpha: route.stops[i].visited && route.stops[i].id != current?.id ? 0.7 : 1,
            infoWindow: InfoWindow(title: '${i + 1}. ${route.stops[i].name}'),
            onTap: () => setState(() => _currentStopId = route.stops[i].id),
          ),
    };

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(current?.lat ?? route.stops.first.lat, current?.lng ?? route.stops.first.lng), zoom: 12),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: markers,
            polylines: _polyline.isEmpty ? const {} : {Polyline(polylineId: const PolylineId('route'), points: _polyline, color: c.primary, width: 4)},
            onMapCreated: (ctl) => _map = ctl,
            padding: const EdgeInsets.only(bottom: 260, top: 80),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Sp.s4),
              child: Row(children: [
                _Glass(child: IconButton(tooltip: 'Exit route', icon: const Icon(Icons.close), onPressed: () => context.pop())),
                const Spacer(),
                ProgressPill('${route.visitedCount} of ${route.stopCount} visited', icon: Icons.flag_outlined),
                const SizedBox(width: Sp.s2),
                _Glass(
                  child: PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) async {
                      if (v != 'restart') return;
                      if (await confirm(context, title: 'Start over?', body: 'Every stop is marked unvisited and the visits logged on this ${pack.routeNoun} are deleted.', confirmLabel: 'Start over', destructive: true)) {
                        await ref.read(routesProvider.notifier).restart(route.id);
                        setState(() => _currentStopId = null);
                      }
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'restart', child: Text('Start over'))],
                  ),
                ),
              ]),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.18,
            maxChildSize: 0.9,
            builder: (_, scroll) => Material(
              color: c.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.xxl)),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, Sp.s6),
                children: [
                  Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.outline, borderRadius: BorderRadius.circular(Rad.full)))),
                  const SizedBox(height: Sp.s3),
                  // Before you drive there: what people at this stop just reported.
                  if (current != null && !current.visited && current.pinId != null && pack.community.reports)
                    _LiveHeadsUp(
                      pack: pack,
                      pinId: current.pinId!,
                      onSkip: () {
                        final i = route.stops.indexOf(current);
                        final next = [...route.stops.skip(i + 1), ...route.stops.take(i)].where((s) => !s.visited).firstOrNull;
                        if (next != null) setState(() => _currentStopId = next.id);
                      },
                    ),
                  if (current != null)
                    KnCard(
                      tier: 3,
                      accent: c.tertiary,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          NumberDot(route.stops.indexOf(current) + 1, done: current.visited),
                          const SizedBox(width: Sp.s3),
                          Expanded(child: Text(current.name, style: t.titleLarge, maxLines: 2)),
                        ]),
                        const SizedBox(height: Sp.s1),
                        Text(current.address, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        const SizedBox(height: Sp.s4),
                        if (!current.visited) ...[
                          _QuickLog(
                            pack: pack,
                            outcomes: ref.watch(effectiveOutcomesProvider),
                            logging: _logging,
                            onLog: (o) => _quickLog(pack, route, current, o),
                          ),
                          const SizedBox(height: Sp.s3),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => ref.read(navLauncherProvider).navigateTo(lat: current.lat, lng: current.lng, label: current.name),
                                icon: const Icon(Icons.navigation_outlined),
                                label: const Text('Navigate'),
                              ),
                            ),
                            const SizedBox(width: Sp.s2),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/visit/${route.id}/${current.id}'),
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Details'),
                              ),
                            ),
                          ]),
                        ] else
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => ref.read(navLauncherProvider).navigateTo(lat: current.lat, lng: current.lng, label: current.name),
                              icon: const Icon(Icons.navigation_outlined),
                              label: const Text('Navigate'),
                            ),
                          ),
                          const SizedBox(width: Sp.s2),
                          Expanded(
                            child: KnButton(
                              label: current.visited ? 'Edit visit' : pack.visitVerb,
                              icon: current.visited ? Icons.edit_outlined : Icons.fact_check_outlined,
                              lime: !current.visited,
                              onPressed: () => context.push('/visit/${route.id}/${current.id}'),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  const SizedBox(height: Sp.s3),
                  for (var i = 0; i < route.stops.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: NumberDot(i + 1, done: route.stops[i].visited, color: route.stops[i].id == current?.id ? c.tertiary : null),
                      title: Text(route.stops[i].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: route.stops[i].visited ? TextStyle(color: c.onSurfaceDisabled, decoration: TextDecoration.lineThrough) : null),
                      subtitle: Text(route.stops[i].address, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        setState(() => _currentStopId = route.stops[i].id);
                        _map?.animateCamera(CameraUpdate.newLatLng(LatLng(route.stops[i].lat, route.stops[i].lng)));
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mode's outcomes as big tiles: the visit is logged on tap.
class _QuickLog extends StatelessWidget {
  const _QuickLog({required this.pack, required this.outcomes, required this.logging, required this.onLog});
  final ModePack pack;
  final List<String> outcomes;
  final String? logging;
  final ValueChanged<String> onLog;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('What happened?', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
      const SizedBox(height: Sp.s2),
      // Rows of Expanded pairs, not LayoutBuilder: the accent card sizes by intrinsics.
      for (var i = 0; i < outcomes.length; i += 2) ...[
        if (i > 0) const SizedBox(height: Sp.s2),
        Row(children: [
          Expanded(child: _tile(context, outcomes[i])),
          const SizedBox(width: Sp.s2),
          Expanded(child: i + 1 < outcomes.length ? _tile(context, outcomes[i + 1]) : const SizedBox()),
        ]),
      ],
    ]);
  }

  Widget _tile(BuildContext context, String o) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.surfaceHigh,
      borderRadius: BorderRadius.circular(Rad.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.lg),
        onTap: logging == null ? () => onLog(o) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.s3, vertical: Sp.s2),
            child: Row(children: [
              logging == o
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.tertiary))
                  : Icon(pack.outcomeIcon(o), size: 20, color: c.tertiary),
              const SizedBox(width: Sp.s2),
              Expanded(child: Text(o, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: context.kn.glass, borderRadius: BorderRadius.circular(Rad.full), border: Border.all(color: context.kn.ghostBorder)),
        child: child,
      );
}

/// "Reported packed up 12 min ago · Skip it" above the current stop. Updates as
/// reports stream in, so a sale that closed while you drove is caught in time.
class _LiveHeadsUp extends ConsumerWidget {
  const _LiveHeadsUp({required this.pack, required this.pinId, required this.onSkip});
  final ModePack pack;
  final String pinId;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    ref.listen(reportStreamProvider, (_, next) {
      if (next.value?.any((r) => r['pin_id'] == pinId) ?? false) ref.invalidate(latestReportsProvider(pinId));
    });
    final rep = ref.watch(latestReportsProvider(pinId)).value?[pinId];
    if (rep == null) return const SizedBox.shrink();
    final st = pack.community.statuses.where((s) => s.value == rep.status).firstOrNull;
    final age = DateTime.now().difference(rep.createdAt);
    // Only recent news is worth a banner: "packed up" holds for the day, the rest for an hour.
    final style = switch (st) {
      final s? when s.ends && age <= const Duration(hours: 6) => (c.errorContainer, c.onErrorContainer, true),
      final s? when s.caution && age <= const Duration(hours: 1) => (c.warning, Colors.black, false),
      final s? when s.positive && age <= const Duration(hours: 1) => (c.tertiaryContainer, c.onTertiaryContainer, false),
      _ => null,
    };
    if (style == null) return const SizedBox.shrink();
    final (tint, ink, skip) = style;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s3),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s2, Sp.s2),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(Rad.lg)),
        child: Row(
          children: [
            Icon(st!.icon, color: ink, size: 20),
            const SizedBox(width: Sp.s2),
            Expanded(
              child: Text(
                'Reported ${st.label.toLowerCase()} ${relativeAge(rep.createdAt)}',
                style: t.titleSmall?.copyWith(color: ink),
              ),
            ),
            if (skip) TextButton(onPressed: onSkip, style: TextButton.styleFrom(foregroundColor: ink), child: const Text('Skip it')),
          ],
        ),
      ),
    );
  }
}
