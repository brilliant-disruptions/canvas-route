import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/kn_colors.dart';
import '../core/theme/kn_theme.dart';
import '../modes/mode_pack.dart';
import '../modes/registry.dart';
import '../state/auth_state.dart';
import '../state/follow_ups_state.dart';
import '../state/profile_state.dart';
import '../ui/widgets/kn_widgets.dart';

/// Bottom tabs + the profile drawer reachable from every tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final index = loc.startsWith('/routes') ? 1 : 0;
    final pack = ref.watch(modePackProvider);
    return Scaffold(
      endDrawer: const ProfileDrawer(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(i == 0 ? '/map' : '/routes'),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(
            icon: const Icon(Icons.alt_route_outlined),
            selectedIcon: const Icon(Icons.alt_route),
            label: pack.routesTab,
          ),
        ],
      ),
    );
  }
}

class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;
    final pack = ref.watch(modePackProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final anon = ref.watch(isAnonymousProvider);
    final paying = ref.watch(isPayingProvider);
    final active = ref.watch(activeModeProvider);
    final dueFollowUps = pack.followUpsLabel == null ? 0 : ref.watch(followUpsDueProvider);

    void go(String path) {
      Navigator.of(context).pop();
      context.push(path);
    }

    return Drawer(
      backgroundColor: c.surfaceLow,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Sp.s4),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.s5, Sp.s3, Sp.s5, Sp.s4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: c.primaryContainer,
                    child: Text(
                      (profile?.name ?? profile?.handle ?? 'C').characters.first.toUpperCase(),
                      style: t.titleLarge?.copyWith(color: c.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: Sp.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? (anon ? 'Guest' : 'CanvasRoute'),
                          style: t.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          anon ? 'Sign in to share and report' : (profile?.email ?? ''),
                          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (pack.proProductId != null)
                    KnBadge(
                      paying ? 'PRO' : 'FREE',
                      color: paying ? c.tertiary : c.surfaceHighest,
                      onColor: paying ? c.onTertiary : c.onSurfaceVariant,
                    ),
                ],
              ),
            ),
            // Modes inline: switching is one tap, and the other verticals stay visible.
            if (launchModes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s3),
                child: Row(
                  children: [
                    for (final m in launchModes) ...[
                      if (m != launchModes.first) const SizedBox(width: Sp.s2),
                      Expanded(
                        child: _ModeTile(
                          pack: packFor(m),
                          active: m == active,
                          onTap: () async {
                            Navigator.of(context).pop();
                            if (m != active) await ref.read(profileProvider.notifier).setMode(m);
                            if (context.mounted) context.go('/map');
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (!paying && pack.proProductId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s3),
                child: KnCard(
                  tier: 3,
                  accent: c.tertiary,
                  onTap: () => go('/settings/account'),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pack.proPitch, style: t.titleMedium),
                            Text(
                              '${pack.proLabel} · ${pack.proPrice}',
                              style: t.bodySmall?.copyWith(color: c.tertiary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            const Divider(),
            if (anon)
              ListTile(leading: const Icon(Icons.login), title: const Text('Sign in'), onTap: () => go('/signin')),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => go('/settings/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Account'),
              onTap: () => go('/settings/account'),
            ),
            ListTile(leading: const Icon(Icons.tune), title: const Text('Preferences'), onTap: () => go('/settings')),
            if (pack.followUpsLabel != null)
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: Text(pack.followUpsLabel!),
                trailing: dueFollowUps == 0
                    ? null
                    : KnBadge('$dueFollowUps due', color: c.tertiary, onColor: c.onTertiary),
                onTap: () => go('/follow-ups'),
              ),
            if (pack.mileageLog)
              ListTile(leading: const Icon(Icons.speed), title: const Text('Mileage'), onTap: () => go('/mileage')),
            if (pack.alerts.isNotEmpty && pack.hasCommunity)
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(pack.productCatalog ? 'Watchlist' : 'Alerts'),
                onTap: () => go('/alerts'),
              ),
            if (pack.supportsHosting)
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('My sales'),
                onTap: () => go('/host'),
              ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Feature requests'),
              onTap: () => go('/feature-requests'),
            ),
            if (isAdmin)
              ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined, color: c.error),
                title: const Text('Admin'),
                onTap: () => go('/admin'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.pack, required this.active, required this.onTap});
  final ModePack pack;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: active,
      button: true,
      label: '${pack.label} mode',
      child: Material(
        color: active ? c.tertiaryContainer : c.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.lg),
          side: BorderSide(color: active ? c.tertiary : c.ghostBorder, width: active ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.s3, horizontal: Sp.s1),
            child: Column(
              children: [
                Icon(pack.icon, color: active ? c.tertiary : c.onSurfaceVariant),
                const SizedBox(height: Sp.s1),
                Text(
                  pack.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: t.labelMedium?.copyWith(
                    color: active ? c.onTertiaryContainer : c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top-right header button that opens the profile drawer.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});
  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openEndDrawer());
}
