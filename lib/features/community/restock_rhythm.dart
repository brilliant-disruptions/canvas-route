import 'package:flutter/material.dart';

import '../../core/logic/pin_labels.dart';
import '../../core/logic/restock.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/store_summary.dart';
import '../../ui/widgets/kn_widgets.dart';

/// A store's week at a glance: reports per weekday, the strongest day lit,
/// today marked, and when the next likely restock window opens.
class RestockRhythm extends StatelessWidget {
  const RestockRhythm({super.key, required this.summary});
  final StoreSummary summary;

  static const _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = now.weekday % 7;
    final hits = summary.dayHits.length == 7 ? summary.dayHits : List.filled(7, 0);
    final peak = hits.reduce((a, b) => a > b ? a : b);
    final next = nextLikelyWindow(summary.bestWindows, now);

    return KnCard(
      tier: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: c.tertiary, size: 20),
              const SizedBox(width: Sp.s2),
              Expanded(child: Text('Restock rhythm', style: t.titleMedium)),
              Text(
                '${summary.totalHits} sighting${summary.totalHits == 1 ? '' : 's'} · 90 days',
                style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Sp.s4),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var d = 0; d < 7; d++) ...[
                  if (d > 0) const SizedBox(width: Sp.s2),
                  Expanded(
                    child: Semantics(
                      label: '${_dayNames[d]}: ${hits[d]} sightings',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (peak > 0 && hits[d] == peak)
                            Text(
                              '${hits[d]}',
                              style: t.labelSmall?.copyWith(color: c.tertiary, fontWeight: FontWeight.w800),
                            ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: peak == 0 ? 4 : 4 + 52 * hits[d] / peak,
                            decoration: BoxDecoration(
                              color: peak > 0 && hits[d] == peak
                                  ? c.tertiary
                                  : c.primary.withValues(alpha: hits[d] == 0 ? 0.18 : 0.55),
                              borderRadius: BorderRadius.circular(Rad.sm),
                            ),
                          ),
                          const SizedBox(height: Sp.s1),
                          Text(
                            _days[d],
                            style: t.labelSmall?.copyWith(
                              color: d == today ? c.onSurface : c.onSurfaceVariant,
                              fontWeight: d == today ? FontWeight.w800 : null,
                              decoration: d == today ? TextDecoration.underline : null,
                              decorationColor: c.tertiary,
                              decorationThickness: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: Sp.s3),
            const GhostDivider(),
            const SizedBox(height: Sp.s3),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: c.tertiary),
                const SizedBox(width: Sp.s2),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Next likely  ',
                          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: '${_dayNames[next.start.weekday % 7]} ${compactWindow(next.start, next.end)}',
                          style: t.titleSmall,
                        ),
                        TextSpan(
                          text: '  ·  ${untilLabel(next.start, now)}',
                          style: t.bodySmall?.copyWith(color: c.tertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (summary.lastSeen != null) ...[
            const SizedBox(height: Sp.s1),
            Text(
              'Last seen ${relativeAge(summary.lastSeen!)}',
              style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
