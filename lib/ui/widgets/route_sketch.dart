import 'package:flutter/material.dart';

import '../../core/logic/recap.dart';

enum SketchStop { pending, visited, win }

/// A route drawn as a line through its stops, north up; wins glow.
/// [scale] sizes the dots and line for thumbnails (1 = recap card size).
class RouteSketch extends StatelessWidget {
  const RouteSketch({
    super.key,
    required this.points,
    required this.stops,
    required this.line,
    required this.win,
    required this.visited,
    required this.pending,
    this.scale = 1,
  });

  final List<({double lat, double lng})> points;
  final List<SketchStop> stops;
  final Color line;
  final Color win;
  final Color visited;
  final Color pending;
  final double scale;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _Painter(this));
}

class _Painter extends CustomPainter {
  _Painter(this.w);
  final RouteSketch w;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = fitPoints(w.points, size.width, size.height, pad: 14 * w.scale).map((p) => Offset(p.x, p.y)).toList();
    if (pts.isEmpty) return;
    if (pts.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(pts, false),
        Paint()
          ..color = w.line.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * w.scale
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < pts.length; i++) {
      final s = w.stops[i];
      if (s == SketchStop.win) canvas.drawCircle(pts[i], 13 * w.scale, Paint()..color = w.win.withValues(alpha: 0.25));
      canvas.drawCircle(
        pts[i],
        7 * w.scale,
        Paint()
          ..color = switch (s) {
            SketchStop.win => w.win,
            SketchStop.visited => w.visited,
            SketchStop.pending => w.pending,
          },
      );
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.w.points != w.points || old.w.stops != w.stops;
}
