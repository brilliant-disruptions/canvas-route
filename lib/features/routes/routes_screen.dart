import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/shell.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/route_model.dart';
import '../../state/auth_state.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../../ui/widgets/route_sketch.dart';
import '../settings/paywall_sheet.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(modePackProvider);
    final routes = ref.watch(routesProvider);
    final paying = ref.watch(isPayingProvider);

    Future<void> newRoute() async {
      final count = routes.value?.length ?? 0;
      if (pack.atRouteLimit(count, paying: paying)) {
        await showPaywall(context, pack, reason: freeLimitReason(pack));
        return;
      }
      ref.read(mapProvider.notifier).clearEditing();
      if (context.mounted) context.push('/route/builder');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pack.routesTitle),
        actions: [
          TextButton.icon(onPressed: newRoute, icon: const Icon(Icons.add), label: const Text('New')),
          const ProfileButton(),
        ],
      ),
      body: AsyncView(
        value: routes,
        onRetry: () => ref.invalidate(routesProvider),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.alt_route,
                title: 'No ${pack.routeNoun}s yet',
                body: pack.emptyRoutesCopy,
                action: OutlinedButton(onPressed: () => context.go('/map'), child: const Text('Open the map')),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(routesProvider),
                child: Builder(
                  builder: (context) {
                    final sorted = [...list]..sort(_byNextAction);
                    return ListView.separated(
                      padding: const EdgeInsets.all(Sp.s4),
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
                      itemBuilder: (_, i) => _RouteCard(route: sorted[i]),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// In-progress runs first (resuming is the likeliest action), then unstarted,
/// then finished; most recently run first within each.
int _byNextAction(RouteModel a, RouteModel b) {
  int rank(RouteModel r) => r.status == RouteStatus.inProgress && !r.allVisited
      ? 0
      : (r.allVisited || r.status == RouteStatus.complete ? 2 : 1);
  final c = rank(a).compareTo(rank(b));
  if (c != 0) return c;
  return (b.lastRunAt ?? b.createdAt).compareTo(a.lastRunAt ?? a.createdAt);
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.route});
  final RouteModel route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final n = ref.read(routesProvider.notifier);
    final anon = ref.watch(isAnonymousProvider);
    final pack = ref.watch(modePackProvider);
    final done = route.allVisited || route.status == RouteStatus.complete;
    final inProgress = route.status == RouteStatus.inProgress && !done;

    return Slidable(
      key: ValueKey(route.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final name = await promptText(context, title: 'Rename route', initial: route.name);
              if (name != null && name.isNotEmpty) n.rename(route.id, name);
            },
            backgroundColor: c.surfaceHighest,
            foregroundColor: c.onSurface,
            icon: Icons.edit_outlined,
          ),
          SlidableAction(
            onPressed: (_) async {
              if (await confirm(
                context,
                title: 'Delete "${route.name}"?',
                body: 'Visits logged on this route are deleted too.',
                confirmLabel: 'Delete',
                destructive: true,
              )) {
                n.delete(route.id);
              }
            },
            backgroundColor: c.error,
            foregroundColor: c.onError,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: KnCard(
        accent: inProgress ? c.tertiary : null,
        onTap: () => context.push(done ? '/route/${route.id}/summary' : '/route/${route.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(Rad.lg)),
              child: RouteSketch(
                scale: 0.45,
                points: [for (final s in route.stops) (lat: s.lat, lng: s.lng)],
                stops: [for (final s in route.stops) s.visited ? SketchStop.win : SketchStop.pending],
                line: c.primary,
                win: c.tertiary,
                visited: c.onSurface,
                pending: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Sp.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(route.name, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          switch (v) {
                            case 'edit':
                              ref.read(mapProvider.notifier).editRoute(route);
                              context.push('/route/builder');
                            case 'dup':
                              await n.duplicate(route.id);
                            case 'share':
                              if (anon) {
                                context.push('/signin?reason=share');
                                return;
                              }
                              final link = await ref.read(shareRepoProvider).createLink(route.id);
                              await ref
                                  .read(shareServiceProvider)
                                  .shareText('${route.name} — $link', subject: route.name);
                            case 'summary':
                              context.push('/route/${route.id}/summary');
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit stops')),
                          PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                          PopupMenuItem(value: 'share', child: Text('Share link')),
                          PopupMenuItem(value: 'summary', child: Text('Summary & export')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.s1),
                  Text(
                    [
                      inProgress ? '${route.visitedCount} of ${route.stopCount} stops' : '${route.stopCount} stops',
                      route.lastRunAt == null ? 'Never run' : 'Last run ${DateFormat.MMMd().format(route.lastRunAt!)}',
                      if (route.isOptimized) 'Optimized',
                    ].join(' · '),
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                  if (inProgress) ...[
                    const SizedBox(height: Sp.s3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Rad.full),
                      child: LinearProgressIndicator(
                        value: route.stopCount == 0 ? 0 : route.visitedCount / route.stopCount,
                        backgroundColor: c.surfaceLow,
                        color: c.tertiary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                  const SizedBox(height: Sp.s3),
                  if (inProgress)
                    KnButton(
                      label: 'Resume · stop ${route.visitedCount + 1}',
                      icon: Icons.play_arrow_rounded,
                      lime: true,
                      compact: true,
                      onPressed: () => context.push('/route/${route.id}'),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: done ? () => _runAgain(context, ref) : () => context.push('/route/${route.id}'),
                      icon: Icon(done ? Icons.replay : Icons.navigation_outlined, size: 18),
                      label: Text(done ? 'Run again' : 'Start ${pack.routeNoun}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A finished route keeps its history: running it again runs a copy.
  Future<void> _runAgain(BuildContext context, WidgetRef ref) async {
    final pack = ref.read(modePackProvider);
    final saved = ref.read(routesProvider).value?.length ?? 0;
    if (pack.atRouteLimit(saved, paying: ref.read(isPayingProvider))) {
      await showPaywall(context, pack, reason: freeLimitReason(pack));
      return;
    }
    final copy = await ref.read(routesProvider.notifier).duplicate(route.id);
    if (context.mounted) context.push('/route/${copy.id}');
  }
}
