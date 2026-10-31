import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logic/follow_ups.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/stop.dart';
import '../../state/follow_ups_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../settings/paywall_sheet.dart';

/// Every visit that asked for a callback, grouped by when it's due. Today's and
/// overdue ones route in one tap.
class FollowUpsScreen extends ConsumerWidget {
  const FollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(modePackProvider);
    final list = ref.watch(followUpsProvider);
    final now = DateTime.now();
    final due = (list.value ?? const <FollowUp>[])
        .where((f) => followUpBucket(f.due, now).index <= FollowUpBucket.today.index)
        .toList();

    Future<void> routeDue() async {
      if (!await requirePro(context, ref, 'Routing your callbacks is part of ${pack.proLabel}.')) return;
      if (!context.mounted) return;
      final map = ref.read(mapProvider.notifier);
      for (final f in due) {
        map.addDraft(f.stop.toBusiness());
      }
      HapticFeedback.mediumImpact();
      context.push('/route/builder');
    }

    return KnScaffold(
      title: pack.followUpsLabel ?? 'Follow-ups',
      bottom: due.isEmpty
          ? null
          : KnButton(
              label: 'Route ${due.length == 1 ? 'today\'s follow-up' : 'today\'s ${due.length}'}',
              icon: Icons.alt_route,
              lime: true,
              onPressed: routeDue,
            ),
      body: AsyncView(
        value: list,
        onRetry: () => ref.invalidate(followUpsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No follow-ups',
              body: 'Set a follow-up date when you log a visit and it shows up here on the day.',
            );
          }
          final groups = <FollowUpBucket, List<FollowUp>>{};
          for (final f in items) {
            groups.putIfAbsent(followUpBucket(f.due, now), () => []).add(f);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(followUpsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s6),
              children: [
                for (final b in FollowUpBucket.values)
                  if (groups[b] != null) ...[
                    SectionHeader('${followUpBucketTitle(b)} · ${groups[b]!.length}'),
                    for (final f in groups[b]!) ...[
                      _FollowUpCard(f: f, now: now),
                      const SizedBox(height: Sp.s3),
                    ],
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FollowUpCard extends ConsumerWidget {
  const _FollowUpCard({required this.f, required this.now});
  final FollowUp f;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final bucket = followUpBucket(f.due, now);
    final v = f.visit;
    final actions = ref.read(followUpActionsProvider);
    final phone = v.phone;

    // Seeing what's due is free; working the list is the paid tier.
    Future<bool> pro() => requirePro(context, ref, '${pack.followUpsLabel ?? 'Follow-ups'} are part of ${pack.proLabel}.');

    Future<void> move(DateTime? to, String message) async {
      if (!await pro()) return;
      try {
        await actions.reschedule(f, to);
        if (context.mounted) toast(context, message, icon: Icons.check);
      } catch (e) {
        if (context.mounted) toast(context, 'Couldn\'t update. Try again.');
      }
    }

    return KnCard(
      tier: bucket == FollowUpBucket.later ? 1 : 2,
      accent: switch (bucket) {
        FollowUpBucket.overdue => c.error,
        FollowUpBucket.today => c.tertiary,
        _ => null,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pack.outcomeIcons[v.outcome] != null) ...[
                Icon(pack.outcomeIcons[v.outcome], color: c.tertiary, size: 22),
                const SizedBox(width: Sp.s3),
              ],
              Expanded(child: Text(f.stop.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: Sp.s2),
              KnBadge(
                followUpDueLabel(f.due, now),
                color: bucket == FollowUpBucket.overdue ? c.errorContainer : c.surfaceHighest,
                onColor: bucket == FollowUpBucket.overdue ? c.onErrorContainer : c.onSurface,
              ),
            ],
          ),
          const SizedBox(height: Sp.s1),
          Text(
            [?v.outcome, ?v.contactName, f.route.name].join(' · '),
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          if (v.notes != null && v.notes!.isNotEmpty) ...[
            const SizedBox(height: Sp.s2),
            Text(v.notes!, style: t.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: Sp.s2),
          Wrap(
            spacing: Sp.s1,
            children: [
              if (phone != null && phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => ref.read(navLauncherProvider).call(phone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Call'),
                ),
              TextButton.icon(
                onPressed: () async {
                  if (!await pro() || !context.mounted) return;
                  ref.read(mapProvider.notifier).addDraft(f.stop.toBusiness());
                  toast(context, 'Added to your next ${pack.routeNoun}', icon: Icons.add_location_alt_outlined);
                },
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add stop'),
              ),
              TextButton.icon(
                onPressed: () => move(snoozeWeek(now, f.due), 'Moved a week later'),
                icon: const Icon(Icons.snooze, size: 18),
                label: const Text('Next week'),
              ),
              TextButton.icon(
                onPressed: () => move(null, 'Follow-up done'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
