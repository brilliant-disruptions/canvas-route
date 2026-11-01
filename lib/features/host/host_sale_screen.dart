import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/logic/pin_labels.dart';
import '../../core/logic/sale_text.dart';
import '../../core/logic/errors.dart';
import '../../core/env.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../modes/mode_pack.dart';
import '../../data/services/storage_service.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/demand_state.dart';
import '../../state/location_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../../ui/widgets/xfile_image.dart';

/// Post a sale → live pin + share link + QR for the sign (spec §4.3).
class HostSaleScreen extends ConsumerStatefulWidget {
  const HostSaleScreen({super.key});
  @override
  ConsumerState<HostSaleScreen> createState() => _HostSaleScreenState();
}

class _HostSaleScreenState extends ConsumerState<HostSaleScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _day;
  TimeOfDay _open = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 13, minute: 0);
  final _cats = <String>{};
  String? _earlyBirds;
  final _photos = <XFile>[];
  bool _busy = false;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _day = nextSaleDay(DateTime.now(), closesHour: _close.hour);
  }

  /// Paste a post → filled form. Only what's found changes; the host reviews it all.
  Future<void> _pastePost() async {
    // Pre-fill from the clipboard when allowed; the box is editable either way.
    var clip = '';
    try {
      clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    } catch (_) {}
    if (!mounted) return;
    final text = await promptText(
      context,
      title: 'Paste your post',
      initial: clip,
      confirmLabel: 'Fill the form',
      multiline: true,
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    _fillFrom(text, keepAsNotes: true);
  }

  /// Reads the host's sign with the camera and fills the form from it.
  Future<void> _snapSign() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: StorageService.photoQuality,
      maxWidth: StorageService.photoMaxWidth,
    );
    if (x == null || !mounted) return;
    setState(() => _reading = true);
    try {
      final text = await ref.read(signReaderProvider).read(x);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        toast(context, 'Couldn\'t read the sign. Try closer, in good light.');
        return;
      }
      _fillFrom(text, keepAsNotes: false);
    } catch (e) {
      if (mounted) toast(context, 'Couldn\'t read the sign. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Fills whatever [text] reveals; only found fields change.
  void _fillFrom(String text, {required bool keepAsNotes}) {
    final pack = ref.read(modePackProvider);
    final d = parseSaleText(text, DateTime.now(), categoryKeywords: pack.community.categoryKeywords);
    if (d.filled == 0) {
      toast(context, 'Couldn\'t find sale details in that. Fill the form below instead.');
      return;
    }
    setState(() {
      if (d.name != null) _name.text = d.name!;
      if (d.address != null) _address.text = d.address!;
      if (d.day != null) _day = d.day!;
      if (d.opens case (final h, final m)) _open = TimeOfDay(hour: h, minute: m);
      if (d.closes case (final h, final m)) _close = TimeOfDay(hour: h, minute: m);
      _cats.addAll(d.categories.where(pack.community.categories.contains));
      if (d.earlyBirds != null) _earlyBirds = d.earlyBirds;
      if (keepAsNotes && _notes.text.trim().isEmpty) {
        _notes.text = text.trim().length > 500 ? '${text.trim().substring(0, 500)}…' : text.trim();
      }
    });
    HapticFeedback.mediumImpact();
    final missing = [if (d.address == null) 'address', if (d.day == null) 'day', if (d.opens == null) 'hours'];
    toast(
      context,
      missing.isEmpty ? 'Filled ${d.filled} fields. Check them, then publish.' : 'Filled ${d.filled} fields. Add the ${missing.join(' and ')}.',
      icon: Icons.auto_fix_high,
    );
  }

  Future<void> _publish() async {
    if (ref.read(isAnonymousProvider)) {
      context.push('/signin?reason=host');
      return;
    }
    final name = _name.text.trim();
    final addr = _address.text.trim();
    if (name.isEmpty || addr.isEmpty) {
      toast(context, 'Name and address are required');
      return;
    }
    final opens = DateTime(_day.year, _day.month, _day.day, _open.hour, _open.minute);
    final closes = DateTime(_day.year, _day.month, _day.day, _close.hour, _close.minute);
    if (saleWindowError(opens, closes, DateTime.now()) case final error?) {
      toast(context, error);
      return;
    }
    setState(() => _busy = true);
    try {
      final geo = await ref.read(placesServiceProvider).geocode(addr);
      if (geo == null) throw StateError('Couldn\'t find that address. Check it and try again.');
      final pin = await ref
          .read(pinRepoProvider)
          .createHosted(
            ownerId: ref.read(currentUserIdProvider)!,
            name: name,
            address: geo.formatted,
            lat: geo.lat,
            lng: geo.lng,
            opensAt: opens,
            closesAt: closes,
            categories: _cats.toList(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            earlyBirds: _earlyBirds,
            photos: _photos,
          );
      ref.invalidate(myPinsProvider);
      if (mounted) {
        await showShareSaleSheet(context, pin);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    return KnScaffold(
      title: 'Post your sale',
      bottom: KnButton(label: 'Publish & get my sign QR', lime: true, loading: _busy, onPressed: _publish),
      body: ListView(
        padding: const EdgeInsets.all(Sp.s4),
        children: [
          // Supply meets demand: hosts see that people near them are looking.
          if (pack.community.waitlistLabel != null) _WaitingBanner(pack: pack),
          // The fastest way in: most hosts already wrote this post somewhere.
          if (pack.community.categoryKeywords.isNotEmpty) ...[
            KnCard(
              tier: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: c.tertiary),
                      const SizedBox(width: Sp.s3),
                      Expanded(child: Text('Fill this in for me', style: t.titleSmall)),
                    ],
                  ),
                  const SizedBox(height: Sp.s1),
                  Text(
                    'Paste the post you already wrote, or snap the sign you made. You check everything before it goes live.',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: Sp.s2),
                  Wrap(
                    spacing: Sp.s2,
                    children: [
                      ActionChip(avatar: const Icon(Icons.content_paste_go, size: 18), label: const Text('Paste your post'), onPressed: _pastePost),
                      if (ref.watch(signReaderProvider).available)
                        ActionChip(
                          avatar: _reading
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.photo_camera_outlined, size: 18),
                          label: const Text('Snap your sign'),
                          onPressed: _reading ? null : _snapSign,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.s4),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Sale name', hintText: 'Multi-family yard sale'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: Sp.s3),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Address'),
            textCapitalization: TextCapitalization.words,
          ),
          const SectionHeader('When'),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 120)),
              );
              if (d != null) setState(() => _day = d);
            },
            icon: const Icon(Icons.event),
            label: Text(DateFormat.yMMMEd().format(_day)),
          ),
          const SizedBox(height: Sp.s2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final r = await showTimePicker(context: context, initialTime: _open);
                    if (r != null) setState(() => _open = r);
                  },
                  child: Text('Opens ${_open.format(context)}'),
                ),
              ),
              const SizedBox(width: Sp.s2),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final r = await showTimePicker(context: context, initialTime: _close);
                    if (r != null) setState(() => _close = r);
                  },
                  child: Text('Closes ${_close.format(context)}'),
                ),
              ),
            ],
          ),
          const SectionHeader('What you\'re selling'),
          Wrap(
            spacing: Sp.s2,
            runSpacing: Sp.s2,
            children: [
              for (final cat in pack.community.categories)
                FilterChip(
                  label: Text(cat),
                  selected: _cats.contains(cat),
                  onSelected: (v) => setState(() => v ? _cats.add(cat) : _cats.remove(cat)),
                ),
            ],
          ),
          const SizedBox(height: Sp.s3),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Cash only, furniture in the garage, no early birds…',
            ),
          ),
          const SectionHeader('Early birds'),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Either')),
              ButtonSegment(value: 'welcome', label: Text('Welcome')),
              ButtonSegment(value: 'not_welcome', label: Text('Please don\'t')),
            ],
            selected: {_earlyBirds},
            showSelectedIcon: false, // the check squeezed "No preference" onto three lines
            onSelectionChanged: (s) => setState(() => _earlyBirds = s.first),
          ),
          const SectionHeader('Photos'),
          Row(
            children: [
              for (final f in _photos)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.s2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Rad.lg),
                    child: XFileImage(f, width: 72, height: 72),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: StorageService.photoQuality,
                    maxWidth: StorageService.photoMaxWidth,
                  );
                  if (x != null) setState(() => _photos.add(x));
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: Sp.s3),
          Text(
            'Your address is shown to people planning routes this weekend and removed 14 days after the sale.',
            style: t.labelSmall?.copyWith(color: c.onSurfaceDisabled),
          ),
        ],
      ),
    );
  }
}

