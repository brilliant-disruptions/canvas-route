import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/logic/errors.dart';
import '../../core/logic/restock.dart';
import '../../core/logic/watchlist.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/product.dart';
import '../../modes/mode_pack.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../community/pin_sheet.dart';
import '../settings/paywall_sheet.dart';

/// The watchlist: each followed product with where it's in stock near you right
/// now, one-tap follows for what's turning up nearby, then alert settings and
/// history. Free follows one product; Pro lifts the cap (spec §8).
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _follow(BuildContext context, WidgetRef ref, ModePack pack, String productId) async {
    final follows = ref.read(followsProvider).value ?? {};
    if (!ref.read(isPayingProvider) && follows.isNotEmpty) {
      await showPaywall(context, pack, reason: 'Free follows 1 product. Watch every set you collect.');
      return;
    }
    await ref.read(followsProvider.notifier).toggle(productId);
  }

  Future<void> _openStore(BuildContext context, WidgetRef ref, String pinId) async {
    final pin = await ref.read(pinRepoProvider).byId(pinId);
    if (pin != null && context.mounted) showPinSheet(context, pin);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final profile = ref.watch(profileProvider).value;
    final follows = ref.watch(followsProvider).value ?? {};
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final byId = {for (final p in products) p.id: p};
    final sightings = ref.watch(nearbySightingsProvider).value ?? const <Sighting>[];
    final alerts = ref.watch(alertsProvider);
    final paying = ref.watch(isPayingProvider);
    final anon = ref.watch(isAnonymousProvider);
    final statuses = watchStatuses(follows.where(byId.containsKey).toList(), sightings);
    final trending = trendingProducts(sightings, follows).where(byId.containsKey).toList();

    return KnScaffold(
      title: pack.productCatalog ? 'Watchlist' : 'Alerts',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestReportsProvider);
          await ref.read(nearbySightingsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(Sp.s4),
          children: [
            if (anon)
              KnCard(
                tier: 3,
                child: Row(
                  children: [
                    Icon(Icons.login, color: c.tertiary),
                    const SizedBox(width: Sp.s3),
                    const Expanded(child: Text('Sign in to get alerts on your phone.')),
                    TextButton(onPressed: () => context.push('/signin'), child: const Text('Sign in')),
                  ],
                ),
              ),
            if (pack.productCatalog) ...[
              SectionHeader(
                'Watching',
                subtitle: paying
                    ? 'Live from reports within ${profile?.alertRadiusMi ?? 10} mi'
                    : 'Free: 1 product · ${pack.proLabel} for unlimited',
              ),
              for (final w in statuses) ...[
                _WatchCard(
                  product: byId[w.productId]!,
                  status: w,
                  onOpen: w.live ? () => _openStore(context, ref, w.inStock.first.pinId) : null,
                  onUnfollow: () => ref.read(followsProvider.notifier).toggle(w.productId),
                ),
                const SizedBox(height: Sp.s2),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  final id = await showKnSheet<String>(
                    context,
                    builder: (_) => _ProductPicker(products: products.where((p) => !follows.contains(p.id)).toList()),
                  );
                  if (id != null && context.mounted) await _follow(context, ref, pack, id);
                },
                icon: const Icon(Icons.add),
                label: Text(statuses.isEmpty ? 'Watch a product' : 'Watch another'),
              ),
              if (trending.isNotEmpty) ...[
                const SectionHeader('In stock near you', subtitle: 'Reported in the last 24 hours'),
                Wrap(
                  spacing: Sp.s2,
                  runSpacing: Sp.s2,
                  children: [
                    for (final id in trending)
                      ActionChip(
                        avatar: Icon(Icons.add, size: 16, color: c.tertiary),
                        label: Text(byId[id]!.displayName),
                        onPressed: () => _follow(context, ref, pack, id),
                      ),
                  ],
                ),
              ],
            ],
            if (profile != null) ...[
              const SectionHeader('Alert settings'),
              _RadiusSlider(
                miles: profile.alertRadiusMi,
                max: paying ? 50 : 5,
                upsell: paying ? null : 'Up to 50 mi with ${pack.proLabel}',
                onChanged: (v) => ref.read(profileProvider.notifier).patch({'alert_radius_mi': v}),
              ),
              const SizedBox(height: Sp.s3),
              Row(
                children: [
                  Expanded(
                    child: _HourPicker(
                      label: 'Quiet from',
                      value: profile.quietHoursStart,
                      onChanged: (v) => ref.read(profileProvider.notifier).patch({'quiet_hours_start': v}),
                    ),
                  ),
                  const SizedBox(width: Sp.s2),
                  Expanded(
                    child: _HourPicker(
                      label: 'Until',
                      value: profile.quietHoursEnd,
                      onChanged: (v) => ref.read(profileProvider.notifier).patch({'quiet_hours_end': v}),
                    ),
                  ),
                ],
              ),
            ],
            const SectionHeader('History'),
            ...alerts.when(
              loading: () => const [LinearProgressIndicator()],
              error: (e, _) => [Text(friendlyError(e))],
              data: (list) => list.isEmpty
                  ? [
                      Text(
                        'No alerts yet. They arrive the minute someone nearby reports a product you watch.',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ]
                  : [
                      for (final a in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            a.kind == 'stock_report_nearby' ? Icons.inventory_2_outlined : Icons.yard_outlined,
                            color: a.openedAt == null ? c.tertiary : c.onSurfaceDisabled,
                          ),
                          title: Text(a.title),
                          subtitle: Text('${a.body} · ${relativeAge(a.sentAt)}'),
                          onTap: a.pinId == null
                              ? null
                              : () async {
                                  await ref.read(alertRepoProvider).markOpened(a.id);
                                  if (context.mounted) await _openStore(context, ref, a.pinId!);
                                },
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A followed product: lit with where it's in stock, or quiet with the last word on it.
class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.product, required this.status, required this.onUnfollow, this.onOpen});
  final Product product;
  final WatchStatus status;
  final VoidCallback onUnfollow;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final live = status.live;
    final (sku, set) = _split(product.displayName);
    final line = live
        ? 'In stock at ${whereLabel(status.inStock)} · ${relativeAge(status.inStock.first.at)}'
        : status.lastSeen != null
        ? 'Last report: ${status.lastSeen!.pinName}, ${relativeAge(status.lastSeen!.at)}'
        : 'No reports near you in 24h';
    return KnCard(
      tier: live ? 3 : 1,
      accent: live ? c.tertiary : null,
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s1, Sp.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.toUpperCase(),
                  style: t.labelSmall?.copyWith(
                    color: c.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(sku, style: t.titleLarge),
                const SizedBox(height: Sp.s1),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: live ? c.tertiary : c.outline, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Sp.s2),
                    Expanded(
                      child: Text(
                        line,
                        style: t.bodySmall?.copyWith(
                          color: live ? c.tertiary : c.onSurfaceVariant,
                          fontWeight: live ? FontWeight.w700 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Stop watching', icon: const Icon(Icons.close), onPressed: onUnfollow),
        ],
      ),
    );
  }

  /// "Prismatic Evolutions — Elite Trainer Box" → ("Elite Trainer Box", "Prismatic Evolutions").
  static (String, String) _split(String name) {
    final i = name.indexOf(' — ');
    return i < 0 ? (name, '') : (name.substring(i + 3), name.substring(0, i));
  }
}

/// Products grouped by set, newest set first, with search.
class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.products});
  final List<Product> products;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';

  static bool _upcoming(Product p) => p.releaseDate?.isAfter(DateTime.now()) ?? false;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final q = _q.toLowerCase();
    final sets = <String, List<Product>>{};
    for (final p in widget.products.where((p) => p.displayName.toLowerCase().contains(q))) {
      sets.putIfAbsent(p.setName, () => []).add(p);
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s2),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search sets or products', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s4),
              children: [
                // Upcoming sets first: release day is when a watch matters most.
                for (final e
                    in sets.entries.toList()..sort(
                      (a, b) => (_upcoming(b.value.first) ? 1 : 0).compareTo(_upcoming(a.value.first) ? 1 : 0),
                    )) ...[
                  const SizedBox(height: Sp.s3),
                  Row(
                    children: [
                      Expanded(child: Text(e.key, style: t.titleMedium)),
                      if (e.value.first.releaseDate != null)
                        Text(
                          e.value.first.releaseDate!.isAfter(DateTime.now())
                              ? 'Out ${DateFormat.MMMd().format(e.value.first.releaseDate!)}'
                              : DateFormat.yMMM().format(e.value.first.releaseDate!),
                          style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: Sp.s2),
                  Wrap(
                    spacing: Sp.s2,
                    runSpacing: Sp.s2,
                    children: [
                      for (final p in e.value)
                        ActionChip(
                          label: Text(_WatchCard._split(p.displayName).$1),
                          onPressed: () => Navigator.pop(context, p.id),
                        ),
                    ],
                  ),
                ],
                if (sets.isEmpty) const EmptyState(icon: Icons.search_off, title: 'No matching products'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Moves while dragging; saves on release.
class _RadiusSlider extends StatefulWidget {
  const _RadiusSlider({required this.miles, required this.max, required this.onChanged, this.upsell});
  final int miles;
  final int max;
  final String? upsell;
  final ValueChanged<int> onChanged;
  @override
  State<_RadiusSlider> createState() => _RadiusSliderState();
}

class _RadiusSliderState extends State<_RadiusSlider> {
  late double _v = widget.miles.clamp(1, widget.max).toDouble();

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Alert radius', style: t.titleMedium),
            const Spacer(),
            Text('${_v.round()} mi', style: t.titleMedium?.copyWith(color: c.tertiary)),
          ],
        ),
        Slider(
          value: _v,
          min: 1,
          max: widget.max.toDouble(),
          divisions: widget.max - 1,
          label: '${_v.round()} mi',
          onChanged: (v) => setState(() => _v = v),
          onChangeEnd: (v) => widget.onChanged(v.round()),
        ),
        if (widget.upsell != null) Text(widget.upsell!, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
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
    items: [
      const DropdownMenuItem(value: null, child: Text('Off')),
      for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(hourLabel(h))),
    ],
    onChanged: onChanged,
  );
}
