import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/logic/pin_labels.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/pin.dart';
import '../../modes/registry.dart';
import '../../state/community_state.dart';
import '../../state/providers.dart';
import '../../ui/widgets/kn_widgets.dart';
import 'host_sale_screen.dart';

/// Preview and share a print-ready sign for a hosted sale. Every printed sign
/// carries a QR that opens the sale in CanvasRoute.
class SaleSignScreen extends ConsumerStatefulWidget {
  const SaleSignScreen({super.key, required this.pinId});
  final String pinId;
  @override
  ConsumerState<SaleSignScreen> createState() => _SaleSignScreenState();
}

class _SaleSignScreenState extends ConsumerState<SaleSignScreen> {
  final _signKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(Pin pin) async {
    setState(() => _sharing = true);
    try {
      final boundary = _signKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 600×800 logical at 4× is 2400×3200 px: 8×10.7 in at 300 dpi.
      final image = await boundary.toImage(pixelRatio: 4);
      final png = (await image.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
      await ref.read(shareServiceProvider).shareImage(png, 'yard-sale-sign.png', subject: pin.name);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pin = ref.watch(pinByIdProvider(widget.pinId));
    return KnScaffold(
      title: 'Your sign',
      body: AsyncView(
        value: pin,
        data: (p) {
          if (p == null) return const EmptyState(icon: Icons.sell_outlined, title: 'Sale not found');
          return ListView(
            padding: const EdgeInsets.all(Sp.s4),
            children: [
              Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _signKey,
                    child: SaleSign(pin: p, headline: packFor(p.mode).community.signHeadline, link: saleLink(p)),
                  ),
                ),
              ),
              const SizedBox(height: Sp.s3),
              Text(
                'Print it letter-size, or share it to your neighborhood group. Scanning the code shows your hours and adds your sale to their route.',
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.s4),
              KnButton(
                label: 'Share or print',
                icon: Icons.ios_share,
                lime: true,
                loading: _sharing,
                onPressed: () => _share(p),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The sign itself: built for a lawn at 20 feet, so black on white with one
/// lime band, not the app's dark theme.
class SaleSign extends StatelessWidget {
  const SaleSign({super.key, required this.pin, required this.headline, required this.link});
  final Pin pin;
  final String headline;
  final String link;

  static const size = Size(600, 800);

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0E0E0E);
    const paper = Colors.white;
    final lime = KnColors.dark.tertiary;
    final t = Theme.of(context).textTheme;
    TextStyle s(double size, FontWeight w, {Color color = ink, double ls = 0}) => (t.bodyLarge ?? const TextStyle())
        .copyWith(fontSize: size, fontWeight: w, color: color, height: 1.0, letterSpacing: ls);

    final opens = pin.opensAt;
    final when = opens == null
        ? null
        : '${DateFormat.E().format(opens).toUpperCase()} ${signWindow(opens, pin.closesAt)}';

    return SizedBox.fromSize(
      size: size,
      child: ColoredBox(
        color: paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: lime,
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(headline, style: s(112, FontWeight.w900, ls: -4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (when != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(when, style: s(64, FontWeight.w900, ls: -2)),
                    ),
                  if (opens != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.MMMMd().format(opens),
                      style: s(30, FontWeight.w700, color: const Color(0xFF555555)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (pin.address != null)
                    Text(
                      pin.address!.split(',').first,
                      style: s(36, FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (pin.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      pin.categories.join(' · '),
                      style: s(26, FontWeight.w600, color: const Color(0xFF555555)),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.fromLTRB(36, 0, 36, 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: ink, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  QrImageView(data: link, size: 168, padding: EdgeInsets.zero),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan for hours\n& directions', style: s(30, FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text(
                          'Add this sale to your route',
                          style: s(20, FontWeight.w600, color: const Color(0xFF555555)),
                        ),
                        const SizedBox(height: 14),
                        Text('CanvasRoute', style: s(22, FontWeight.w900)),
                      ],
                    ),
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
