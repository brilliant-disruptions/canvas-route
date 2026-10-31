import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/kn_theme.dart';

/// A branded map marker: a numbered route dot or a labeled pill.
/// Rendered once to PNG and cached; [key] is the cache identity.
class PinSpec {
  /// Route-order dot. [done] draws a check instead of the number.
  const PinSpec.number(this.number, {required this.fill, required this.ink, this.done = false})
    : label = null,
      border = null,
      halo = false,
      dot = null;

  /// Labeled pill with a pointer. [halo] marks a live signal; [dot] leads the label.
  const PinSpec.pill(
    String this.label, {
    required this.fill,
    required this.ink,
    this.border,
    this.halo = false,
    this.dot,
  }) : number = null,
       done = false;

  final int? number;
  final String? label;
  final Color fill;
  final Color ink;
  final Color? border;
  final bool halo;
  final Color? dot;
  final bool done;

  bool get isNumber => number != null;

  /// Where the marker's point sits: dot centers, pills point down.
  Offset get anchor => isNumber ? const Offset(0.5, 0.5) : const Offset(0.5, 1);

  String get key =>
      [number, label, fill.toARGB32(), ink.toARGB32(), border?.toARGB32(), halo, dot?.toARGB32(), done].join('|');
}

/// Renders and caches [PinSpec]s. Rendering is async; [get] returns null until
/// the icon is ready and calls [onReady] once it is.
class PinIcons {
  final _cache = <String, BitmapDescriptor>{};
  final _pending = <String>{};

  BitmapDescriptor? get(PinSpec spec, double pixelRatio, VoidCallback onReady) {
    final key = '${spec.key}@$pixelRatio';
    final hit = _cache[key];
    if (hit != null || !_pending.add(key)) return hit;
    _render(spec, pixelRatio).then((bytes) {
      _cache[key] = BitmapDescriptor.bytes(bytes, imagePixelRatio: pixelRatio);
      _pending.remove(key);
      onReady();
    });
    return null;
  }

  static Future<Uint8List> _render(PinSpec s, double dpr) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(dpr);
    final Size size = s.isNumber ? _paintNumber(canvas, s) : _paintPill(canvas, s);
    final image = await rec.endRecording().toImage((size.width * dpr).ceil(), (size.height * dpr).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static TextPainter _text(String text, Color color, double size) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: FontWeight.w800, color: color, height: 1),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  static const _shadow = Color(0x66000000);

  static Size _paintNumber(Canvas canvas, PinSpec s) {
    const d = 30.0, pad = 4.0;
    const c = Offset(d / 2 + pad, d / 2 + pad);
    canvas.drawCircle(
      c + const Offset(0, 1.5),
      d / 2,
      Paint()
        ..color = _shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(c, d / 2, Paint()..color = Colors.white);
    canvas.drawCircle(c, d / 2 - 2.5, Paint()..color = s.fill);
    if (s.done) {
      final p = Path()
        ..moveTo(c.dx - 6, c.dy)
        ..lineTo(c.dx - 1.5, c.dy + 4.5)
        ..lineTo(c.dx + 6.5, c.dy - 4.5);
      canvas.drawPath(
        p,
        Paint()
          ..color = s.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final tp = _text('${s.number}', s.ink, s.number! > 9 ? 12 : 14);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    return const Size(d + pad * 2, d + pad * 2);
  }

  static Size _paintPill(Canvas canvas, PinSpec s) {
    const h = 26.0, padX = 10.0, pointer = 6.0, dotD = 7.0;
    final halo = s.halo ? 6.0 : 2.0;
    final tp = _text(s.label!, s.ink, 12);
    final w = tp.width + padX * 2 + (s.dot != null ? dotD + 6 : 0);
    final pill = RRect.fromRectAndRadius(Rect.fromLTWH(halo, halo, w, h), const Radius.circular(h / 2));

    if (s.halo) {
      canvas.drawRRect(pill.inflate(halo - 1), Paint()..color = s.fill.withValues(alpha: 0.28));
    }
    canvas.drawRRect(
      pill.shift(const Offset(0, 1.5)),
      Paint()
        ..color = _shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    final tip = Path()
      ..moveTo(halo + w / 2 - pointer, halo + h - 1)
      ..lineTo(halo + w / 2, halo + h + pointer)
      ..lineTo(halo + w / 2 + pointer, halo + h - 1)
      ..close();
    final fill = Paint()..color = s.fill;
    canvas.drawPath(tip, fill);
    canvas.drawRRect(pill, fill);
    if (s.border != null) {
      canvas.drawRRect(
        pill.deflate(0.75),
        Paint()
          ..color = s.border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    var x = halo + padX;
    if (s.dot != null) {
      canvas.drawCircle(Offset(x + dotD / 2, halo + h / 2), dotD / 2, Paint()..color = s.dot!);
      x += dotD + 6;
    }
    tp.paint(canvas, Offset(x, halo + (h - tp.height) / 2));
    return Size(w + halo * 2, halo + h + pointer + 2);
  }
}

/// Gives a screen a [PinIcons] cache that rebuilds it as icons finish rendering.
mixin PinIconsMixin<T extends StatefulWidget> on State<T> {
  final _pinIcons = PinIcons();

  /// Null until rendered; hide the marker until then rather than flash a default pin.
  BitmapDescriptor? pinIcon(PinSpec spec) =>
      _pinIcons.get(spec, MediaQuery.devicePixelRatioOf(context), () => mounted ? setState(() {}) : null);
}
