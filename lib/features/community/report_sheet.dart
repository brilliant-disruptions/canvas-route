import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../data/models/product.dart';
import '../../data/models/report.dart';
import '../../modes/mode_pack.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import 'product_picker.dart';

Future<void> showReportSheet(BuildContext context, Pin pin) =>
    showKnSheet(context, builder: (_) => ReportSheet(pin: pin));

/// Two taps to file: product, status. Everything else optional (spec §5.4).
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.pin});
  final Pin pin;
  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  String? _status;
  Product? _product;
  String? _productText;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _limit = TextEditingController();
  bool _line = false;
  bool _saving = false;

  /// Search the whole catalog instead of the quick picks.
  bool _typing = false;
  bool _details = false;

  Future<void> _submit() async {
    if (_status == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(reportRepoProvider)
          .create(
            ReportDraft(
              pinId: widget.pin.id,
              status: _status!,
              productId: _product?.id,
              productText: _product == null ? _productText : null,
              qty: int.tryParse(_qty.text),
              priceCents: double.tryParse(_price.text) == null ? null : (double.parse(_price.text) * 100).round(),
              purchaseLimit: int.tryParse(_limit.text),
              linePresent: _line,
            ),
            ref.read(currentUserIdProvider)!,
          );
      ref.invalidate(recentReportsProvider(widget.pin.id));
      ref.invalidate(storeSummaryProvider(widget.pin.id));
      // The map's pins and deck read these; your own report should show there too.
      ref.invalidate(latestReportsProvider);
      ref.invalidate(storeSummariesProvider);
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Shared with nearby ${ref.read(modePackProvider).communityNoun}', icon: Icons.check);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Couldn\'t report: $e');
      }
    }
  }

  Widget _statusTile(ReportStatusOption s) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final selected = _status == s.value;
    return Material(
      color: selected ? c.tertiary : c.surfaceHigh,
      borderRadius: BorderRadius.circular(Rad.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.lg),
        onTap: () => setState(() => _status = s.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.s3, vertical: Sp.s2),
            child: Row(
              children: [
                Icon(s.icon, size: 20, color: selected ? c.onTertiary : c.tertiary),
                const SizedBox(width: Sp.s2),
                Expanded(
                  child: Text(
                    s.label,
                    style: t.titleSmall?.copyWith(color: selected ? c.onTertiary : null),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    // Quick picks: what's been reported here lately, then the user's watchlist.
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final byId = {for (final p in products) p.id: p};
    final recent = ref.watch(recentReportsProvider(widget.pin.id)).value ?? const <Report>[];
    final follows = ref.watch(followsProvider).value ?? const <String>{};
    final quick = [
      ...{...recent.map((r) => r.productId).whereType<String>(), ...follows},
    ].map((id) => byId[id]).whereType<Product>().take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report the shelf', style: t.headlineSmall),
            Text(widget.pin.name, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Sp.s4),
            if (pack.productCatalog) ...[
              Text('What did you see?', style: t.titleMedium),
              const SizedBox(height: Sp.s2),
              if (quick.isNotEmpty && !_typing)
                Wrap(
                  spacing: Sp.s2,
                  runSpacing: Sp.s2,
                  children: [
                    for (final p in quick)
                      ChoiceChip(
                        label: Text(p.displayName),
                        selected: _product?.id == p.id,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _product = _product?.id == p.id ? null : p;
                          _productText = null;
                        }),
                      ),
                    ActionChip(
                      avatar: Icon(Icons.search, size: 16, color: c.tertiary),
                      label: const Text('Other…'),
                      onPressed: () => setState(() {
                        _typing = true;
                        _product = null;
                      }),
                    ),
                  ],
                )
              else
                ProductField(
                  selected: _product,
                  freeText: _productText,
                  onChanged: (p, txt) => setState(() {
                    _product = p;
                    _productText = txt;
                  }),
                ),
              const SizedBox(height: Sp.s4),
            ],
            Text('Shelf status', style: t.titleMedium),
            const SizedBox(height: Sp.s2),
            for (var i = 0; i < pack.reportStatuses.length; i += 2) ...[
              if (i > 0) const SizedBox(height: Sp.s2),
              Row(
                children: [
                  Expanded(child: _statusTile(pack.reportStatuses[i])),
                  const SizedBox(width: Sp.s2),
                  Expanded(
                    child: i + 1 < pack.reportStatuses.length
                        ? _statusTile(pack.reportStatuses[i + 1])
                        : const SizedBox(),
                  ),
                ],
              ),
            ],
            if (pack.productCatalog) ...[
              const SizedBox(height: Sp.s2),
              if (!_details)
                TextButton.icon(
                  onPressed: () => setState(() => _details = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add details: qty, price, limit, line'),
                )
              else ...[
                const SizedBox(height: Sp.s2),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qty,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty left'),
                      ),
                    ),
                    const SizedBox(width: Sp.s2),
                    Expanded(
                      child: TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price', prefixText: '\$'),
                      ),
                    ),
                    const SizedBox(width: Sp.s2),
                    Expanded(
                      child: TextField(
                        controller: _limit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Limit'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Line / scalpers present'),
                  value: _line,
                  onChanged: (v) => setState(() => _line = v),
                ),
              ],
            ],
            const SizedBox(height: Sp.s3),
            KnButton(label: 'Send report', lime: true, loading: _saving, onPressed: _status == null ? null : _submit),
            const SizedBox(height: Sp.s2),
            Text(
              'Public observation on a retail floor. No employee names, no back-room photos.',
              style: t.labelSmall?.copyWith(color: c.onSurfaceDisabled),
            ),
          ],
        ),
      ),
    );
  }
}
