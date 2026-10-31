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
      if (pack.freeRouteLimit != null && !paying && count >= pack.freeRouteLimit!) {
        await showPaywall(context, pack);
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
                child: ListView.separated(
                  padding: const EdgeInsets.all(Sp.s4),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
                  itemBuilder: (_, i) => _RouteCard(route: list[i]),
                ),
              ),
      ),
    );
  }
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
    final inProgress = route.status == RouteStatus.inProgress;
    final (statusLabel, statusColor) = switch (route.status) {
      RouteStatus.inProgress => ('In progress', c.statusDevelopment),
      RouteStatus.complete => ('Complete', c.statusDone),
      RouteStatus.updated => ('Updated', c.statusTodo),
      RouteStatus.notStarted => ('Not started', c.statusBacklog),
    };

    return Slidable(
      key: ValueKey(route.id),
      endActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.5, children: [
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
            if (await confirm(context, title: 'Delete "${route.name}"?', body: 'Visits logged on this route are deleted too.', confirmLabel: 'Delete', destructive: true)) {
              n.delete(route.id);
            }
          },
          backgroundColor: c.error,
          foregroundColor: c.onError,
          icon: Icons.delete_outline,
        ),
      ]),
      child: KnCard(
        accent: inProgress ? c.tertiary : null,
        onTap: () => context.push('/route/${route.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(route.name, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
              KnBadge(statusLabel, color: statusColor, onColor: c.surface),
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
                      await ref.read(shareServiceProvider).shareText('${route.name} — $link', subject: route.name);
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
            ]),
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
          ],
        ),
      ),
    );
  }
}
