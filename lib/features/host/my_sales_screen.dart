import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../state/community_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import 'host_sale_screen.dart';

class MySalesScreen extends ConsumerWidget {
  const MySalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pins = ref.watch(myPinsProvider);
    return KnScaffold(
      title: 'My sales',
      actions: [TextButton.icon(onPressed: () => context.push('/host/new'), icon: const Icon(Icons.add), label: const Text('Post'))],
      body: AsyncView(
        value: pins,
        onRetry: () => ref.invalidate(myPinsProvider),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.sell_outlined, title: 'No sales posted', body: 'Post once, get a link and a QR for your sign.', action: KnButton(label: 'Post a sale', lime: true, onPressed: () => context.push('/host/new')))
            : ListView.separated(
                padding: const EdgeInsets.all(Sp.s4),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return KnCard(
                    accent: p.isLive ? c.tertiary : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(p.name, style: t.titleLarge)),
                        KnBadge(p.status.name, color: p.isLive ? c.statusDone : c.statusBacklog, onColor: c.surface),
                      ]),
                      if (p.opensAt != null) Text('${DateFormat.yMMMEd().format(p.opensAt!)} · ${DateFormat.jm().format(p.opensAt!)}–${p.closesAt == null ? '' : DateFormat.jm().format(p.closesAt!)}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                      const SizedBox(height: Sp.s3),
                      Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
                        OutlinedButton.icon(onPressed: () => showShareSaleSheet(context, p), icon: const Icon(Icons.qr_code_2), label: const Text('Sign QR')),
                        if (p.isLive)
                          TextButton(
                            onPressed: () async {
                              if (await confirm(context, title: 'Mark as packed up?', body: 'The sale disappears from the map.', confirmLabel: 'Packed up')) {
                                await ref.read(pinRepoProvider).setStatus(p.id, PinStatus.ended);
                                ref.invalidate(myPinsProvider);
                              }
                            },
                            child: const Text('Packed up'),
                          ),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
