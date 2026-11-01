import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Upgrade sheet, shown at the moment a free limit blocks something the user
/// just asked for. [reason] says what. Store billing (RevenueCat) lands in
/// Phase 4; until then the CTA routes to Account.
Future<void> showPaywall(BuildContext context, ModePack pack, {required String reason}) => showKnSheet(
      context,
      builder: (ctx) {
        final c = ctx.kn;
        final t = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.tertiary, borderRadius: BorderRadius.circular(Rad.lg)),
                child: Icon(Icons.workspace_premium_outlined, color: c.onTertiary),
              ),
              const SizedBox(width: Sp.s3),
              Text(pack.pro.label.toUpperCase(),
                  style: t.labelMedium?.copyWith(color: c.tertiary, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ]),
            const SizedBox(height: Sp.s4),
            Text(pack.pro.pitch, style: t.displaySmall),
            const SizedBox(height: Sp.s2),
            Text(reason, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Sp.s5),
            for (final p in pack.pro.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s3),
                child: Row(children: [
                  Icon(p.icon, color: c.tertiary, size: 22),
                  const SizedBox(width: Sp.s3),
                  Expanded(child: Text(p.label, style: t.titleMedium)),
                ]),
              ),
            const SizedBox(height: Sp.s3),
            KnCard(
              tier: 3,
              padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3),
              child: Row(children: [
                Expanded(child: Text(pack.pro.label, style: t.titleLarge)),
                Text(pack.pro.price, style: t.titleLarge?.copyWith(color: c.tertiary)),
              ]),
            ),
            const SizedBox(height: Sp.s1),
            Center(child: Text('Cancel anytime.', style: t.labelSmall?.copyWith(color: c.onSurfaceVariant))),
            const SizedBox(height: Sp.s4),
            KnButton(
              label: 'Upgrade · ${pack.pro.price}',
              lime: true,
              onPressed: () {
                Navigator.pop(ctx);
                ctx.push('/settings/account');
              },
            ),
            const SizedBox(height: Sp.s1),
            Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now'))),
          ]),
        );
      },
    );

/// "Free saves 1 run. This would be your 2nd."
/// True when the user has the active vertical's paid tier; otherwise shows the
/// paywall with [reason] and returns false. Use at the tap, not to hide the button.
Future<bool> requirePro(BuildContext context, WidgetRef ref, String reason) async {
  if (ref.read(hasProAccessProvider)) return true;
  await showPaywall(context, ref.read(modePackProvider), reason: reason);
  return false;
}

String freeLimitReason(ModePack pack) {
  final n = pack.pro.freeRouteLimit ?? 0;
  final noun = pack.routeNoun;
  return 'Free saves $n $noun${n == 1 ? '' : 's'}. This would be your ${_ordinal(n + 1)}.';
}

String _ordinal(int n) => '$n${n % 100 >= 11 && n % 100 <= 13 ? 'th' : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';
