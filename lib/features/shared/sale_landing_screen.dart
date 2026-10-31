import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/logic/pin_labels.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../modes/registry.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/map/pin_icons.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/pin_sheet.dart';
import 'newcomer_pitch.dart';

/// Where a host's sign QR lands: the sale, its hours, and one tap to add it to
/// tonight's plan. Scanning a sign counts as onboarding.
class SaleLandingScreen extends ConsumerStatefulWidget {
  const SaleLandingScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<SaleLandingScreen> createState() => _SaleLandingScreenState();
}

class _SaleLandingScreenState extends ConsumerState<SaleLandingScreen> with PinIconsMixin {
  late final Future<Pin?> _pin = ref.read(pinRepoProvider).byShareToken(widget.token);
  bool _busy = false;

  Future<void> _add(Pin pin) async {
    setState(() => _busy = true);
    try {
      final profile = ref.read(profileProvider.notifier);
      if (ref.read(activeModeProvider) != pin.mode) await profile.setMode(pin.mode);
      ref.read(mapProvider.notifier).addDraft(businessFromPin(pin));
      if (!ref.read(localPrefsProvider).hasOnboarded) await profile.markOnboarded();
      if (!mounted) return;
      context.go('/map');
      toast(context, 'Added "${pin.name}" to your route', icon: Icons.add_location_alt);
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
        final pack = packFor(pin.mode);
        final at = LatLng(pin.lat, pin.lng);
        final label = pin.opensAt == null ? pin.name : compactWindow(pin.opensAt!, pin.closesAt);
        final icon = pinIcon(PinSpec.pill(label, fill: c.tertiary, ink: c.onTertiary, halo: true));

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: c.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: GoogleMap(
                    initialCameraPosition: CameraPosition(target: at, zoom: 14),
                    liteModeEnabled: true,
                    zoomGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    padding: const EdgeInsets.only(top: 56),
                    markers: {
                      if (icon != null)
                        Marker(
                          markerId: const MarkerId('sale'),
                          position: at,
                          icon: icon,
                          anchor: const Offset(0.5, 1),
                        ),
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
                    Text(pin.name, style: t.displaySmall),
                    if (pin.opensAt != null) ...[
                      const SizedBox(height: Sp.s2),
                      Text(
                        '${DateFormat.MMMEd().format(pin.opensAt!)} · ${compactWindow(pin.opensAt!, pin.closesAt)}',
                        style: t.headlineSmall?.copyWith(color: c.tertiary),
                      ),
                    ],
                    if (pin.address != null)
                      Text(pin.address!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
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
                    if (pin.notes != null && pin.notes!.isNotEmpty) ...[
                      const SizedBox(height: Sp.s4),
                      Text(pin.notes!, style: t.bodyLarge),
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
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(navLauncherProvider).navigateTo(lat: pin.lat, lng: pin.lng, label: pin.name),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Directions'),
                  ),
                  const SizedBox(width: Sp.s2),
                  Expanded(
                    child: KnButton(
                      label: 'Add to my route',
                      icon: Icons.add_location_alt_outlined,
                      lime: true,
                      loading: _busy,
                      onPressed: () => _add(pin),
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
