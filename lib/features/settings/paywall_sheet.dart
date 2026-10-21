import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Upgrade sheet. Store billing (RevenueCat) lands in Phase 4; until then this
/// explains the tier and routes to Account, where plans are set manually.
Future<void> showPaywall(BuildContext context, ModePack pack) => showKnSheet(
      context,
      builder: (ctx) {
        final c = ctx.kn;
        final t = Theme.of(ctx).textTheme;
        final perks = switch (pack.id.name) {
          'yardSales' => ['Unlimited saved routes', 'Haul export for taxes', 'Share routes with your crew'],
          'cardDrops' => ['Unlimited followed products', 'Alert radius up to 50 mi', 'Restock calendar'],
          _ => ['Unlimited routes', 'Custom fields and exports', 'Feature request submissions'],
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pack.proLabel, style: t.headlineMedium),
            const SizedBox(height: Sp.s2),
            Text('You\'ve reached the free limit for ${pack.label}.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Sp.s4),
            for (final p in perks)
              Padding(padding: const EdgeInsets.only(bottom: Sp.s2), child: Row(children: [Icon(Icons.check_circle, color: c.tertiary, size: 18), const SizedBox(width: Sp.s2), Text(p)])),
            const SizedBox(height: Sp.s4),
            KnButton(label: 'See plans', lime: true, onPressed: () {
              Navigator.pop(ctx);
              ctx.push('/settings/account');
            }),
          ]),
        );
      },
    );
