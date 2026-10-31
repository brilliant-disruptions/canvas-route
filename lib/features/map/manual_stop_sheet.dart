import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../../ui/widgets/xfile_image.dart';

class ManualStopResult {
  const ManualStopResult({
    required this.name,
    this.address,
    this.opensAt,
    this.closesAt,
    this.listingUrl,
    this.signPhoto,
    this.categories = const [],
  });
  final String name;
  final String? address;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final String? listingUrl;

  /// Set when the user chose to share the stop with the community.
  final XFile? signPhoto;
  final List<String> categories;

  bool get share => signPhoto != null;
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
  String? shareLabel,
  List<String> categories = const [],
  String? confirmLabel,
}) => showKnSheet<ManualStopResult>(
  context,
  builder: (_) => _ManualStopForm(
    address: address,
    requiresWindow: requiresWindow,
    listingUrl: listingUrl,
    askAddress: askAddress,
    initialName: initialName,
    initialOpens: initialOpens,
    initialCloses: initialCloses,
    shareLabel: shareLabel,
    categories: categories,
    confirmLabel: confirmLabel,
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
    this.shareLabel,
    this.categories = const [],
    this.confirmLabel,
  });
  final String? address;
  final bool requiresWindow;
  final String? listingUrl;
  final bool askAddress;
  final String? initialName;
  final DateTime? initialOpens;
  final DateTime? initialCloses;

  /// Offers sharing as a community pin; null hides it.
  final String? shareLabel;
  final List<String> categories;
  final String? confirmLabel;

  @override
  State<_ManualStopForm> createState() => _ManualStopFormState();
}

class _ManualStopFormState extends State<_ManualStopForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _address = TextEditingController(text: widget.address);
  late DateTime _day;
  late TimeOfDay _open;
  late TimeOfDay _close;
  late bool _share = widget.shareLabel != null;
  XFile? _sign;
  final _cats = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final sat = now.add(Duration(days: (DateTime.saturday - now.weekday) % 7));
    _day = widget.initialOpens ?? DateTime(sat.year, sat.month, sat.day);
    _open = widget.initialOpens == null
        ? const TimeOfDay(hour: 7, minute: 0)
        : TimeOfDay.fromDateTime(widget.initialOpens!);
    _close = widget.initialCloses == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : TimeOfDay.fromDateTime(widget.initialCloses!);
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
          Text(
            widget.listingUrl != null ? 'Add from listing' : (_share ? 'Spot a sale' : 'Name this stop'),
            style: t.headlineSmall,
          ),
          if (widget.address != null && !widget.askAddress) ...[
            const SizedBox(height: Sp.s1),
            Text(widget.address!, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: Sp.s4),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          if (widget.askAddress) ...[
            const SizedBox(height: Sp.s3),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address', hintText: 'Copy it from the listing'),
            ),
          ],
          if (widget.requiresWindow) ...[
            const SizedBox(height: Sp.s4),
            Text('When', style: t.titleMedium),
            const SizedBox(height: Sp.s2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _day,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (d != null) setState(() => _day = d);
                    },
                    icon: const Icon(Icons.event),
                    label: Text(DateFormat.MMMEd().format(_day)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.s2),
            Row(
              children: [
                Expanded(child: _timeButton('Opens', _open, (v) => setState(() => _open = v))),
                const SizedBox(width: Sp.s2),
                Expanded(child: _timeButton('Closes', _close, (v) => setState(() => _close = v))),
              ],
            ),
          ],
          if (widget.shareLabel != null) ...[
            const SizedBox(height: Sp.s3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.shareLabel!),
              subtitle: const Text('Needs a photo of the sign. Shown to others after a quick check.'),
              value: _share,
              onChanged: (v) => setState(() => _share = v),
            ),
            if (_share) ...[
              Row(
                children: [
                  if (_sign != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Rad.lg),
                      child: XFileImage(_sign!, width: 64, height: 64),
                    ),
                    const SizedBox(width: Sp.s3),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                          maxWidth: 1600,
                        );
                        if (x != null) setState(() => _sign = x);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_sign == null ? 'Snap the sign' : 'Retake'),
                    ),
                  ),
                ],
              ),
              if (widget.categories.isNotEmpty) ...[
                const SizedBox(height: Sp.s3),
                Wrap(
                  spacing: Sp.s2,
                  runSpacing: Sp.s2,
                  children: [
                    for (final cat in widget.categories)
                      FilterChip(
                        label: Text(cat),
                        selected: _cats.contains(cat),
                        onSelected: (v) => setState(() => v ? _cats.add(cat) : _cats.remove(cat)),
                      ),
                  ],
                ),
              ],
            ],
          ],
          const SizedBox(height: Sp.s5),
          KnButton(
            label: widget.confirmLabel ?? (_share ? 'Share and add to route' : 'Add to route'),
            lime: true,
            // Sharing needs the sign photo; turn sharing off to add it privately.
            onPressed: _share && _sign == null
                ? null
                : () {
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
                        signPhoto: _share ? _sign : null,
                        categories: _share ? _cats.toList() : const [],
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
    // One line even for "Closes 12:00 PM" in a half-width button.
    child: FittedBox(fit: BoxFit.scaleDown, child: Text('$label ${v.format(context)}', maxLines: 1)),
  );
}
