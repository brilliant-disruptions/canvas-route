import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../state/map_state.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

Future<void> showDraftTray(BuildContext context) => showKnSheet(context, builder: (_) => const DraftTray());

class DraftTray extends ConsumerWidget {
  const DraftTray({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final map = ref.watch(mapProvider);
    final pack = ref.watch(modePackProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s3, Sp.s2),
            child: Row(children: [
              Expanded(child: Text(map.editingRouteId != null ? 'Editing "${map.editingRouteName}"' : 'Draft route', style: t.headlineSmall)),
              TextButton(
                onPressed: () async {
                  if (await confirm(context, title: 'Discard draft?', confirmLabel: 'Discard', destructive: true)) {
                    ref.read(mapProvider.notifier).clearDrafts();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Discard'),
              ),
            ]),
          ),
          Expanded(
            child: map.draftStops.isEmpty
                ? EmptyState(icon: Icons.add_location_alt_outlined, title: 'No ${pack.stopNoun}s yet')
                : ListView.separated(
                    itemCount: map.draftStops.length,
                    separatorBuilder: (_, _) => const GhostDivider(),
                    itemBuilder: (_, i) {
                      final d = map.draftStops[i];
                      return Slidable(
                        key: ValueKey(d.id),
                        endActionPane: ActionPane(motion: const DrawerMotion(), children: [
                          SlidableAction(
                            onPressed: (_) => ref.read(mapProvider.notifier).removeDraft(d.id),
                            backgroundColor: c.error,
                            foregroundColor: c.onError,
                            icon: Icons.delete_outline,
                            label: 'Remove',
                          ),
                        ]),
                        child: ListTile(
                          leading: NumberDot(i + 1),
                          title: Text(d.business.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(d.business.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(Sp.s4),
            child: KnButton(
              label: 'Go to Builder',
              icon: Icons.arrow_forward,
              lime: true,
              onPressed: map.draftStops.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.push('/route/builder');
                    },
            ),
          ),
        ],
      ),
    );
  }
}