/// Public link for a hosted sale; the sign's QR encodes it.
String saleLink(Pin pin) => '${Env.webOrigin}/s/${pin.shareToken}';

Future<void> showShareSaleSheet(BuildContext context, Pin pin) {
  final link = saleLink(pin);
  return showKnSheet(
    context,
    builder: (ctx) {
      final c = ctx.kn;
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Sp.s5, 0, Sp.s5, Sp.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your sale is live', style: t.headlineSmall),
            const SizedBox(height: Sp.s2),
            Text(
              'Put this QR on your sign. Anyone who scans it gets the hours and a one-tap "add to route".',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Sp.s4),
            Container(
              padding: const EdgeInsets.all(Sp.s3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Rad.lg)),
              child: QrImageView(data: link, size: 200),
            ),
            const SizedBox(height: Sp.s3),
            SelectableText(link, style: t.labelMedium, textAlign: TextAlign.center),
            const SizedBox(height: Sp.s4),
            KnButton(
              label: 'Make a printable sign',
              icon: Icons.print_outlined,
              lime: true,
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/host/sign/${pin.id}');
              },
            ),
            const SizedBox(height: Sp.s2),
            Consumer(
              builder: (_, ref, _) => OutlinedButton.icon(
                onPressed: () => ref.read(shareServiceProvider).shareText('${pin.name} — $link', subject: pin.name),
                icon: const Icon(Icons.ios_share),
                label: const Text('Share link'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// "38 hunters near you are waiting for sales." Only shown once there's a crowd.
class _WaitingBanner extends ConsumerWidget {
  const _WaitingBanner({required this.pack});
  final ModePack pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final at = ref.watch(mapCenterProvider); // GPS, else home, else office
    final n = ref.watch(huntersWaitingProvider(demandKey(pack.id, at.lat, at.lng))).value ?? 0;
    if (n < 3) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s4),
      child: KnCard(
        tier: 3,
        accent: c.tertiary,
        child: Row(
          children: [
            Icon(Icons.groups_2_outlined, color: c.tertiary, size: 32),
            const SizedBox(width: Sp.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$n ${pack.community.noun} near you are waiting', style: t.titleMedium),
                  Text(
                    'Your ${pack.stopNoun} lands on their map the moment you publish. Free, always.',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
