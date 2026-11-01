import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/logic/geo.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/logic/freshness.dart';
import '../../core/logic/sale_page.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../modes/mode_pack.dart';
import '../../modes/registry.dart';
import '../../state/community_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/map/pin_icons.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/pin_sheet.dart';
import '../host/host_sale_screen.dart' show saleLink;
import 'newcomer_pitch.dart';

/// Where a shared link or a sign's QR lands. One sale is the hook; the page turns
/// it into a whole morning: live status, the host's photos, the other sales
/// nearby that day, and one tap to plan them all. Visiting counts as onboarding.
class SaleLandingScreen extends ConsumerStatefulWidget {
  const SaleLandingScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<SaleLandingScreen> createState() => _SaleLandingScreenState();
}

class _SaleLandingScreenState extends ConsumerState<SaleLandingScreen> with PinIconsMixin {
  late final Future<Pin?> _pin = ref.read(pinRepoProvider).byShareToken(widget.token);
  bool _busy = false;

  /// Adds [pins] (this sale first) to a fresh draft and opens the planner.
  Future<void> _plan(Pin anchor, List<Pin> pins) async {
    setState(() => _busy = true);
    try {
      final profile = ref.read(profileProvider.notifier);
      if (ref.read(activeModeProvider) != anchor.mode) await profile.setMode(anchor.mode);
      if (!ref.read(localPrefsProvider).hasOnboarded) await profile.markOnboarded();
      final map = ref.read(mapProvider.notifier)..clearDrafts();
      for (final p in [anchor, ...pins]) {
        map.addDraft(businessFromPin(p));
      }
      if (!mounted) return;
      final router = ref.read(routerProvider);
      router.go('/map');
      if (pins.isEmpty) {
        toast(context, 'Added "${anchor.name}" to your route', icon: Icons.add_location_alt);
      } else {
        router.push('/route/builder');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newcomer = !ref.watch(localPrefsProvider).hasOnboarded;
    return FutureBuilder(
      future: _pin,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: LoadingView());
        final pin = snap.data;
        if (pin == null || !pin.isLive) {
          return KnScaffold(
            title: 'Sale',
            body: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'This sale has wrapped up',
              body: 'Find more on the map.',
              action: OutlinedButton(onPressed: () => context.go('/map'), child: const Text('Open the map')),
            ),
          );
        }
        return _SalePage(pin: pin, newcomer: newcomer, busy: _busy, onPlan: _plan, pinIcon: pinIcon);
      },
    );
  }
}

class _SalePage extends ConsumerWidget {
  const _SalePage({required this.pin, required this.newcomer, required this.busy, required this.onPlan, required this.pinIcon});
  final Pin pin;
  final bool newcomer;
  final bool busy;
  final Future<void> Function(Pin anchor, List<Pin> pins) onPlan;
  final BitmapDescriptor? Function(PinSpec) pinIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = packFor(pin.mode);
    final now = DateTime.now();

    // Other sales that day within a few miles: the reason to install.
    final key = (mode: pin.mode, lat: double.parse(pin.lat.toStringAsFixed(2)), lng: double.parse(pin.lng.toStringAsFixed(2)), radiusMi: 5.0);
    final nearby = ref.watch(nearbyPinsProvider(key)).value ?? const <Pin>[];
    PageListing listing(Pin p) => (id: p.id, lat: p.lat, lng: p.lng, opensAt: p.opensAt, closesAt: p.closesAt);
    final byId = {for (final p in nearby) p.id: p};
    final sameDay = sameDayNearby(listing(pin), nearby.map(listing), now);
    // Leave out sales hunters just reported as packed up, as the map's plan does.
    final reports = sameDay.isEmpty ? const {} : (ref.watch(latestReportsProvider(sameDay.join(','))).value ?? const {});
    bool over(String id) {
      final r = reports[id];
      final st = r == null ? null : pack.reportStatuses.where((s) => s.value == r.status).firstOrNull;
      return st != null && st.ends && now.difference(r!.createdAt) <= const Duration(hours: 6);
    }
    final companions = [for (final id in sameDay) if (!over(id)) byId[id]!];
    final toPlan = companions.take(pack.planMaxStops - 1).toList();

