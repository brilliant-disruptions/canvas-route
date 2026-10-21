import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/app_mode.dart';
import '../../modes/registry.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

class ModePickerScreen extends ConsumerWidget {
  const ModePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final current = ref.watch(activeModeProvider);
    return KnScaffold(
      title: 'Switch mode',
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          Text('Routes and settings are kept per mode. Switching is instant.',
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s4),
          for (final m in AppMode.values) ...[
            KnCard(
              tier: current == m ? 3 : 1,
              onTap: () async {
                await ref.read(profileProvider.notifier).setMode(m);
                if (context.mounted) context.go('/map');
              },
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
                  if (current == m) Icon(Icons.check_circle, color: c.tertiary),
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
