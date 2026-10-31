import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logic/restock.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/pin_sheet.dart';
import '../settings/paywall_sheet.dart';

/// Followed products, radius, quiet hours, and alert history. Free tier follows
/// one product; Drop Alerts Pro lifts the cap (spec §8).
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final profile = ref.watch(profileProvider).value;
    final follows = ref.watch(followsProvider).value ?? {};
    final products = ref.watch(productsProvider).value ?? const [];
    final alerts = ref.watch(alertsProvider);
    final paying = ref.watch(isPayingProvider);
    final anon = ref.watch(isAnonymousProvider);

    return KnScaffold(
      title: 'Alerts',
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          if (anon)
            KnCard(tier: 3, child: Row(children: [
              Icon(Icons.login, color: c.tertiary),
              const SizedBox(width: Sp.s3),
              const Expanded(child: Text('Sign in to get alerts on your phone.')),
              TextButton(onPressed: () => context.push('/signin'), child: const Text('Sign in')),
            ])),
          if (pack.productCatalog) ...[
            SectionHeader('Followed products', subtitle: paying ? 'Unlimited' : 'Free: 1 product · ${pack.proLabel} for unlimited'),
            Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
              for (final p in products.where((p) => follows.contains(p.id)))
                InputChip(label: Text(p.displayName), onDeleted: () => ref.read(followsProvider.notifier).toggle(p.id)),
              ActionChip(
                avatar: Icon(Icons.add, size: 16, color: c.tertiary),
                label: const Text('Follow a product'),
                onPressed: () async {
                  if (!paying && follows.isNotEmpty) {
                    await showPaywall(context, pack, reason: 'Free follows 1 product. Follow every set you collect.');
                    return;
                  }
                  final id = await showKnSheet<String>(
                    context,
                    builder: (_) => _ProductList(products: products.where((p) => !follows.contains(p.id)).toList()),
                  );
                  if (id != null) ref.read(followsProvider.notifier).toggle(id);
                },
              ),
            ]),
          ],
          if (profile != null) ...[
            const SectionHeader('Radius'),
            Slider(
              value: profile.alertRadiusMi.toDouble(),
              min: 1,
              max: paying ? 50 : 5,
              divisions: paying ? 49 : 4,
              label: '${profile.alertRadiusMi} mi',
              onChanged: (_) {},
              onChangeEnd: (v) => ref.read(profileProvider.notifier).patch({'alert_radius_mi': v.round()}),
            ),
            Text('${profile.alertRadiusMi} mi from your home point${paying ? '' : ' · up to 50 mi with ${pack.proLabel}'}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            const SectionHeader('Quiet hours'),
            Row(children: [
              Expanded(child: _HourPicker(label: 'From', value: profile.quietHoursStart, onChanged: (v) => ref.read(profileProvider.notifier).patch({'quiet_hours_start': v}))),
              const SizedBox(width: Sp.s2),
              Expanded(child: _HourPicker(label: 'Until', value: profile.quietHoursEnd, onChanged: (v) => ref.read(profileProvider.notifier).patch({'quiet_hours_end': v}))),
            ]),
          ],
          const SectionHeader('History'),
          ...alerts.when(
            loading: () => const [LinearProgressIndicator()],
            error: (e, _) => [Text('$e')],
            data: (list) => list.isEmpty
                ? [Text('No alerts yet. They arrive the minute someone nearby reports a followed product in stock.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))]
                : [
                    for (final a in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(a.kind == 'stock_report_nearby' ? Icons.inventory_2_outlined : Icons.yard_outlined, color: a.openedAt == null ? c.tertiary : c.onSurfaceDisabled),
                        title: Text(a.title),
                        subtitle: Text('${a.body} · ${relativeAge(a.sentAt)}'),
                        onTap: a.pinId == null
                            ? null
                            : () async {
                                await ref.read(alertRepoProvider).markOpened(a.id);
                                final pin = await ref.read(pinRepoProvider).byId(a.pinId!);
                                if (pin != null && context.mounted) showPinSheet(context, pin);
                              },
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ProductList extends StatefulWidget {
  const _ProductList({required this.products});
  final List products;
  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.products.where((p) => p.displayName.toLowerCase().contains(_q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s2), child: TextField(autofocus: true, decoration: const InputDecoration(hintText: 'Search products'), onChanged: (v) => setState(() => _q = v))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) => ListTile(title: Text(list[i].displayName), onTap: () => Navigator.pop(context, list[i].id as String)))),
      ]),
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [const DropdownMenuItem(value: null, child: Text('Off')), for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(hourLabel(h)))],
        onChanged: onChanged,
      );
}