    final status = _status(ref, pack, now);
    final day = pin.opensAt == null ? 'day' : DateFormat.EEEE().format(pin.opensAt!);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: c.surface,
            flexibleSpace: FlexibleSpaceBar(background: _Hero(pin: pin, pinIcon: pinIcon)),
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
                      style: t.labelMedium?.copyWith(color: c.tertiary, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.s2),
                Text(pin.name, style: t.displaySmall),
                if (status != null) ...[
                  const SizedBox(height: Sp.s2),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: status.$2 ? c.tertiary : c.onSurfaceVariant),
                      const SizedBox(width: Sp.s2),
                      Expanded(child: Text(status.$1, style: t.titleMedium?.copyWith(color: status.$2 ? c.tertiary : c.onSurface))),
                    ],
                  ),
                ],
                if (pin.opensAt != null) ...[
                  const SizedBox(height: Sp.s1),
                  Text(
                    '${DateFormat.MMMEd().format(pin.opensAt!)} · ${compactWindow(pin.opensAt!, pin.closesAt)}',
                    style: t.headlineSmall?.copyWith(color: c.tertiary),
                  ),
                ],
                if (pin.address != null) Text(pin.address!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(height: Sp.s3),
                Wrap(
                  spacing: Sp.s2,
                  runSpacing: Sp.s2,
                  children: [
                    if (pin.earlyBirds == 'not_welcome')
                      KnBadge('No early birds', color: c.errorContainer, onColor: c.onErrorContainer),
                    for (final cat in pin.categories) KnBadge(cat, color: c.surfaceHighest, onColor: c.onSurface),
                  ],
                ),
                const SizedBox(height: Sp.s3),
                Wrap(
                  spacing: Sp.s2,
                  runSpacing: Sp.s1,
                  children: [
                    if (pin.opensAt != null)
                      ActionChip(
                        avatar: const Icon(Icons.event_outlined, size: 18),
                        label: const Text('Add to calendar'),
                        onPressed: () => ref.read(navLauncherProvider).open(
                              googleCalendarLink(
                                title: pin.name,
                                start: pin.opensAt!,
                                end: pin.closesAt,
                                location: pin.address,
                                details: saleLink(pin),
                              ).toString(),
                            ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Share'),
                      onPressed: () => ref.read(shareServiceProvider).shareText('${pin.name} — ${saleLink(pin)}', subject: pin.name),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.navigation_outlined, size: 18),
                      label: const Text('Directions'),
                      onPressed: () => ref.read(navLauncherProvider).navigateTo(lat: pin.lat, lng: pin.lng, label: pin.name),
                    ),
                  ],
                ),
                if (pin.notes != null && pin.notes!.isNotEmpty) ...[
                  const SizedBox(height: Sp.s4),
                  Text(pin.notes!, style: t.bodyLarge),
                ],
                if (companions.isNotEmpty) ...[
                  SectionHeader(
                    '+${companions.length} more ${pack.stopNoun}${companions.length == 1 ? '' : 's'} nearby that $day',
                    subtitle: 'Within 3 miles. Plan them in one route.',
                  ),
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: companions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Sp.s2),
                      itemBuilder: (_, i) => _CompanionCard(anchor: pin, pin: companions[i]),
                    ),
                  ),
                ],
                if (newcomer) ...[const SizedBox(height: Sp.s5), NewcomerPitch(pack: pack)],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: c.surfaceLow,
          padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s4, Sp.s4),
          child: toPlan.isEmpty
              ? KnButton(
                  label: 'Add to my route',
                  icon: Icons.add_location_alt_outlined,
                  lime: true,
                  loading: busy,
                  onPressed: () => onPlan(pin, const []),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KnButton(
                      label: 'Plan my $day around this',
                      icon: Icons.bolt,
                      lime: true,
                      loading: busy,
                      onPressed: () => onPlan(pin, toPlan),
                    ),
                    TextButton(onPressed: busy ? null : () => onPlan(pin, const []), child: const Text('Just add this one')),
                  ],
                ),
        ),
      ),
    );
  }

  /// "Still going · reported 9:18am" from a fresh report, else the posted-hours
  /// status ("Opens Sat 7am · in 7 days"). The bool says whether it's live news.
  (String, bool)? _status(WidgetRef ref, ModePack pack, DateTime now) {
    final rep = ref.watch(latestReportsProvider(pin.id)).value?[pin.id];
    final st = rep == null ? null : pack.reportStatuses.where((s) => s.value == rep.status).firstOrNull;
    if (st != null && now.difference(rep!.createdAt) <= Duration(hours: st.ends ? 6 : 1)) {
      return ('${st.label} · reported ${relativeAge(rep.createdAt)}', st.positive);
    }
    if (pin.opensAt == null) return null;
    final phase = salePhase(pin.opensAt!, pin.closesAt, now);
    return (saleStatus(pin.opensAt!, pin.closesAt, now), phase == SalePhase.open || phase == SalePhase.closingSoon);
  }
}

/// The host's photos when there are any (swipe through), else the map.
class _Hero extends StatelessWidget {
  const _Hero({required this.pin, required this.pinIcon});
  final Pin pin;
  final BitmapDescriptor? Function(PinSpec) pinIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    if (pin.photoPaths.isNotEmpty) {
      return PageView(
        children: [
          for (final url in pin.photoPaths)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceHigh, child: Icon(Icons.image_not_supported_outlined, color: c.onSurfaceVariant)),
            ),
        ],
      );
    }
    final at = LatLng(pin.lat, pin.lng);
    final label = pin.opensAt == null ? pin.name : compactWindow(pin.opensAt!, pin.closesAt);
    final icon = pinIcon(PinSpec.pill(label, fill: c.tertiary, ink: c.onTertiary, halo: true));
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: at, zoom: 14),
      liteModeEnabled: true,
      zoomGesturesEnabled: false,
      scrollGesturesEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      padding: const EdgeInsets.only(top: 56),
      markers: {
        if (icon != null) Marker(markerId: const MarkerId('sale'), position: at, icon: icon, anchor: const Offset(0.5, 1)),
      },
    );
  }
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({required this.anchor, required this.pin});
  final Pin anchor;
  final Pin pin;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final miles = metersToMiles(haversineMeters(anchor.lat, anchor.lng, pin.lat, pin.lng));
    return SizedBox(
      width: 200,
      child: KnCard(
        tier: 2,
        onTap: () => showPinSheet(context, pin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pin.opensAt == null ? '' : compactWindow(pin.opensAt!, pin.closesAt), style: t.labelMedium?.copyWith(color: c.tertiary)),
            const SizedBox(height: Sp.s1),
            Text(pin.name, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(
              [miles < 0.1 ? 'next door' : '${miles.toStringAsFixed(1)} mi', if (pin.categories.isNotEmpty) pin.categories.first].join(' · '),
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
