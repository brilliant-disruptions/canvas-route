import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/settings.dart';
import '../../data/models/visit_field.dart';
import '../../state/profile_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Outcomes, visit fields and export columns for the active mode. Edits are
/// stored as per-mode overrides; "Reset" drops back to the pack defaults.
class AdvancedScreen extends ConsumerWidget {
  const AdvancedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final outcomes = ref.watch(effectiveOutcomesProvider);
    final fields = ref.watch(effectiveVisitFieldsProvider);
    final exportFields = ref.watch(effectiveExportFieldsProvider);
    final n = ref.read(settingsProvider.notifier);
    final allExportable = ['stopName', 'address', ...fields.where((f) => f.type != FieldType.photo).map((f) => f.key), 'visitedAt'];

    return KnScaffold(
      title: 'Advanced · ${pack.label}',
      actions: [
        TextButton(
          onPressed: () async {
            if (await confirm(context, title: 'Reset to defaults?', confirmLabel: 'Reset')) {
              await n.updateOverride(pack.id, (_) => const ModeOverride());
            }
          },
          child: const Text('Reset'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          SectionHeader('Outcomes', subtitle: 'Shown as chips in the ${pack.visitVerb.toLowerCase()} form', trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final v = await promptText(context, title: 'New outcome', confirmLabel: 'Add');
              if (v != null && v.isNotEmpty && !outcomes.contains(v)) n.updateOverride(pack.id, (o) => o.copyWith(outcomes: [...outcomes, v]));
            },
          )),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (o, nw) {
              final list = [...outcomes];
              list.insert(nw, list.removeAt(o));
              n.updateOverride(pack.id, (x) => x.copyWith(outcomes: list));
            },
            children: [
              for (var i = 0; i < outcomes.length; i++)
                ListTile(
                  key: ValueKey('o$i${outcomes[i]}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(outcomes[i]),
                  leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => n.updateOverride(pack.id, (x) => x.copyWith(outcomes: outcomes.where((o) => o != outcomes[i]).toList()))),
                ),
            ],
          ),
          SectionHeader('Visit fields', subtitle: 'Toggle, reorder, or add custom fields', trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final r = await showKnSheet<VisitFieldDefinition>(context, builder: (_) => const _NewFieldSheet());
              if (r != null) n.updateOverride(pack.id, (x) => x.copyWith(visitFields: [...fields, r]));
            },
          )),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (o, nw) {
              final list = [...fields];
              list.insert(nw, list.removeAt(o));
              n.updateOverride(pack.id, (x) => x.copyWith(visitFields: list));
            },
            children: [
              for (var i = 0; i < fields.length; i++)
                SwitchListTile(
                  key: ValueKey('f${fields[i].key}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(fields[i].label),
                  subtitle: Text('${fields[i].type.name}${fields[i].isCustom ? ' · custom' : ''}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  secondary: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  value: fields[i].enabled,
                  onChanged: (v) => n.updateOverride(pack.id, (x) => x.copyWith(visitFields: [for (final f in fields) f.key == fields[i].key ? f.copyWith(enabled: v) : f])),
                ),
            ],
          ),
          const SectionHeader('Export columns', subtitle: 'Order and selection for CSV export'),
          for (final k in allExportable)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pack.exportHeaders[k] ?? fields.where((f) => f.key == k).firstOrNull?.label ?? k),
              value: exportFields.contains(k),
              onChanged: (v) => n.updateOverride(pack.id, (x) => x.copyWith(exportFields: v == true ? [...exportFields, k] : exportFields.where((e) => e != k).toList())),
            ),
        ],
      ),
    );
  }
}

class _NewFieldSheet extends StatefulWidget {
  const _NewFieldSheet();
  @override
  State<_NewFieldSheet> createState() => _NewFieldSheetState();
}

class _NewFieldSheetState extends State<_NewFieldSheet> {
  final _label = TextEditingController();
  FieldType _type = FieldType.text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Custom field', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Sp.s3),
          TextField(controller: _label, autofocus: true, decoration: const InputDecoration(labelText: 'Label')),
          const SizedBox(height: Sp.s3),
          DropdownButtonFormField<FieldType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: FieldType.text, child: Text('Text')),
              DropdownMenuItem(value: FieldType.multiline, child: Text('Long text')),
              DropdownMenuItem(value: FieldType.number, child: Text('Number')),
              DropdownMenuItem(value: FieldType.currency, child: Text('Currency')),
              DropdownMenuItem(value: FieldType.date, child: Text('Date')),
              DropdownMenuItem(value: FieldType.toggle, child: Text('Yes / No')),
            ],
            onChanged: (v) => setState(() => _type = v ?? FieldType.text),
          ),
          const SizedBox(height: Sp.s4),
          KnButton(
            label: 'Add field',
            onPressed: () {
              final label = _label.text.trim();
              if (label.isEmpty) return;
              final key = 'c_${label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
              Navigator.pop(context, VisitFieldDefinition(key: key, label: label, type: _type, isCustom: true));
            },
          ),
        ]),
      );
}
