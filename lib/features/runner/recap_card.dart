import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/logic/geo.dart';
import '../../core/logic/recap.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../ui/widgets/route_sketch.dart';

/// The shareable end-of-run card. Fixed 4:5 at [size] logical pixels and
/// always in the dark brand palette, so a shared image looks the same
/// whatever theme the sharer uses.
class RecapCard extends StatelessWidget {
  const RecapCard({
    super.key,
    required this.pack,
    required this.routeName,
    required this.recap,
    this.totals = const {},
    this.extra,
  });

  static const size = Size(360, 450);

  final ModePack pack;
  final String routeName;
  final RunRecap recap;

  /// One more stat for the subtitle, e.g. "7 items".
  final String? extra;

  /// Label → formatted value, e.g. {"Spent": "$72.50"}.
  final Map<String, String> totals;

  @override
  Widget build(BuildContext context) {
    const c = KnColors.dark;
    final t = Theme.of(context).textTheme;
    final when = recap.stops
        .map((s) => s.at)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final sub = [
      '${recap.visited} of ${recap.stops.length} ${pack.stopNoun}s',
      if (recap.duration != null) formatDuration(recap.duration!.inSeconds),
      ...totals.entries.map((e) => '${e.value} ${e.key.toLowerCase()}'),
      ?extra,
    ].join(' · ');

    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.xxl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.surfaceLowest, Color.lerp(c.surfaceLowest, c.primaryDim, 0.35)!],
          ),
          border: Border.all(color: c.ghostBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Sp.s6),
          child: DefaultTextStyle(
            style: t.bodyMedium!.copyWith(color: c.onSurface),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(pack.icon, size: 18, color: c.tertiary),
                    const SizedBox(width: Sp.s2),
                    Text(
                      pack.label.toUpperCase(),
                      style: t.labelMedium?.copyWith(
                        color: c.tertiary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const Spacer(),
                    if (when != null)
                      Text(DateFormat.MMMEd().format(when), style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: Sp.s5),
                Text(
                  routeName,
                  style: t.titleLarge?.copyWith(color: c.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  countNoun(recap.wins, pack.winNoun),
                  style: t.displayLarge?.copyWith(fontSize: 56, height: 1.05, color: c.tertiary, letterSpacing: -1.5),
                ),
                Text(
                  sub,
                  style: t.titleMedium?.copyWith(color: c.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Sp.s4),
                Expanded(
                  child: RouteSketch(
                    points: [for (final s in recap.stops) (lat: s.lat, lng: s.lng)],
                    stops: [
                      for (final s in recap.stops)
                        s.outcome == null
                            ? SketchStop.pending
                            : (pack.winOutcomes.contains(s.outcome) ? SketchStop.win : SketchStop.visited),
                    ],
                    line: c.primary,
                    win: c.tertiary,
                    visited: c.onSurface,
                    pending: c.outline,
                  ),
                ),
                const SizedBox(height: Sp.s4),
                Wrap(
                  spacing: Sp.s2,
                  runSpacing: Sp.s2,
                  children: [
                    for (final e in recap.outcomeCounts.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.s3, vertical: 5),
                        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Rad.full)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pack.outcomeIcon(e.key),
                              size: 14,
                              color: pack.winOutcomes.contains(e.key) ? c.tertiary : c.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text('${e.value} ${e.key}', style: t.labelMedium?.copyWith(color: c.onSurface)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Sp.s5),
                Row(
                  children: [
                    Text(
                      'CanvasRoute',
                      style: t.titleMedium?.copyWith(color: c.onSurface, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: Sp.s2),
                    Expanded(
                      child: Text(
                        pack.tagline,
                        style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
