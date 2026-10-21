import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../data/models/product.dart';
import '../../data/models/report.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import 'product_picker.dart';

Future<void> showReportSheet(BuildContext context, Pin pin) => showKnSheet(context, builder: (_) => ReportSheet(pin: pin));

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

  Future<void> _submit() async {
    if (_status == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(reportRepoProvider).create(
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
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Shared with nearby collectors', icon: Icons.check);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Couldn\'t report: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report ${widget.pin.name}', style: t.headlineSmall),
            const SizedBox(height: Sp.s4),
            if (pack.productCatalog) ...[
              Text('Product', style: t.titleMedium),
              const SizedBox(height: Sp.s2),
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
            Text('Status', style: t.titleMedium),
            const SizedBox(height: Sp.s2),
            Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
              for (final s in pack.reportStatuses)
                ChoiceChip(
                  avatar: Icon(s.icon, size: 16, color: _status == s.value ? c.onPrimaryContainer : c.onSurfaceVariant),
                  label: Text(s.label),
                  selected: _status == s.value,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _status = s.value),
                ),
            ]),
            if (pack.productCatalog) ...[
              const SizedBox(height: Sp.s4),
              Row(children: [
                Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty left'))),
                const SizedBox(width: Sp.s2),
                Expanded(child: TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price', prefixText: '\$'))),
                const SizedBox(width: Sp.s2),
                Expanded(child: TextField(controller: _limit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit'))),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Line / scalpers present'),
                value: _line,
                onChanged: (v) => setState(() => _line = v),
              ),
            ],
            const SizedBox(height: Sp.s3),
            KnButton(label: 'Send report', lime: true, loading: _saving, onPressed: _status == null ? null : _submit),
            const SizedBox(height: Sp.s2),
            Text('Public observation on a retail floor. No employee names, no back-room photos.',
                style: t.labelSmall?.copyWith(color: c.onSurfaceDisabled)),
          ],
        ),
      ),
    );
  }
}
