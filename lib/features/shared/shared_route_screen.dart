import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/app_mode.dart';
import '../../data/models/draft_stop.dart';
import '../../data/models/stop.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Opened from a share link. Read-only view with "Add to my routes" (fork).
class SharedRouteScreen extends ConsumerWidget {
  const SharedRouteScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return KnScaffold(
      title: 'Shared route',
      body: FutureBuilder(
        future: ref.read(shareRepoProvider).fetch(token),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          final r = snap.data;
          if (r == null) return const EmptyState(icon: Icons.link_off, title: 'This link has expired');
          return ListView(
            padding: const EdgeInsets.all(Sp.s4),
            children: [
              Text(r.name, style: t.headlineLarge),
              Text('${r.stops.length} stops${r.ownerHandle == null ? '' : ' · shared by @${r.ownerHandle}'}', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(height: Sp.s4),
              for (var i = 0; i < r.stops.length; i++)
                ListTile(contentPadding: EdgeInsets.zero, leading: NumberDot(i + 1), title: Text(r.stops[i].name), subtitle: Text(r.stops[i].address)),
              const SizedBox(height: Sp.s6),
              if (r.canFork)
                KnButton(
                  label: 'Add to my routes',
                  lime: true,
                  onPressed: () async {
                    final mode = AppMode.fromId(r.mode);
                    if (ref.read(activeModeProvider) != mode) await ref.read(profileProvider.notifier).setMode(mode);
                    final route = await ref.read(routesProvider.notifier).save(
                          r.name,
                          [for (final s in r.stops) DraftStop(id: s.id, business: s.toBusiness())],
                        );
                    if (context.mounted) context.go('/route/${route.id}');
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
