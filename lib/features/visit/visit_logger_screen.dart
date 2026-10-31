import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/logic/errors.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/visit.dart';
import '../../data/models/visit_field.dart';
import '../../data/services/storage_service.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../state/visits_state.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../../ui/widgets/xfile_image.dart';
import '../community/product_picker.dart';

/// Renders the mode's visit fields dynamically; a re-log pre-fills and overwrites.
class VisitLoggerScreen extends ConsumerStatefulWidget {
  const VisitLoggerScreen({super.key, required this.routeId, required this.stopId});
  final String routeId;
  final String stopId;
  @override
  ConsumerState<VisitLoggerScreen> createState() => _VisitLoggerScreenState();
}

class _VisitLoggerScreenState extends ConsumerState<VisitLoggerScreen> {
  VisitDraft _draft = VisitDraft();
  final _controllers = <String, TextEditingController>{};
  XFile? _photo;
  bool _loaded = false;
  bool _saving = false;

  TextEditingController _ctrl(String key) => _controllers.putIfAbsent(key, () {
        final v = _draft.values[key];
        return TextEditingController(text: v == null ? '' : v.toString());
      });

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final route = ref.read(routeByIdProvider(widget.routeId));
    final stop = route?.stops.where((s) => s.id == widget.stopId).firstOrNull;
    if (route == null || stop == null) return;
    for (final e in _controllers.entries) {
      final text = e.value.text.trim();
      final def = ref.read(effectiveVisitFieldsProvider).where((f) => f.key == e.key).firstOrNull;
      _draft.values[e.key] = switch (def?.type) {
        FieldType.number => int.tryParse(text),
        FieldType.currency => double.tryParse(text),
        _ => text.isEmpty ? null : text,
      };
    }
    setState(() => _saving = true);
    try {
      final r = await ref.read(visitLoggerProvider).log(route: route, stop: stop, draft: _draft, photo: _photo);
      if (!mounted) return;
      context.pop();
      if (r.shared) toast(context, 'Shared with nearby ${ref.read(modePackProvider).communityNoun}', icon: Icons.campaign_outlined);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Couldn\'t save. ${friendlyError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final route = ref.watch(routeByIdProvider(widget.routeId));
    final stop = route?.stops.where((s) => s.id == widget.stopId).firstOrNull;
    final fields = ref.watch(effectiveVisitFieldsProvider).where((f) => f.enabled).toList();
    final outcomes = ref.watch(effectiveOutcomesProvider);
    final visits = ref.watch(visitsForRouteProvider(widget.routeId));
    final nav = ref.read(navLauncherProvider);

    if (route == null || stop == null) return const Scaffold(body: LoadingView());
    if (!_loaded && visits.hasValue) {
      final existing = visits.value!.where((v) => v.stopId == stop.id).firstOrNull;
      if (existing != null) _draft = VisitDraft.fromVisit(existing);
      _loaded = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stop.name, style: t.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(stop.address, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          for (final f in fields) ...[
            _field(f, outcomes, nav, pack.productCatalog),
            const SizedBox(height: Sp.s4),
          ],
          if (fields.isEmpty) const EmptyState(icon: Icons.tune, title: 'No visit fields enabled', body: 'Turn some on in Preferences → Advanced.'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, Sp.s4),
          child: KnButton(label: 'Save ${pack.visitVerb.split(' ').last.toLowerCase() == 'shelf' ? 'report' : 'visit'}', lime: true, loading: _saving, onPressed: _save),
        ),
      ),
    );
  }

  Widget _field(VisitFieldDefinition f, List<String> outcomes, dynamic nav, bool catalog) {
    final t = Theme.of(context).textTheme;
    final c = context.kn;
    switch (f.type) {
      case FieldType.selector:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: t.titleMedium),
          const SizedBox(height: Sp.s2),
          ChipRow(options: f.options.isNotEmpty ? f.options : outcomes, selected: _draft.values[f.key] as String?, onSelected: (v) => setState(() => _draft.values[f.key] = v)),
        ]);
      case FieldType.text:
        final isPhone = f.key == 'phone';
        final isEmail = f.key == 'email';
        return TextField(
          controller: _ctrl(f.key),
          keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          textCapitalization: isEmail || isPhone ? TextCapitalization.none : TextCapitalization.words,
          decoration: InputDecoration(
            labelText: f.label,
            hintText: f.hint,
            suffixIcon: isPhone || isEmail
                ? IconButton(
                    tooltip: isPhone ? 'Call' : 'Email',
                    icon: Icon(isPhone ? Icons.call_outlined : Icons.mail_outline),
                    onPressed: () {
                      final v = _ctrl(f.key).text.trim();
                      if (v.isEmpty) return;
                      isPhone ? nav.call(v) : nav.email(v);
                    },
                  )
                : null,
          ),
        );
      case FieldType.multiline:
        return TextField(controller: _ctrl(f.key), maxLines: 4, minLines: 2, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: f.label, hintText: f.hint, alignLabelWithHint: true));
      case FieldType.number:
        return TextField(controller: _ctrl(f.key), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: f.label, hintText: f.hint));
      case FieldType.currency:
        return TextField(controller: _ctrl(f.key), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: f.label, prefixText: '\$ ', hintText: f.hint));
      case FieldType.date:
        final v = _draft.values[f.key];
        final d = v is DateTime ? v : (v is String ? DateTime.tryParse(v) : null);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(f.label),
          subtitle: Text(d == null ? 'Not set' : DateFormat.yMMMEd().format(d)),
          trailing: d == null ? null : IconButton(tooltip: 'Clear date', icon: const Icon(Icons.clear), onPressed: () => setState(() => _draft.values[f.key] = null)),
          onTap: () async {
            final r = await showDatePicker(context: context, initialDate: d ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365 * 2)));
            if (r != null) setState(() => _draft.values[f.key] = r);
          },
        );
      case FieldType.toggle:
        return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), value: _draft.values[f.key] == true, onChanged: (v) => setState(() => _draft.values[f.key] = v));
      case FieldType.photo:
        final existing = _draft.values['photo'] as String?;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: t.titleMedium),
          const SizedBox(height: Sp.s2),
          Row(children: [
            if (_photo != null)
              ClipRRect(borderRadius: BorderRadius.circular(Rad.lg), child: XFileImage(_photo!, width: 96, height: 96))
            else if (existing != null)
              FutureBuilder(
                future: ref.read(storageServiceProvider).signedUrl(StorageService.visitPhotos, existing),
                builder: (_, s) => s.data == null
                    ? Container(width: 96, height: 96, decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Rad.lg)))
                    : ClipRRect(borderRadius: BorderRadius.circular(Rad.lg), child: Image.network(s.data!, width: 96, height: 96, fit: BoxFit.cover)),
              ),
            if (_photo != null || existing != null) const SizedBox(width: Sp.s3),
            OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
            const SizedBox(width: Sp.s2),
            OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Library')),
          ]),
          Text('No employee names or back-room photos.', style: t.labelSmall?.copyWith(color: c.onSurfaceDisabled)),
        ]);
      case FieldType.productMulti:
        final v = (_draft.values[f.key] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const <Map<String, dynamic>>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: t.titleMedium),
          const SizedBox(height: Sp.s2),
          ProductMultiField(value: v, onChanged: (list) => setState(() => _draft.values[f.key] = list)),
        ]);
    }
  }

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 80, maxWidth: 1600);
    if (x != null) setState(() => _photo = x);
  }
}
