import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/logic/when_filter.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../modes/mode_pack.dart';
import '../../state/map_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Search, list/map toggle and menu, then one row of filters under them.
class MapTopBar extends ConsumerWidget {
  const MapTopBar({
    super.key,
    required this.pack,
    required this.search,
    required this.onSearch,
    required this.onSuggestion,
    this.hideSuggestions = false,
  });
  final ModePack pack;
  final TextEditingController search;
  final VoidCallback onSearch;
  final ValueChanged<String> onSuggestion;

  /// The quick-start deck already shows the suggestions as cards.
  final bool hideSuggestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(mapProvider);
    final n = ref.read(mapProvider.notifier);
    final isMap = map.viewMode == MapViewMode.map;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0),
          child: Row(
            children: [
              Expanded(
                child: _GlassBar(
                  child: TextField(
                    controller: search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    decoration: InputDecoration(
                      hintText: pack.searchHint,
                      prefixIcon: map.searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : const Icon(Icons.search),
                      suffixIcon: map.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                search.clear();
                                n.clearSearch();
                              },
                            ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Sp.s2),
              _GlassBar(
                child: IconButton(
                  tooltip: isMap ? 'Show list' : 'Show map',
                  icon: Icon(isMap ? Icons.view_list : Icons.map),
                  onPressed: () => n.setViewMode(isMap ? MapViewMode.list : MapViewMode.map),
                ),
              ),
              const SizedBox(width: Sp.s2),
              const _GlassBar(child: ProfileButton()),
            ],
          ),
        ),
        const SizedBox(height: Sp.s2),
        _FilterRow(pack: pack, map: map, hideSuggestions: hideSuggestions, onSuggestion: onSuggestion),
      ],
    );
  }
}

class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: context.kn.glass,
      borderRadius: BorderRadius.circular(Rad.xl),
      border: Border.all(color: context.kn.ghostBorder),
      boxShadow: [
        BoxShadow(color: context.kn.primaryDim.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 8)),
      ],
    ),
    child: Center(child: child),
  );
}

/// Time-boxed modes get two filters, what and when; others get search suggestions.
class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.pack, required this.map, required this.hideSuggestions, required this.onSuggestion});
  final ModePack pack;
  final MapState map;
  final bool hideSuggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(mapProvider.notifier);
    final c = context.kn;
    final List<Widget> chips;
    if (pack.requiresTimeWindow) {
      final now = DateTime.now();
      final when = whenLabel(openNow: map.openNow, day: map.selectedDay, now: now);
      final anyDay = !map.openNow && map.selectedDay == null;
      chips = [
        if (pack.community.categories.isNotEmpty)
          InputChip(
            avatar: Icon(Icons.tune, size: 16, color: map.huntFilter.isEmpty ? null : c.onPrimaryContainer),
            label: Text('Hunting: ${huntLabel(map.huntFilter)}'),
            selected: map.huntFilter.isNotEmpty,
            showCheckmark: false,
            onPressed: () => _pickHunt(context, pack, map.huntFilter, n.setHunt),
          ),
        InputChip(
          avatar: map.openNow
              ? Icon(Icons.circle, size: 10, color: c.tertiary)
              : Icon(Icons.event, size: 16, color: anyDay ? null : c.onPrimaryContainer),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(when), const SizedBox(width: 2), const Icon(Icons.arrow_drop_down, size: 18)],
          ),
          selected: !anyDay,
          showCheckmark: false,
          onPressed: () => _pickWhen(context, map, n),
        ),
      ];
    } else if (hideSuggestions) {
      return const SizedBox.shrink();
    } else {
      chips = [for (final s in pack.searchSuggestions) ActionChip(label: Text(s), onPressed: () => onSuggestion(s))];
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: Sp.s2),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

Future<void> _pickWhen(BuildContext context, MapState map, MapNotifier n) => showKnSheet<void>(
  context,
  builder: (ctx) {
    final t = Theme.of(ctx).textTheme;
    final c = ctx.kn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When are you going?', style: t.headlineSmall),
          const SizedBox(height: Sp.s2),
          for (final o in whenOptions(DateTime.now()))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: o.openNow
                  ? Icon(Icons.circle, size: 12, color: c.tertiary)
                  : Icon(o.day == null ? Icons.all_inclusive : Icons.event),
              title: Text(o.label),
              subtitle: o.openNow ? const Text('Open, or opening within 30 minutes') : null,
              trailing: whenSelected(o, openNow: map.openNow, day: map.selectedDay)
                  ? Icon(Icons.check, color: c.primary)
                  : null,
              onTap: () {
                o.openNow ? n.setOpenNow(true) : n.setDay(o.day);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  },
);

/// Multi-select of the pack's pin categories for the hunt filter.
Future<void> _pickHunt(
  BuildContext context,
  ModePack pack,
  Set<String> current,
  ValueChanged<Set<String>> onDone,
) async {
  final picked = {...current};
  await showKnSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final t = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you hunting?', style: t.headlineSmall),
              const SizedBox(height: Sp.s1),
              Text(
                'Only matching ${pack.stopNoun}s show on the map and in your plan.',
                style: t.bodySmall?.copyWith(color: ctx.kn.onSurfaceVariant),
              ),
              const SizedBox(height: Sp.s4),
              Wrap(
                spacing: Sp.s2,
                runSpacing: Sp.s2,
                children: [
                  for (final cat in pack.community.categories.where((c) => c != pack.community.categoryWildcard))
                    FilterChip(
                      label: Text(cat),
                      selected: picked.contains(cat),
                      onSelected: (v) => setState(() => v ? picked.add(cat) : picked.remove(cat)),
                    ),
                ],
              ),
              const SizedBox(height: Sp.s5),
              Row(
                children: [
                  TextButton(onPressed: () => setState(picked.clear), child: const Text('Clear')),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: KnButton(
                      label: 'Show ${pack.stopNoun}s',
                      lime: true,
                      compact: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
  onDone(picked);
}
