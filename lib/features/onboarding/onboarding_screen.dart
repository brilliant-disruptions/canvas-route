import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/app_mode.dart';
import '../../modes/mode_pack.dart';
import '../../modes/registry.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// One screen in: pick a mode, see what it does, land on the map (spec §2.2).
/// Profile details are optional and live in the drawer, not in the way.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  AppMode? _mode;
  bool _starting = false;

  Future<void> _start() async {
    final mode = _mode;
    if (mode == null) return;
    setState(() => _starting = true);
    await ref.read(profileProvider.notifier).setMode(mode);
    await ref.read(profileProvider.notifier).markOnboarded();
    if (mounted) context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = _mode == null ? null : packFor(_mode!);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Sp.s6, Sp.s8, Sp.s6, Sp.s6),
                children: [
                  Text('What are you\nhere to do?', style: t.displayMedium),
                  const SizedBox(height: Sp.s2),
                  Text('No sign-up. Switch any time.', style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(height: Sp.s8),
                  for (final m in AppMode.values) ...[
                    _ModeCard(pack: packFor(m), selected: _mode == m, onTap: () => setState(() => _mode = m)),
                    const SizedBox(height: Sp.s3),
                  ],
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: pack == null
                  ? const SizedBox(height: Sp.s4)
                  : Padding(
                      key: ValueKey(pack.id),
                      padding: const EdgeInsets.fromLTRB(Sp.s6, Sp.s2, Sp.s6, Sp.s6),
                      child: KnButton(
                        label: 'Start with ${pack.label}',
                        icon: Icons.arrow_forward,
                        lime: true,
                        loading: _starting,
                        onPressed: _start,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsed: icon, name, tagline. Selected: expands to the mode's value props.
class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.pack, required this.selected, required this.onTap});
  final ModePack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        border: Border.all(color: selected ? c.tertiary : Colors.transparent, width: 1.5),
      ),
      child: KnCard(
        tier: selected ? 3 : 1,
        onTap: onTap,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(pack.icon, color: c.tertiary, size: 28),
                  const SizedBox(width: Sp.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pack.label, style: t.titleLarge),
                        Text(pack.tagline, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? c.tertiary : c.onSurfaceVariant,
                  ),
                ],
              ),
              if (selected)
                for (final p in pack.onboarding) ...[
                  const SizedBox(height: Sp.s4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Rad.lg)),
                        child: Icon(p.icon, size: 20, color: c.tertiary),
                      ),
                      const SizedBox(width: Sp.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.headline, style: t.titleMedium),
                            Text(p.subtext, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
