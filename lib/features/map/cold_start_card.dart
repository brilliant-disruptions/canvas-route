import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env.dart';
import '../../core/logic/errors.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../state/demand_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';

/// What an empty area shows instead of a dead map: the honest state ("not here
/// yet"), how many people are already waiting, a one-tap "count me in", and the
/// three ways to change it: spot a listing, post your own, or go where it's live.
class ColdStartCard extends ConsumerStatefulWidget {
  const ColdStartCard({
    super.key,
    required this.pack,
    required this.area,
    required this.onSpot,
    required this.onBrowse,
  });

  final ModePack pack;
  final DemandKey area;
  final VoidCallback onSpot;

  /// Moves the map to the nearest live listing.
  final void Function(double lat, double lng) onBrowse;

  @override
  ConsumerState<ColdStartCard> createState() => _ColdStartCardState();
}

class _ColdStartCardState extends ConsumerState<ColdStartCard> {
  bool _busy = false;

  Future<void> _countMeIn() async {
    setState(() => _busy = true);
    try {
      final n = await ref.read(demandActionsProvider).register(widget.area);
      HapticFeedback.mediumImpact();
      if (mounted) {
        toast(
          context,
          n <= 1 ? 'You\'re the first here. Invite a friend to fill the map faster.' : 'You\'re one of $n waiting here.',
          icon: Icons.how_to_reg_outlined,
        );
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invite() {
    final p = widget.pack;
    ref.read(shareServiceProvider).shareText(
          'Help fill the ${p.label.toLowerCase()} map near us: ${Env.webOrigin}',
          subject: '${p.label} near us',
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final p = widget.pack;
    final waiting = ref.watch(huntersWaitingProvider(widget.area)).value ?? 0;
    final mine = ref.watch(myHuntInterestProvider(widget.area)).value ?? false;
    final nearest = ref.watch(nearestLiveProvider(widget.area)).value;
    final others = mine ? waiting - 1 : waiting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s4),
      child: KnCard(
        tier: 3,
        accent: c.tertiary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NOT HERE YET', style: t.labelSmall?.copyWith(color: c.tertiary, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            const SizedBox(height: Sp.s1),
            Text('No ${p.stopNoun}s posted near you yet', style: t.titleLarge),
            const SizedBox(height: Sp.s1),
            Text(
              switch ((mine, others)) {
                (true, 0) => 'You\'re first in line. Invite another ${p.communityNoun.replaceAll(RegExp(r's$'), '')} to fill it faster.',
                (true, _) => 'You and $others other ${p.communityNoun} are waiting here.',
                (false, 0) => 'Be the first ${p.communityNoun.replaceAll(RegExp(r's$'), '')} here. Hosts see how many are waiting.',
                (false, _) => '$others ${p.communityNoun} near you are already waiting. Hosts can see that.',
              },
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Sp.s3),
            KnButton(
              label: mine ? 'You\'re on the list · Invite a friend' : p.waitlistLabel!,
              icon: mine ? Icons.ios_share : Icons.front_hand_outlined,
              lime: !mine,
              loading: _busy,
              onPressed: mine ? _invite : _countMeIn,
            ),
            const SizedBox(height: Sp.s2),
            Wrap(
              spacing: Sp.s2,
              runSpacing: Sp.s1,
              children: [
                if (p.spotLabel != null)
                  ActionChip(avatar: const Icon(Icons.add_a_photo_outlined, size: 18), label: const Text('Spot one'), onPressed: widget.onSpot),
                if (p.supportsHosting)
                  ActionChip(avatar: const Icon(Icons.sell_outlined, size: 18), label: const Text('Post mine free'), onPressed: () => context.push('/host/new')),
                if (nearest != null && nearest.miles > 15)
                  ActionChip(
                    avatar: const Icon(Icons.travel_explore, size: 18),
                    label: Text('Live in ${nearest.city ?? 'another area'} · ${nearest.miles.round()} mi'),
                    onPressed: () => widget.onBrowse(nearest.lat, nearest.lng),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
