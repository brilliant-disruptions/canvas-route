import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/feature_request.dart';
import '../../data/models/pin.dart';
import '../../state/community_state.dart';
import '../../state/feature_requests_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../feature_requests/feature_requests_screen.dart';

/// Role-gated. Requests pipeline, pin moderation, product catalog merges.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAdminProvider)) return const Scaffold(body: EmptyState(icon: Icons.lock_outline, title: 'Admins only'));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [const Text('Admin'), const SizedBox(width: Sp.s2), KnBadge('ADMIN', color: context.kn.error, onColor: context.kn.onError)]),
          bottom: const TabBar(tabs: [Tab(text: 'Requests'), Tab(text: 'Pins'), Tab(text: 'Products')]),
        ),
        body: const TabBarView(children: [_Requests(), _Pins(), _Products()]),
      ),
    );
  }
}

class _Requests extends ConsumerWidget {
  const _Requests();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final q = ref.watch(adminQueueProvider);
    return AsyncView(
      value: q,
      onRetry: () => ref.invalidate(adminQueueProvider),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.all(Sp.s4),
        itemCount: list.length,
        separatorBuilder: (_, _) => const GhostDivider(),
        itemBuilder: (_, i) {
          final r = list[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.s2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.title, style: t.titleMedium)),
                DropdownButton<String>(
                  value: r.status,
                  underline: const SizedBox(),
                  items: [for (final s in featureRequestStatuses) DropdownMenuItem(value: s, child: Text(statusLabel(s), style: t.labelMedium?.copyWith(color: statusColor(context, s))))],
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref.read(featureRequestRepoProvider).setStatus(r.id, v);
                    ref.invalidate(adminQueueProvider);
                  },
                ),
              ]),
              Text(
                [
                  // Codes read as words; the email stays exactly as entered.
                  for (final code in [r.category, ?r.role, ?r.frequency, ?r.impact]) code.replaceAll('_', ' '),
                  '${r.upvoteCount} vote${r.upvoteCount == 1 ? '' : 's'}',
                  if (r.interviewOptIn) 'interview: ${r.interviewEmail}',
                ].join(' · '),
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
              if (r.problem != null && r.problem!.isNotEmpty) Text(r.problem!, style: t.bodySmall),
              TextButton(
                onPressed: () async {
                  final s = await promptText(context, title: 'Public summary', initial: r.summary);
                  if (s != null) {
                    await ref.read(featureRequestRepoProvider).setStatus(r.id, r.status, summary: s);
                    ref.invalidate(adminQueueProvider);
                  }
                },
                child: Text(r.summary == null ? 'Write summary' : 'Edit summary'),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Pins extends ConsumerWidget {
  const _Pins();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    return FutureBuilder<List<Pin>>(
      future: ref.read(pinRepoProvider).pendingForAdmin(),
      builder: (_, snap) {
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) return const EmptyState(icon: Icons.check_circle_outline, title: 'No pins awaiting review');
        return ListView.separated(
          padding: const EdgeInsets.all(Sp.s4),
          itemCount: list.length,
          separatorBuilder: (_, _) => const GhostDivider(),
          itemBuilder: (_, i) {
            final p = list[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text('${p.status.name} · ${p.origin.name} · ${p.address ?? ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Approve', icon: Icon(Icons.check, color: c.statusDone), onPressed: () async {
                  await ref.read(pinRepoProvider).setStatus(p.id, PinStatus.live);
                  ref.invalidate(myPinsProvider);
                  if (context.mounted) (context as Element).markNeedsBuild();
                }),
                IconButton(tooltip: 'Remove', icon: Icon(Icons.delete_outline, color: c.error), onPressed: () async {
                  await ref.read(pinRepoProvider).setStatus(p.id, PinStatus.removed);
                  if (context.mounted) (context as Element).markNeedsBuild();
                }),
              ]),
            );
          },
        );
      },
    );
  }
}

class _Products extends ConsumerWidget {
  const _Products();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canonical = ref.watch(productsProvider).value ?? const [];
    return FutureBuilder(
      future: ref.read(productRepoProvider).nonCanonical(),
      builder: (_, snap) {
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No free-text products to merge');
        return ListView.separated(
          padding: const EdgeInsets.all(Sp.s4),
          itemCount: list.length,
          separatorBuilder: (_, _) => const GhostDivider(),
          itemBuilder: (_, i) {
            final p = list[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.displayName),
              subtitle: const Text('Free-text · tap to merge into a canonical product'),
              onTap: () async {
                final target = await showKnSheet<String>(
                  context,
                  builder: (_) => ListView(
                    padding: const EdgeInsets.all(Sp.s4),
                    children: [for (final cp in canonical) ListTile(title: Text(cp.displayName), onTap: () => Navigator.pop(context, cp.id))],
                  ),
                );
                if (target != null) {
                  await ref.read(productRepoProvider).merge(p.id, target);
                  if (context.mounted) (context as Element).markNeedsBuild();
                }
              },
            );
          },
        );
      },
    );
  }
}
