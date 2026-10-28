import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/kn_colors.dart';
import '../core/theme/kn_theme.dart';
import '../features/tour/tour.dart';
import '../modes/mode_pack.dart';
import '../state/auth_state.dart';
import '../state/profile_state.dart';
import '../state/providers.dart';
import '../state/tour_state.dart';

/// Bottom tabs + the profile drawer reachable from every tab. Also where the
/// first-run tour starts, and where Preferences asks to replay it.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _touring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final firstTime = ref.read(localPrefsProvider).hasOnboarded && !ref.read(touredProvider);
      if (firstTime || ref.read(tourRequestProvider)) _tour();
    });
  }

  Future<void> _tour() async {
    if (_touring) return;
    _touring = true;
    try {
      await startTour(context, ref);
    } finally {
      _touring = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tourRequestProvider, (_, asked) {
      if (asked) _tour();
    });
    final loc = GoRouterState.of(context).matchedLocation;
    final index = loc.startsWith('/routes') ? 1 : 0;
    final pack = ref.watch(modePackProvider);
    return Scaffold(
      endDrawer: const ProfileDrawer(),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(i == 0 ? '/map' : '/routes'),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(
            key: TourKeys.routesTab,
            icon: const Icon(Icons.alt_route_outlined),
            selectedIcon: const Icon(Icons.alt_route),
            label: pack.id.name == 'cardDrops' ? 'Runs' : 'Routes',
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
                    child: Text((profile?.name ?? profile?.handle ?? 'C').characters.first.toUpperCase(),
                        style: t.titleLarge?.copyWith(color: c.onPrimaryContainer)),
                  ),
                  const SizedBox(width: Sp.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile?.name ?? (anon ? 'Guest' : 'CanvasRoute'), style: t.titleLarge),
                        Text(anon ? 'Sign in to share and report' : (profile?.email ?? ''),
                            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(pack.icon, color: c.tertiary),
              title: Text(pack.label),
              subtitle: const Text('Switch mode'),
              onTap: () => go('/mode'),
            ),
            const Divider(),
            if (anon)
              ListTile(leading: const Icon(Icons.login), title: const Text('Sign in'), onTap: () => go('/signin')),
            ListTile(leading: const Icon(Icons.person_outline), title: const Text('Profile'), onTap: () => go('/settings/profile')),
            ListTile(leading: const Icon(Icons.credit_card), title: const Text('Account'), onTap: () => go('/settings/account')),
            ListTile(leading: const Icon(Icons.tune), title: const Text('Preferences'), onTap: () => go('/settings')),
            if (pack.alerts.isNotEmpty && pack.hasCommunity)
              ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Alerts'), onTap: () => go('/alerts')),
            if (pack.supportsHosting)
              ListTile(leading: const Icon(Icons.sell_outlined), title: const Text('My sales'), onTap: () => go('/host')),
            ListTile(leading: const Icon(Icons.lightbulb_outline), title: const Text('Feature requests'), onTap: () => go('/feature-requests')),
            if (isAdmin)
              ListTile(leading: Icon(Icons.admin_panel_settings_outlined, color: c.error), title: const Text('Admin'), onTap: () => go('/admin')),
          ],
        ),
      ),
    );
  }
}

/// Top-right header button that opens the profile drawer.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openEndDrawer(),
      );
}

extension PackLabels on ModePack {
  String get routesTitle => id.name == 'cardDrops' ? 'Card runs' : 'Saved routes';
}
