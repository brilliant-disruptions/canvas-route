import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/app_mode.dart';
import '../../modes/registry.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Screen 0 picks a mode; screens 1–3 are the mode's own copy (spec §2.2).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  AppMode? _mode;
  int _index = 0;

  Future<void> _finish() async {
    await ref.read(profileProvider.notifier).setMode(_mode ?? AppMode.fieldSales);
    await ref.read(profileProvider.notifier).markOnboarded();
    if (mounted) context.go('/onboarding/profile');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pages = _mode == null ? const [] : packFor(_mode!).onboarding;
    final total = 1 + pages.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _index == 0
                  ? const SizedBox(height: 48)
                  : TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: _mode == null ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _ModeSelect(
                    selected: _mode,
                    onSelect: (m) {
                      setState(() => _mode = m);
                      _page.animateToPage(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                    },
                  ),
                  for (final p in pages)
                    Padding(
                      padding: const EdgeInsets.all(Sp.s8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Rad.xxl)),
                            child: Icon(p.icon, size: 48, color: c.tertiary),
                          ),
                          const SizedBox(height: Sp.s8),
                          Text(p.headline, style: t.displaySmall),
                          const SizedBox(height: Sp.s4),
                          Text(p.subtext, style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.s6, 0, Sp.s6, Sp.s6),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < total; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index ? c.tertiary : c.outline,
                            borderRadius: BorderRadius.circular(Rad.full),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Sp.s5),
                  if (_index > 0)
                    KnButton(
                      label: _index == total - 1 ? 'Get Started' : 'Next',
                      lime: _index == total - 1,
                      onPressed: () => _index == total - 1
                          ? _finish()
                          : _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelect extends StatelessWidget {
  const _ModeSelect({required this.selected, required this.onSelect});
  final AppMode? selected;
  final ValueChanged<AppMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Sp.s6),
          Text('What are you\nhere to do?', style: t.displayMedium),
          const SizedBox(height: Sp.s2),
          Text('You can switch any time.', style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s8),
          for (final m in AppMode.values) ...[
            KnCard(
              tier: selected == m ? 3 : 1,
              onTap: () => onSelect(m),
              child: Row(
                children: [
                  Icon(packFor(m).icon, color: c.tertiary, size: 28),
                  const SizedBox(width: Sp.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(packFor(m).label, style: t.titleLarge),
                        Text(packFor(m).tagline, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: Sp.s3),
          ],
        ],
      ),
    );
  }
}
