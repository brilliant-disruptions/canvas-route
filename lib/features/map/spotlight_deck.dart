import 'package:flutter/material.dart';

import '../../core/logic/geo.dart';
import '../../core/logic/spotlight.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/business.dart';
import '../../modes/mode_pack.dart';
import '../../ui/widgets/kn_widgets.dart';

typedef SpotEntry = ({Spot spot, Business business, String? detail});

/// Bottom-of-map carousel of ranked spots with a one-tap planner.
/// Replaces hunting through anonymous pins: the "why go" is on the card.
class SpotlightDeck extends StatelessWidget {
  const SpotlightDeck({
    super.key,
    required this.pack,
    required this.entries,
    required this.draftCount,
    required this.isDraft,
    required this.onToggle,
    required this.onOpen,
    required this.onPlan,
    required this.onOpenDraft,
    required this.statusLabel,
    this.showTip = false,
    this.onDismissTip,
  });

  final ModePack pack;
  final List<SpotEntry> entries;
  final int draftCount;
  final bool Function(Business) isDraft;
  final ValueChanged<Business> onToggle;
  final ValueChanged<Business> onOpen;

  /// Empty draft: auto-pick and plan. Otherwise: build the route from the draft.
  final VoidCallback onPlan;
  final VoidCallback onOpenDraft;
  final String Function(String status) statusLabel;

  /// First-run coach mark above the plan button.
  final bool showTip;
  final VoidCallback? onDismissTip;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final n = entries.length;
    final planCount = pickPlan(entries.map((e) => e.spot).toList(), pack.planMaxStops).length;
    final drafting = draftCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTip && !drafting && planCount > 0)
          _PlanTip(
            text: 'One tap picks the best $planCount ${pack.stopNoun}s near you and puts them in the right order.',
            onDismiss: onDismissTip,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.s4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s2, Sp.s2),
            decoration: BoxDecoration(
              color: c.glass,
              borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: c.ghostBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: drafting ? onOpenDraft : null,
                    borderRadius: BorderRadius.circular(Rad.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          drafting
                              ? '$draftCount ${pack.stopNoun}${draftCount == 1 ? '' : 's'} picked'
                              : '$n ${pack.stopNoun}${n == 1 ? '' : 's'} ${pack.spotlightTitle}',
                          style: t.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          drafting ? 'Tap to review' : 'Best $planCount, in order',
                          style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Sp.s2),
                SizedBox(
                  width: 148,
                  child: KnButton(
                    label: drafting ? 'Build route' : pack.planLabel,
                    icon: drafting ? Icons.arrow_forward : Icons.bolt,
                    lime: true,
                    compact: true,
                    onPressed: drafting || planCount > 0 ? onPlan : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.s2),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sp.s4),
            itemCount: n,
            separatorBuilder: (_, _) => const SizedBox(width: Sp.s2),
            itemBuilder: (_, i) {
              final e = entries[i];
              return _SpotCard(
                entry: e,
                rank: i + 1,
                headline: spotHeadline(e.spot, now: now, statusLabel: statusLabel),
                added: isDraft(e.business),
                onToggle: () => onToggle(e.business),
                onOpen: () => onOpen(e.business),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlanTip extends StatelessWidget {
  const _PlanTip({required this.text, this.onDismiss});
  final String text;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s8, 0, Sp.s4, Sp.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: c.tertiary,
            borderRadius: BorderRadius.circular(Rad.lg),
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(Rad.lg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s2, Sp.s3),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: c.onTertiary, size: 20),
                    const SizedBox(width: Sp.s2),
                    Expanded(
                      child: Text(
                        text,
                        style: t.bodyMedium?.copyWith(color: c.onTertiary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Dismiss tip',
                      child: Icon(Icons.close, color: c.onTertiary, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 64),
            child: CustomPaint(size: const Size(16, 8), painter: _Notch(c.tertiary)),
          ),
        ],
      ),
    );
  }
}

