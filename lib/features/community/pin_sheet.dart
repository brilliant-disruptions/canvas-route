import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/logic/errors.dart';
import '../../core/env.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/logic/freshness.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/business.dart';
import '../../data/models/pin.dart';
import '../../data/models/report.dart';
import '../../data/models/stop.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';

Future<void> showPinSheet(BuildContext context, Pin pin) => showKnSheet(context, builder: (_) => PinSheet(pin: pin));

Business businessFromPin(Pin p) => Business(
  pinId: p.id,
  placeId: p.placeId,
  name: p.name,
  address: p.address ?? '',
  lat: p.lat,
  lng: p.lng,
  source: StopSource.community,
  opensAt: p.opensAt,
  closesAt: p.closesAt,
  listingUrl: p.listingUrl,
);

/// A community listing's sheet: live status, hours, categories, photos, recent
/// reports, and one-tap "Still going?" report chips.
class PinSheet extends ConsumerWidget {
  const PinSheet({super.key, required this.pin});
  final Pin pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final map = ref.watch(mapProvider);
    final nav = ref.read(navLauncherProvider);
    final anon = ref.watch(isAnonymousProvider);
    final business = businessFromPin(pin);
    final added = map.isDraft(business);
    final recent = ref.watch(recentReportsProvider(pin.id));
    // Time-boxed sales get a live status, and take reports only while they're on.
    final now = DateTime.now();
    final phase = pin.kind == PinKind.yardSale && pin.opensAt != null
        ? salePhase(pin.opensAt!, pin.closesAt, now)
        : null;
    final takesReports = phase == null || salePhaseTakesReports(phase);
    final phaseColor = switch (phase) {
      SalePhase.open => c.tertiary,
      SalePhase.closingSoon => c.warning,
      SalePhase.ended => c.error,
      _ => c.primary,
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s6),
        children: [
          if (phase != null) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: phaseColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: Sp.s2),
                Text(
                  saleStatus(pin.opensAt!, pin.closesAt, now).toUpperCase(),
                  style: t.labelMedium?.copyWith(color: phaseColor, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ],
            ),
            const SizedBox(height: Sp.s1),
          ],
          Text(pin.name, style: t.headlineSmall),
          if (pin.address != null) Text(pin.address!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s3),
          Wrap(
            spacing: Sp.s2,
            runSpacing: Sp.s2,
            children: [
              if (pin.kind == PinKind.yardSale && pin.opensAt != null)
                KnBadge(
                  '${DateFormat.MMMEd().format(pin.opensAt!)} · ${DateFormat.jm().format(pin.opensAt!)}–${pin.closesAt == null ? '' : DateFormat.jm().format(pin.closesAt!)}',
                  icon: Icons.schedule,
                ),
              if (pin.origin == PinOrigin.host)
                KnBadge(
                  'Posted by host',
                  color: c.tertiaryContainer,
                  onColor: c.onTertiaryContainer,
                  icon: Icons.verified_outlined,
                ),
              if (pin.origin == PinOrigin.permit)
                KnBadge('City permit', icon: Icons.assignment_turned_in_outlined),
              if (pin.origin == PinOrigin.spotted)
                KnBadge('Spotted · ${pin.confirmations} confirm', icon: Icons.visibility_outlined),
              if (pin.earlyBirds == 'not_welcome')
                KnBadge('No early birds', color: c.errorContainer, onColor: c.onErrorContainer),
              if (pin.earlyBirds == 'welcome') KnBadge('Early birds OK'),
              for (final cat in pin.categories) KnBadge(cat, color: c.surfaceHighest, onColor: c.onSurface),
            ],
          ),
          if (pin.notes != null && pin.notes!.isNotEmpty) ...[
            const SizedBox(height: Sp.s3),
            Text(pin.notes!, style: t.bodyMedium),
          ],
          if (pin.photoPaths.isNotEmpty) ...[
            const SizedBox(height: Sp.s3),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pin.photoPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: Sp.s2),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(Rad.lg),
                  child: Image.network(pin.photoPaths[i], width: 160, height: 120, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          if (pin.listingUrl != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open listing'),
              onTap: () => nav.open(pin.listingUrl!),
            ),
          const SizedBox(height: Sp.s4),
          Row(
            children: [
              Expanded(
                child: KnButton(
                  label: added ? 'Remove' : 'Add to route',
                  icon: added ? Icons.remove_circle_outline : Icons.add_location_alt_outlined,
                  onPressed: () {
                    ref.read(mapProvider.notifier).toggleDraft(business);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: Sp.s2),
              SizedBox(
                width: 52,
                child: OutlinedButton(
                  onPressed: () => nav.navigateTo(lat: pin.lat, lng: pin.lng, label: pin.name),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Icon(Icons.navigation_outlined),
                ),
              ),
              if (pin.shareToken != null) ...[
                const SizedBox(width: Sp.s2),
                SizedBox(
                  width: 52,
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(shareServiceProvider)
                        .shareText('${pin.name} — ${Env.webOrigin}/s/${pin.shareToken}', subject: pin.name),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Icon(Icons.ios_share),
                  ),
                ),
              ],
            ],
          ),
          if (pack.communityReports) ...[
            SectionHeader(
              takesReports ? 'Still going?' : 'Live reports',
              trailing: anon && takesReports
                  ? TextButton(
                      onPressed: () => context.push('/signin?reason=report'),
                      child: const Text('Sign in to report'),
                    )
                  : null,
            ),
            if (!takesReports)
              Text(
                phase == SalePhase.ended
                    ? 'This sale has ended.'
                    : 'Reports open when the sale starts, so they reflect what\'s really there.',
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: Sp.s2,
                children: [
                  for (final s in pack.reportStatuses)
                    ActionChip(
                      avatar: Icon(s.icon, size: 16),
                      label: Text(s.label),
                      onPressed: anon
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(reportRepoProvider)
                                    .create(
                                      ReportDraft(pinId: pin.id, status: s.value),
                                      ref.read(currentUserIdProvider)!,
                                    );
                                ref.invalidate(recentReportsProvider(pin.id));
                                if (context.mounted) {
                                  toast(
                                    context,
                                    'Thanks — shared with nearby ${pack.communityNoun}',
                                    icon: Icons.check,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  toast(
                                    context,
                                    friendlyError(
                                      e,
                                      denied: 'You can report a place 3 times an hour. Try again a bit later.',
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                ],
              ),
            const SizedBox(height: Sp.s3),
            ...recent.when(
              loading: () => const [LinearProgressIndicator()],
              error: (e, _) => [Text(friendlyError(e), style: t.bodySmall)],
              data: (list) => list.isEmpty
                  ? [if (takesReports) Text('No reports yet.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))]
                  : [
                      for (final r in list.take(5))
                        _ReportRow(
                          r,
                          pack.reportStatuses.where((s) => s.value == r.status).firstOrNull?.label ?? r.status,
                        ),
                    ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.r, this.label);
  final Report r;
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(relativeAge(r.createdAt), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
          ),
          const SizedBox(width: Sp.s3),
          Expanded(child: Text(label, style: t.bodySmall)),
        ],
      ),
    );
  }
}
