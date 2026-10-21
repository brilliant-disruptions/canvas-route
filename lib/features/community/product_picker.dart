import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/product.dart';
import '../../state/community_state.dart';
import '../../ui/widgets/kn_widgets.dart';

/// Autocomplete over the seeded catalog with a free-text fallback.
class ProductField extends ConsumerStatefulWidget {
  const ProductField({super.key, required this.selected, required this.freeText, required this.onChanged});
  final Product? selected;
  final String? freeText;
  final void Function(Product? product, String? freeText) onChanged;
  @override
  ConsumerState<ProductField> createState() => _ProductFieldState();
}

class _ProductFieldState extends ConsumerState<ProductField> {
  late final _ctrl = TextEditingController(text: widget.selected?.displayName ?? widget.freeText);

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final q = _ctrl.text.toLowerCase();
    final matches = q.length < 2 ? const <Product>[] : products.where((p) => p.displayName.toLowerCase().contains(q)).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'e.g. Prismatic Evolutions ETB',
            suffixIcon: widget.selected != null ? Icon(Icons.check_circle, color: c.tertiary) : null,
          ),
          onChanged: (v) {
            setState(() {});
            widget.onChanged(null, v.trim().isEmpty ? null : v.trim());
          },
        ),
        if (widget.selected == null && matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: Sp.s1),
            decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(Rad.lg)),
            child: Column(children: [
              for (final p in matches)
                ListTile(
                  dense: true,
                  title: Text(p.displayName),
                  onTap: () {
                    _ctrl.text = p.displayName;
                    setState(() {});
                    widget.onChanged(p, null);
                  },
                ),
            ]),
          ),
      ],
    );
  }
}

/// Multi-select used by the Visit Logger's `productMulti` field. Values are
/// stored as `[{id, name}]` in `visits.custom_fields`.
class ProductMultiField extends ConsumerWidget {
  const ProductMultiField({super.key, required this.value, required this.onChanged});
  final List<Map<String, dynamic>> value;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
          for (final v in value)
            InputChip(
              label: Text(v['name'] as String),
              onDeleted: () => onChanged(value.where((x) => x != v).toList()),
            ),
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: c.tertiary),
            label: const Text('Add product'),
            onPressed: () async {
              final r = await showKnSheet<Map<String, dynamic>>(context, builder: (_) => const _PickOne());
              if (r != null && !value.any((x) => x['name'] == r['name'])) onChanged([...value, r]);
            },
          ),
        ]),
      ],
    );
  }
}

class _PickOne extends StatefulWidget {
  const _PickOne();
  @override
  State<_PickOne> createState() => _PickOneState();
}

class _PickOneState extends State<_PickOne> {
  Product? _p;
  String? _txt;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Which product?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Sp.s3),
          ProductField(selected: _p, freeText: _txt, onChanged: (p, t) => setState(() {
            _p = p;
            _txt = t;
          })),
          const SizedBox(height: Sp.s4),
          KnButton(
            label: 'Add',
            onPressed: (_p == null && (_txt == null || _txt!.isEmpty))
                ? null
                : () => Navigator.pop(context, {'id': _p?.id, 'name': _p?.displayName ?? _txt}),
          ),
        ]),
      );
}
