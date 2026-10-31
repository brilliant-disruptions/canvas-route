import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logic/errors.dart';
import '../../core/logic/geo.dart';
import '../../core/logic/visit_history.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/business.dart';
import '../../data/models/stop.dart';
import '../../data/models/team.dart';
import '../../state/auth_state.dart';
import '../../state/follow_ups_state.dart';
import '../../state/location_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/team_state.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/report_sheet.dart';
import '../settings/paywall_sheet.dart';

Future<void> showBusinessSheet(BuildContext context, Business b) =>
    showKnSheet(context, builder: (_) => BusinessSheet(business: b));

/// Bottom sheet for a Places result or manual stop. Details (phone, website,
/// hours) are fetched on open, not on search (spec API notes).
class BusinessSheet extends ConsumerWidget {
  const BusinessSheet({super.key, required this.business});
  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final map = ref.watch(mapProvider);
    final pack = ref.watch(modePackProvider);
    final center = ref.watch(mapCenterProvider);
    final nav = ref.read(navLauncherProvider);
    final added = map.isDraft(business);
    final dist = haversineMeters(center.lat, center.lng, business.lat, business.lng);
    final history = ref.watch(visitHistoryProvider)[business.identity];
    final seeHistory = !pack.visitHistoryPro || ref.watch(hasProAccessProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(business.name, style: t.headlineSmall),
          const SizedBox(height: Sp.s1),
          Text(business.address, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s3),
          Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
            KnBadge(formatDistance(dist), icon: Icons.near_me_outlined),
            if (business.rating != null) KnBadge(business.rating!.toStringAsFixed(1), icon: Icons.star_rate_rounded),
            if (business.source == StopSource.manual) KnBadge('Manual stop', color: c.tertiaryContainer, onColor: c.onTertiaryContainer),
            if (business.listingUrl != null) KnBadge('Listing', icon: Icons.link),
          ]),
          if (history != null) ...[
            const SizedBox(height: Sp.s3),
            KnCard(
              tier: 2,
              accent: c.tertiary,
              onTap: seeHistory
                  ? null
                  : () => showPaywall(context, pack, reason: 'See what happened last time at every ${pack.stopNoun} with ${pack.proLabel}.'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(pack.outcomeIcons[history.lastOutcome] ?? Icons.history, color: c.tertiary),
                  const SizedBox(width: Sp.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(visitHistoryLine(history, DateTime.now()), style: t.titleSmall),
                        if (seeHistory) ...[
                          if (history.lastOutcome != null)
                            Text('Last time: ${history.lastOutcome}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                          if (history.lastNotes != null && history.lastNotes!.isNotEmpty)
                            Text(history.lastNotes!, style: t.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                        ] else
                          Text('See last outcome and notes with ${pack.proLabel}', style: t.bodySmall?.copyWith(color: c.tertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Don't double-knock: who on the team has been here lately (outcome only).
          if (pack.teamPlan && business.placeId != null)
            for (final v in ref.watch(teammateVisitsProvider(business.placeId!)).value ?? const <TeammateVisit>[])
              Padding(
                padding: const EdgeInsets.only(top: Sp.s2),
                child: Row(
                  children: [
                    Icon(Icons.groups_outlined, size: 18, color: c.onSurfaceVariant),
                    const SizedBox(width: Sp.s2),
                    Expanded(
                      child: Text(
                        '${v.name} visited ${visitHistoryLine(VisitHistory(count: 1, lastAt: v.visitedAt), DateTime.now()).replaceFirst('Visited ', '')}${v.outcome == null ? '' : ' · ${v.outcome}'}',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
          if (business.placeId != null)
            FutureBuilder(
              future: ref.read(placesServiceProvider).details(business.placeId!),
              builder: (_, snap) {
                final d = snap.data;
                if (d == null) return const SizedBox(height: Sp.s3);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Sp.s3),
                    if (d.phone != null)
                      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.call_outlined), title: Text(d.phone!), onTap: () => nav.call(d.phone!)),
                    if (d.website != null)
                      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.language), title: Text(d.website!, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => nav.open(d.website!)),
                    if (d.hours.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: Text(_todayHours(d.hours)),
                        children: [for (final h in d.hours) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 56, bottom: 4), child: Text(h, style: t.bodySmall)))],
                      ),
                  ],
                );
              },
            ),
          if (business.listingUrl != null)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.open_in_new), title: const Text('Open listing'), onTap: () => nav.open(business.listingUrl!)),
          const SizedBox(height: Sp.s4),
          Row(children: [
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
            if (pack.communityReports && pack.productCatalog && business.placeId != null) ...[
              const SizedBox(width: Sp.s2),
              SizedBox(
                width: 52,
                child: OutlinedButton(
                  onPressed: () async {
                    // Reporting needs a real account (the server refuses guests).
                    if (ref.read(isAnonymousProvider)) {
                      Navigator.pop(context);
                      context.push('/signin?reason=report');
                      return;
                    }
                    try {
                      final pin = await ref.read(pinRepoProvider).ensureStorePin(business);
                      if (context.mounted) {
                        Navigator.pop(context);
                        showReportSheet(context, pin);
                      }
                    } catch (e) {
                      if (context.mounted) toast(context, friendlyError(e));
                    }
                  },
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Icon(Icons.campaign_outlined),
                ),
              ),
            ],
          ]),
          const SizedBox(height: Sp.s2),
          OutlinedButton.icon(
            onPressed: () => nav.navigateTo(lat: business.lat, lng: business.lng, label: business.name),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Navigate'),
          ),
        ],
      ),
    );
  }

  String _todayHours(List<String> hours) {
    final names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = names[DateTime.now().weekday - 1];
    return hours.firstWhere((h) => h.startsWith(today), orElse: () => hours.first);
  }
}
