import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/errors.dart';
import '../../core/logic/pin_labels.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../data/models/report.dart';
import '../../modes/mode_pack.dart';
import '../../state/auth_state.dart';
import '../../state/community_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';

/// "At Moving sale? Still going?" when you're standing at an open listing. One tap
/// files a report on the listing (never your location) and keeps the live map
/// honest for everyone still deciding where to drive.
class CheckInBanner extends ConsumerStatefulWidget {
  const CheckInBanner({super.key, required this.pack, required this.pin, required this.onDone});
  final ModePack pack;
  final Pin pin;

  /// Called after an answer or a dismissal, so the map stops asking today.
  final VoidCallback onDone;

  @override
  ConsumerState<CheckInBanner> createState() => _CheckInBannerState();
}

class _CheckInBannerState extends ConsumerState<CheckInBanner> {
  String? _sending;

  Future<void> _answer(ReportStatusOption s) async {
    setState(() => _sending = s.value);
    try {
      await ref.read(reportRepoProvider).create(ReportDraft(pinId: widget.pin.id, status: s.value), ref.read(currentUserIdProvider)!);
      ref.invalidate(latestReportsProvider);
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, 'Thanks. ${widget.pack.communityNoun[0].toUpperCase()}${widget.pack.communityNoun.substring(1)} nearby can see it.', icon: Icons.check);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = null);
        toast(context, friendlyError(e, denied: 'You can report a place 3 times an hour.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return KnCard(
      tier: 3,
      accent: c.tertiary,
      padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s3, Sp.s2, Sp.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: c.tertiary, size: 20),
              const SizedBox(width: Sp.s2),
              Expanded(
                child: Text('At ${shortPlaceName(widget.pin.name, max: 28)}? Is it still going?', style: t.titleSmall),
              ),
              IconButton(
                tooltip: 'Not now',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onDone,
              ),
            ],
          ),
          Wrap(
            spacing: Sp.s2,
            children: [
              for (final s in widget.pack.reportStatuses)
                ActionChip(
                  avatar: _sending == s.value
                      ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(s.icon, size: 16),
                  label: Text(s.label),
                  onPressed: _sending == null ? () => _answer(s) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
