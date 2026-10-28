import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import 'kn_widgets.dart';

/// One stop on a spotlight tour: the widget to light up and what to say.
class SpotlightStep {
  const SpotlightStep({required this.target, required this.title, required this.body, this.radius = Rad.xl});

  /// Put this key on the widget to light up. A step whose target isn't on
  /// screen is left out.
  final GlobalKey target;
  final String title;
  final String body;
  final double radius;
}

/// Dims the screen and lights up one thing at a time with a caption. Tap
/// anywhere (or Next) to go on; Skip or back ends it. Resolves to true if
/// they saw every stop.
Future<bool> showSpotlight(BuildContext context, List<SpotlightStep> steps) async {
  final shown = steps.where((s) => _rectOf(s.target) != null).toList();
  if (shown.isEmpty) return true;
  final done = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: false,
      barrierLabel: 'Tour',
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => _Spotlight(shown),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
  return done ?? false;
}

Rect? _rectOf(GlobalKey k) {
  final box = k.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _Spotlight extends StatefulWidget {
  const _Spotlight(this.steps);
  final List<SpotlightStep> steps;
  @override
  State<_Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<_Spotlight> {
  int _i = 0;
  Rect? _seen;

  // Targets can still be moving (a banner sliding in, a sheet settling): follow them.
  late final Timer _follow = Timer.periodic(const Duration(milliseconds: 200), (_) {
    final r = _rectOf(widget.steps[_i].target);
    if (mounted && r != _seen) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _follow;
  }

  @override
  void dispose() {
    _follow.cancel();
    super.dispose();
  }

  void _next() {
    if (_i == widget.steps.length - 1) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final step = widget.steps[_i];
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    _seen = _rectOf(step.target);
    final hole = (_seen ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)).inflate(Sp.s1 + 2);
    final still = MediaQuery.disableAnimationsOf(context);
    final last = _i == widget.steps.length - 1;
    final scrim = Theme.of(context).colorScheme.scrim.withValues(alpha: context.isDark ? 0.78 : 0.62);
    final card = _Caption(
      count: '${_i + 1} of ${widget.steps.length}',
      title: step.title,
      body: step.body,
      last: last,
      onNext: _next,
      onSkip: () => Navigator.of(context).pop(false),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: ExcludeSemantics(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: hole),
                  duration: still ? Duration.zero : const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  builder: (_, r, _) => CustomPaint(painter: _Dim(r ?? hole, step.radius, scrim, c.tertiary)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _CaptionPlace(hole, pad),
              child: AnimatedSwitcher(
                duration: still ? Duration.zero : const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_i), child: card),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Puts the caption just below the lit-up thing if it fits, else just above,
/// else at the bottom of the screen.
class _CaptionPlace extends SingleChildLayoutDelegate {
  _CaptionPlace(this.hole, this.pad);
  final Rect hole;
  final EdgeInsets pad;
  static const gap = Sp.s3, side = Sp.s4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: c.maxWidth - 2 * side,
    minWidth: c.maxWidth - 2 * side,
    maxHeight: c.maxHeight - pad.vertical - Sp.s4,
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final top = pad.top + Sp.s2, bottom = size.height - pad.bottom - Sp.s2;
    final below = hole.bottom + gap, above = hole.top - gap - child.height;
    final y = below + child.height <= bottom
        ? below
        : above >= top
        ? above
        : bottom - child.height;
    return Offset(side, y);
  }

  @override
  bool shouldRelayout(_CaptionPlace old) => old.hole != hole || old.pad != pad;
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.count,
    required this.title,
    required this.body,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });
  final String count, title, body;
  final bool last;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.s5, Sp.s4, Sp.s4, Sp.s4),
        decoration: BoxDecoration(
          color: c.surfaceHighest,
          borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: c.ghostBorder),
          boxShadow: [
            BoxShadow(color: c.primaryDim.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: t.labelMedium?.copyWith(color: c.tertiary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Sp.s1),
            Text(title, style: t.headlineSmall),
            const SizedBox(height: Sp.s1),
            Text(body, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Sp.s4),
            Row(
              children: [
                if (!last) TextButton(onPressed: onSkip, child: const Text('Skip')),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: KnButton(label: last ? 'Got it' : 'Next', lime: last, compact: true, onPressed: onNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dim extends CustomPainter {
  _Dim(this.hole, this.radius, this.scrim, this.ring);
  final Rect hole;
  final double radius;
  final Color scrim, ring;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    final shade = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(r));
    canvas.drawPath(shade, Paint()..color = scrim);
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_Dim old) => old.hole != hole || old.radius != radius || old.scrim != scrim || old.ring != ring;
}
