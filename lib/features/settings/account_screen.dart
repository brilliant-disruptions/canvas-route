import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final p = ref.watch(profileProvider).value;
    final pack = ref.watch(modePackProvider);
    final anon = ref.watch(isAnonymousProvider);
    final paying = ref.watch(isPayingProvider);
    if (p == null) return const Scaffold(body: LoadingView());
    return KnScaffold(
      title: 'Account',
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          KnCard(
            tier: 3,
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Paid tiers are per vertical: show the one for the mode you're in.
                Text('${pack.label} plan', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
                Text((paying ? pack.proLabel : 'Free').toUpperCase(), style: t.headlineMedium?.copyWith(color: c.tertiary)),
                if (p.billingDate != null) Text('Next billing ${DateFormat.yMMMd().format(p.billingDate!)}', style: t.bodySmall),
              ])),
              Icon(Icons.workspace_premium_outlined, color: c.tertiary, size: 36),
            ]),
          ),
          const SectionHeader('Plans'),
          _PlanRow(name: 'Free', price: '\$0', perks: 'Map, routes${pack.freeRouteLimit != null ? ' (${pack.freeRouteLimit} saved)' : ''}, visit logging, reporting'),
          _PlanRow(name: pack.proLabel, price: pack.proPrice, perks: ['Everything in Free', ...pack.proPerks.map((p) => p.label)].join(' · '), highlight: true),
          const SizedBox(height: Sp.s4),
          if (!paying) KnButton(label: 'Upgrade to ${pack.proLabel}', lime: true, onPressed: () => toast(context, 'Store billing arrives in the next release. Email us for early access.')),
          if (anon) ...[
            const SectionHeader('Sign in'),
            Text('You\'re using CanvasRoute as a guest. Sign in to keep your routes across devices and to share or report.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Sp.s3),
            OutlinedButton(onPressed: () => context.push('/signin'), child: const Text('Sign in or create account')),
          ],
          const SizedBox(height: Sp.s10),
          TextButton(
            onPressed: () async {
              if (await confirm(context, title: 'Deactivate account?', body: 'Your profile is cleared and you are signed out. Routes are deleted after 30 days.', confirmLabel: 'Deactivate', destructive: true)) {
                await ref.read(profileRepoProvider).deactivate(p.id);
                await ref.read(authRepoProvider).signOut();
                await ref.read(authRepoProvider).ensureSession();
                if (context.mounted) context.go('/map');
              }
            },
            style: TextButton.styleFrom(foregroundColor: c.error),
            child: const Text('Deactivate account'),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.name, required this.price, required this.perks, this.highlight = false});
  final String name;
  final String price;
  final String perks;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s3),
      child: KnCard(
        tier: highlight ? 3 : 1,
        accent: highlight ? c.tertiary : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name, style: t.titleLarge)), Text(price, style: t.titleMedium?.copyWith(color: c.tertiary))]),
          const SizedBox(height: Sp.s1),
          Text(perks, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
