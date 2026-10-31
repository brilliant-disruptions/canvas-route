import 'package:flutter/material.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../ui/widgets/kn_widgets.dart';

/// "New to CanvasRoute?" card for people arriving from a link or a sign.
class NewcomerPitch extends StatelessWidget {
  const NewcomerPitch({super.key, required this.pack});
  final ModePack pack;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return KnCard(
      tier: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New to CanvasRoute?', style: t.titleMedium),
          Text(pack.tagline, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          for (final p in pack.onboarding) ...[
            const SizedBox(height: Sp.s3),
            Row(
              children: [
                Icon(p.icon, size: 20, color: c.tertiary),
                const SizedBox(width: Sp.s3),
                Expanded(child: Text(p.headline, style: t.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
