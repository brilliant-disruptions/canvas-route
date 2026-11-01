import 'package:flutter/material.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../ui/widgets/kn_widgets.dart';

/// "Neighbor says it's still going": tap to see the listing.
class LiveDropBanner extends StatelessWidget {
  const LiveDropBanner({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: c.tertiary,
        borderRadius: BorderRadius.circular(Rad.full),
        elevation: 4,
        shadowColor: c.tertiary.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.full),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3),
            child: Row(
              children: [
                Icon(Icons.bolt, color: c.onTertiary, size: 20),
                const SizedBox(width: Sp.s2),
                Text(
                  'LIVE',
                  style: t.labelSmall?.copyWith(color: c.onTertiary, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                ),
                const SizedBox(width: Sp.s2),
                Expanded(
                  child: Text(
                    '$label · just now',
                    style: t.titleSmall?.copyWith(color: c.onTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: c.onTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A listing link was copied in another app: offer to add that sale.
class ClipboardBanner extends StatelessWidget {
  const ClipboardBanner({super.key, required this.source, required this.onAdd, required this.onDismiss});
  final String source;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => KnCard(
    tier: 3,
    padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s2),
    child: Row(
      children: [
        Icon(Icons.link, color: context.kn.tertiary),
        const SizedBox(width: Sp.s3),
        Expanded(child: Text('Add the $source sale from your clipboard?')),
        TextButton(onPressed: onAdd, child: const Text('Add')),
        IconButton(tooltip: 'Dismiss', icon: const Icon(Icons.close), onPressed: onDismiss),
      ],
    ),
  );
}

/// The map's one + button: every way to put a sale on the map, in one place.
/// [onSpot] is null in modes without spotting; [onPasteLink] in modes without
/// listing links. With only one way, the button does that directly.
class AddSaleButton extends StatelessWidget {
  const AddSaleButton({super.key, required this.noun, this.onSpot, this.onPasteLink});

  /// The mode's stop noun: "sale".
  final String noun;
  final VoidCallback? onSpot;
  final VoidCallback? onPasteLink;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final ways = [?onSpot, ?onPasteLink];
    if (ways.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton(
      heroTag: 'add',
      tooltip: 'Add a $noun',
      backgroundColor: c.surfaceHighest,
      foregroundColor: c.onSurface,
      onPressed: ways.length == 1 ? ways.single : () => _sheet(context),
      child: const Icon(Icons.add, size: 28),
    );
  }

  Future<void> _sheet(BuildContext context) => showKnSheet<void>(
    context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      void pick(VoidCallback f) {
        Navigator.pop(ctx);
        f();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a $noun', style: t.headlineSmall),
            const SizedBox(height: Sp.s3),
            if (onSpot != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_a_photo_outlined),
                title: Text('Spot a $noun'),
                subtitle: const Text('Snap the sign where you are. We fill in the rest.'),
                onTap: () => pick(onSpot!),
              ),
            if (onPasteLink != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: const Text('Paste a listing link'),
                subtitle: const Text('Facebook, Craigslist, Nextdoor, EstateSales.net…'),
                onTap: () => pick(onPasteLink!),
              ),
            const SizedBox(height: Sp.s2),
            Text(
              'Tip: long-press the map to drop a stop anywhere.',
              style: t.bodySmall?.copyWith(color: ctx.kn.onSurfaceVariant),
            ),
          ],
        ),
      );
    },
  );
}
