import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/logic/geo.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/app_mode.dart';
import '../../data/models/draft_stop.dart';
import '../../data/models/stop.dart';
import '../../data/repositories/share_repository.dart';
import '../../modes/registry.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../ui/map/pin_icons.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../settings/paywall_sheet.dart';
import 'newcomer_pitch.dart';

/// Where a share link lands, often for someone who has never opened the app.
/// Shows the route on a map, pitches the mode to newcomers, and runs it in one tap.
class SharedRouteScreen extends ConsumerStatefulWidget {
  const SharedRouteScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<SharedRouteScreen> createState() => _SharedRouteScreenState();
}

class _SharedRouteScreenState extends ConsumerState<SharedRouteScreen> with PinIconsMixin {
  late final Future<SharedRoute?> _route = ref.read(shareRepoProvider).fetch(widget.token);
  bool _busy = false;

  /// Copies the route into this user's routes in its mode. Arriving here counts
  /// as onboarding: the link already chose the mode.
  Future<void> _fork(SharedRoute r, {required bool start}) async {
    // A route from a vertical this build doesn't ship lands in the default one.
    final mode = launchable(AppMode.fromId(r.mode));
    final pack = packFor(mode);
    setState(() => _busy = true);
    try {
      final profile = ref.read(profileProvider.notifier);
      if (ref.read(activeModeProvider) != mode) await profile.setMode(mode);
      final saved = (await ref.read(routesProvider.future)).length;
      if (!mounted) return;
      if (pack.pro.atRouteLimit(saved, paying: ref.read(hasProAccessProvider))) {
        await showPaywall(context, pack, reason: freeLimitReason(pack));
        return;
      }
      final route = await ref.read(routesProvider.notifier).save(r.name, [
        for (final s in r.stops) DraftStop(id: s.id, business: s.toBusiness()),
      ]);
      if (!ref.read(localPrefsProvider).hasOnboarded) await profile.markOnboarded();
      if (!mounted) return;
      if (start) {
        context.go('/route/${route.id}');
      } else {
        context.go('/routes');
        toast(context, 'Saved "${route.name}"', icon: Icons.check_circle_outline);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final newcomer = !ref.watch(localPrefsProvider).hasOnboarded;

    return FutureBuilder(
      future: _route,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: LoadingView());
        final r = snap.data;
        if (r == null) {
          return KnScaffold(
            title: 'Shared route',
            body: EmptyState(
              icon: Icons.link_off,
              title: 'This link has expired',
              action: OutlinedButton(onPressed: () => context.go('/map'), child: const Text('Open the map')),
            ),
          );
        }
        final pack = packFor(AppMode.fromId(r.mode));
        final pts = [for (final s in r.stops) LatLng(s.lat, s.lng)];
        var meters = 0.0;
        for (var i = 1; i < r.stops.length; i++) {
          meters += haversineMeters(r.stops[i - 1].lat, r.stops[i - 1].lng, r.stops[i].lat, r.stops[i].lng);
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 280,
                backgroundColor: c.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: pts.isEmpty
                      ? const SizedBox()
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(target: pts.first, zoom: 12),
                          liteModeEnabled: true,
                          zoomGesturesEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          padding: const EdgeInsets.only(top: 56),
                          markers: {
                            for (var i = 0; i < r.stops.length; i++)
                              if (pinIcon(PinSpec.number(i + 1, fill: c.primary, ink: c.onPrimary)) case final icon?)
                                Marker(
                                  markerId: MarkerId('s$i'),
                                  position: pts[i],
                                  icon: icon,
                                  anchor: const Offset(0.5, 0.5),
                                ),
                          },
                          polylines: {
                            Polyline(polylineId: const PolylineId('r'), points: pts, color: c.primary, width: 3),
                          },
                          onMapCreated: (ctl) {
                            if (pts.length < 2) return;
                            final lats = pts.map((p) => p.latitude), lngs = pts.map((p) => p.longitude);
                            ctl.moveCamera(
                              CameraUpdate.newLatLngBounds(
                                LatLngBounds(
                                  southwest: LatLng(
                                    lats.reduce((a, b) => a < b ? a : b),
                                    lngs.reduce((a, b) => a < b ? a : b),
                                  ),
                                  northeast: LatLng(
                                    lats.reduce((a, b) => a > b ? a : b),
                                    lngs.reduce((a, b) => a > b ? a : b),
                                  ),
                                ),
                                48,
                              ),
                            );
                          },
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Sp.s5, Sp.s5, Sp.s5, Sp.s6),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Icon(pack.icon, size: 18, color: c.tertiary),
                        const SizedBox(width: Sp.s2),
                        Text(
                          pack.label.toUpperCase(),
                          style: t.labelMedium?.copyWith(
                            color: c.tertiary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.s2),
                    Text(r.name, style: t.displaySmall),
                    const SizedBox(height: Sp.s1),
                    Text(
                      [
                        '${r.stops.length} ${pack.stopNoun}s',
                        if (meters > 0) formatDistance(meters),
                        if (r.ownerHandle != null) 'shared by @${r.ownerHandle}',
                      ].join(' · '),
                      style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                    ),
                    if (newcomer) ...[
                      const SizedBox(height: Sp.s5),
                      NewcomerPitch(pack: pack),
                    ],
                    const SizedBox(height: Sp.s5),
                    for (var i = 0; i < r.stops.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: NumberDot(i + 1),
                        title: Text(r.stops[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(r.stops[i].address, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: !r.canFork
              ? null
              : SafeArea(
                  child: Container(
                    color: c.surfaceLow,
                    padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s4, Sp.s4),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _fork(r, start: false),
                          child: const Text('Save for later'),
                        ),
                        const SizedBox(width: Sp.s2),
                        Expanded(
                          child: KnButton(
                            label: 'Start this ${pack.routeNoun}',
                            icon: Icons.navigation_outlined,
                            lime: true,
                            loading: _busy,
                            onPressed: () => _fork(r, start: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
