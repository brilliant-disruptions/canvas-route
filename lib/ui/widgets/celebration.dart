import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A one-shot burst of particles from the upper middle of its area.
/// Seeded, so the same finish looks the same in screenshots and tests.
class Celebration extends StatefulWidget {
  const Celebration({super.key, required this.colors, this.play = true, this.seed = 7});
  final List<Color> colors;
  final bool play;
  final int seed;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _particles = [
      for (var i = 0; i < 48; i++)
        _Particle(
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.4,
          speed: 220 + r.nextDouble() * 260,
          size: 4 + r.nextDouble() * 5,
          spin: (r.nextDouble() - 0.5) * 12,
          color: widget.colors[i % widget.colors.length],
          square: r.nextBool(),
        ),
    ];
    if (widget.play) _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) => CustomPaint(size: Size.infinite, painter: _BurstPainter(_particles, _ctl.value)),
    ),
  );
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
    required this.square,
  });
  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
  final bool square;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final origin = Offset(size.width / 2, size.height * 0.28);
    const gravity = 520.0;
    final secs = t * 1.6;
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final p in particles) {
      final pos =
          origin +
          Offset(math.cos(p.angle) * p.speed * secs, math.sin(p.angle) * p.speed * secs + 0.5 * gravity * secs * secs);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * secs);
      if (p.square) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
