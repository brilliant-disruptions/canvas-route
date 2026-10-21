import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/settings.dart';
import '../../state/appearance_state.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final pack = ref.watch(modePackProvider);
    final profile = ref.watch(profileProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final theme = ref.watch(appearanceProvider);
    final anon = ref.watch(isAnonymousProvider);

    return KnScaffold(
      title: 'Preferences',
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('Profile'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/settings/profile')),
          ListTile(leading: const Icon(Icons.credit_card), title: const Text('Account & plan'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/settings/account')),
          ListTile(leading: const Icon(Icons.tune), title: Text('Outcomes, fields & export · ${pack.label}'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/settings/advanced')),
          const SectionHeader('Appearance'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.phone_iphone)),
            ],
            selected: {theme},
            onSelectionChanged: (s) => ref.read(appearanceProvider.notifier).set(s.first.name),
          ),
          const SectionHeader('Map region'),
          OutlinedButton.icon(
            onPressed: () async {
              final loc = await ref.read(locationServiceProvider).current();
              if (loc == null) {
                if (context.mounted) toast(context, 'Location unavailable');
                return;
              }
              await ref.read(profileProvider.notifier).patch({'home_lat': loc.lat, 'home_lng': loc.lng});
              if (context.mounted) toast(context, 'Home territory set', icon: Icons.home_outlined);
            },
            icon: const Icon(Icons.home_outlined),
            label: Text(profile?.homeLat == null ? 'Set current location as home territory' : 'Update home territory'),
          ),
          if (settings != null) ...[
            const SectionHeader('Route end'),
            DropdownButtonFormField<RouteEndPreference>(
              initialValue: settings.routeEndPreference,
              items: const [
                DropdownMenuItem(value: RouteEndPreference.currentLocation, child: Text('Back to where I started')),
                DropdownMenuItem(value: RouteEndPreference.office, child: Text('Office address')),
                DropdownMenuItem(value: RouteEndPreference.custom, child: Text('Custom address')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                var next = settings.copyWith(routeEndPreference: v);
                if (v == RouteEndPreference.custom) {
                  final addr = await promptText(context, title: 'End address', initial: settings.customEndAddress);
                  if (addr == null || addr.isEmpty) return;
                  final geo = await ref.read(placesServiceProvider).geocode(addr);
                  if (geo == null) {
                    if (context.mounted) toast(context, 'Couldn\'t find that address');
                    return;
                  }
                  next = next.copyWith(customEndAddress: geo.formatted, customEndLat: geo.lat, customEndLng: geo.lng);
                }
                await ref.read(settingsProvider.notifier).save(next);
              },
            ),
          ],
          if (pack.hasCommunity && profile != null) ...[
            const SectionHeader('Community'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-share my visits as reports'),
              subtitle: const Text('What you see on the shelf helps everyone nearby. Never includes your location.'),
              value: profile.autoShareReports,
              onChanged: (v) => ref.read(profileProvider.notifier).patch({'auto_share_reports': v}),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alert radius'),
              subtitle: Slider(
                value: profile.alertRadiusMi.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                label: '${profile.alertRadiusMi} mi',
                onChangeEnd: (v) => ref.read(profileProvider.notifier).patch({'alert_radius_mi': v.round()}),
                onChanged: (_) {},
              ),
              trailing: Text('${profile.alertRadiusMi} mi'),
            ),
          ],
          const SizedBox(height: Sp.s8),
          if (!anon)
            TextButton(
              onPressed: () async {
                if (await confirm(context, title: 'Sign out?', body: 'Your routes stay in your account.', confirmLabel: 'Sign out')) {
                  await ref.read(authRepoProvider).signOut();
                  await ref.read(authRepoProvider).ensureSession();
                  if (context.mounted) context.go('/map');
                }
              },
              style: TextButton.styleFrom(foregroundColor: c.error),
              child: const Text('Sign out'),
            ),
        ],
      ),
    );
  }
}
