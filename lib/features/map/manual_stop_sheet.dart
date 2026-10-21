import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../ui/widgets/kn_widgets.dart';

class ManualStopResult {
  const ManualStopResult({required this.name, this.address, this.opensAt, this.closesAt, this.listingUrl});
  final String name;
  final String? address;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final String? listingUrl;
}

Future<ManualStopResult?> showManualStopSheet(
  BuildContext context, {
  String? address,
  bool requiresWindow = false,
  String? listingUrl,
  bool askAddress = false,
  String? initialName,
  DateTime? initialOpens,
  DateTime? initialCloses,
}) =>
    showKnSheet<ManualStopResult>(
      context,
      builder: (_) => _ManualStopForm(
        address: address,
        requiresWindow: requiresWindow,
        listingUrl: listingUrl,
        askAddress: askAddress,
        initialName: initialName,
        initialOpens: initialOpens,
        initialCloses: initialCloses,
      ),
    );

class _ManualStopForm extends StatefulWidget {
  const _ManualStopForm({
    this.address,
    required this.requiresWindow,
    this.listingUrl,
    required this.askAddress,
    this.initialName,
    this.initialOpens,
    this.initialCloses,
  });
  final String? address;
  final bool requiresWindow;
  final String? listingUrl;
  final bool askAddress;
  final String? initialName;
  final DateTime? initialOpens;
  final DateTime? initialCloses;

  @override
  State<_ManualStopForm> createState() => _ManualStopFormState();
}

class _ManualStopFormState extends State<_ManualStopForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _address = TextEditingController(text: widget.address);
  late DateTime _day;
  late TimeOfDay _open;
  late TimeOfDay _close;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final sat = now.add(Duration(days: (DateTime.saturday - now.weekday) % 7));
    _day = widget.initialOpens ?? DateTime(sat.year, sat.month, sat.day);
    _open = widget.initialOpens == null ? const TimeOfDay(hour: 7, minute: 0) : TimeOfDay.fromDateTime(widget.initialOpens!);
    _close = widget.initialCloses == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay.fromDateTime(widget.initialCloses!);
  }

  DateTime _at(TimeOfDay t) => DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.listingUrl != null ? 'Add from listing' : 'Name this stop', style: t.headlineSmall),
          if (widget.address != null && !widget.askAddress) ...[
            const SizedBox(height: Sp.s1),
            Text(widget.address!, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: Sp.s4),
          TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Name'), textCapitalization: TextCapitalization.words),
          if (widget.askAddress) ...[
            const SizedBox(height: Sp.s3),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address', hintText: 'Copy it from the listing')),
          ],
          if (widget.requiresWindow) ...[
            const SizedBox(height: Sp.s4),
            Text('When', style: t.titleMedium),
            const SizedBox(height: Sp.s2),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setState(() => _day = d);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat.MMMEd().format(_day)),
                ),
              ),
            ]),
            const SizedBox(height: Sp.s2),
            Row(children: [
              Expanded(child: _timeButton('Opens', _open, (v) => setState(() => _open = v))),
              const SizedBox(width: Sp.s2),
              Expanded(child: _timeButton('Closes', _close, (v) => setState(() => _close = v))),
            ]),
          ],
          const SizedBox(height: Sp.s5),
          KnButton(
            label: 'Add to draft',
            lime: true,
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                context,
                ManualStopResult(
                  name: name,
                  address: widget.askAddress ? _address.text.trim() : widget.address,
                  opensAt: widget.requiresWindow ? _at(_open) : null,
                  closesAt: widget.requiresWindow ? _at(_close) : null,
                  listingUrl: widget.listingUrl,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _timeButton(String label, TimeOfDay v, ValueChanged<TimeOfDay> on) => OutlinedButton(
        onPressed: () async {
          final r = await showTimePicker(context: context, initialTime: v);
          if (r != null) on(r);
        },
        child: Text('$label ${v.format(context)}'),
      );
}