class _Notch extends CustomPainter {
  const _Notch(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_Notch old) => old.color != color;
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.entry,
    required this.rank,
    required this.headline,
    required this.added,
    required this.onToggle,
    required this.onOpen,
  });

  final SpotEntry entry;
  final int rank;
  final String headline;
  final bool added;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final tone = toneFor(entry.spot.reason);
    final toneColor = switch (tone) {
      SpotTone.hot => c.tertiary,
      SpotTone.good => c.primary,
      SpotTone.neutral => c.onSurfaceVariant,
      SpotTone.warn => c.error,
    };
    final sub = [
      if (entry.spot.reason != SpotReason.nearby) formatDistance(entry.spot.distanceMeters),
      if (entry.detail != null && entry.detail!.isNotEmpty) entry.detail!,
    ].join(' · ');

    return SizedBox(
      width: 264,
      child: Material(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(Rad.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: tone == SpotTone.hot ? c.tertiary.withValues(alpha: 0.6) : c.ghostBorder),
              borderRadius: BorderRadius.circular(Rad.xl),
            ),
            padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s2, Sp.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          tone == SpotTone.hot ? _PulseDot(color: toneColor) : _Dot(color: toneColor),
                          const SizedBox(width: Sp.s2),
                          Expanded(
                            child: Text(
                              headline.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSmall?.copyWith(
                                color: toneColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.s2),
                      Text(entry.business.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text(
                        sub.isEmpty ? '#$rank nearby' : sub,
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: added ? 'Remove from route' : 'Add to route',
                  onPressed: onToggle,
                  style: IconButton.styleFrom(
                    backgroundColor: added ? c.tertiary : c.surfaceHighest,
                    foregroundColor: added ? c.onTertiary : c.onSurface,
                  ),
                  icon: Icon(added ? Icons.check : Icons.add),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A live-signal dot with an expanding halo.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 8,
    height: 8,
    child: AnimatedBuilder(
      animation: _ctl,
      builder: (_, child) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1 + _ctl.value * 1.6,
            child: Opacity(
              opacity: 1 - _ctl.value,
              child: _Dot(color: widget.color),
            ),
          ),
          child!,
        ],
      ),
      child: _Dot(color: widget.color),
    ),
  );
}

/// The empty map's deck: one card per search category. Tapping a card searches;
/// its button searches and plans the nearest stops in one go.
class QuickStartDeck extends StatelessWidget {
  const QuickStartDeck({
    super.key,
    required this.pack,
    required this.busy,
    required this.onSearch,
    required this.onPlan,
  });
  final ModePack pack;

  /// The category currently being searched or planned, if any.
  final String? busy;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.s4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3),
            decoration: BoxDecoration(
              color: c.glass,
              borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: c.ghostBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: c.tertiary),
                const SizedBox(width: Sp.s2),
                Expanded(
                  child: Text(
                    'Pick a category. We\'ll route the nearest ${pack.planMaxStops}.',
                    style: t.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.s2),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sp.s4),
            itemCount: pack.searchSuggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: Sp.s2),
            itemBuilder: (_, i) {
              final s = pack.searchSuggestions[i];
              final label = '${s[0].toUpperCase()}${s.substring(1)}';
              return SizedBox(
                width: 204,
                child: Material(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(Rad.xl),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: busy == null ? () => onSearch(s) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(Sp.s3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(pack.suggestionIcon(s), color: c.tertiary, size: 22),
                              const SizedBox(width: Sp.s2),
                              Expanded(
                                child: Text(label, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 36,
                            child: FilledButton.icon(
                              onPressed: busy == null ? () => onPlan(s) : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: c.tertiary,
                                foregroundColor: c.onTertiary,
                                minimumSize: const Size.fromHeight(36),
                                padding: const EdgeInsets.symmetric(horizontal: Sp.s3),
                                textStyle: t.labelLarge,
                              ),
                              icon: busy == s
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: c.onTertiary),
                                    )
                                  : const Icon(Icons.bolt, size: 16),
                              label: Text(
                                'Route nearest ${pack.planMaxStops}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
