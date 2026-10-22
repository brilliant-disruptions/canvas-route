import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show PlatformViewCreatedCallback;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../core/theme/kn_theme.dart';

/// Stands in for Google Maps in the demo build: draws a stylized Dallas street
/// grid, the app's real markers and polylines, and supports pan, zoom, pin taps
/// and long-press. No network, no API key.
class DemoMapsPlatform extends GoogleMapsFlutterPlatform {
  DemoMapsPlatform({required this.myLocation});
  final LatLng myLocation;

  @override
  Future<void> init(int mapId) async {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) =>
      _DemoMap(
        key: ValueKey('demo-map-$creationId'),
        initial: widgetConfiguration.initialCameraPosition,
        objects: mapObjects,
        config: mapConfiguration,
        myLocation: myLocation,
      );
}

class _DemoMap extends StatefulWidget {
  const _DemoMap({super.key, required this.initial, required this.objects, required this.config, required this.myLocation});
  final CameraPosition initial;
  final MapObjects objects;
  final MapConfiguration config;
  final LatLng myLocation;

  @override
  State<_DemoMap> createState() => _DemoMapState();
}

class _Projection {
  _Projection(this.center, this.zoom, this.size, this.padding);
  final LatLng center;
  final double zoom;
  final Size size;
  final EdgeInsets padding;

  double get world => 256 * math.pow(2, zoom).toDouble();
  static double nx(double lng) => (lng + 180) / 360;
  static double ny(double lat) {
    final s = math.sin(lat.clamp(-85, 85) * math.pi / 180);
    return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
  }

  Offset get origin => Offset(
        padding.left + (size.width - padding.horizontal) / 2,
        padding.top + (size.height - padding.vertical) / 2,
      );

  Offset toScreen(LatLng p) =>
      origin + Offset((nx(p.longitude) - nx(center.longitude)) * world, (ny(p.latitude) - ny(center.latitude)) * world);

  LatLng toLatLng(Offset o) {
    final x = nx(center.longitude) + (o.dx - origin.dx) / world;
    final y = ny(center.latitude) + (o.dy - origin.dy) / world;
    final lng = x * 360 - 180;
    final n = math.pi - 2 * math.pi * y;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return LatLng(lat, lng);
  }
}

class _DemoMapState extends State<_DemoMap> {
  late LatLng _center = widget.initial.target;
  late double _zoom = widget.initial.zoom;
  double _startZoom = 0;
  bool _needsFit = false;
  Size _size = Size.zero;

  bool get _gestures => widget.config.scrollGesturesEnabled ?? true;
  bool get _lite => widget.config.liteModeEnabled ?? false;

  @override
  void initState() {
    super.initState();
    _needsFit = _lite && widget.objects.markers.length > 1;
  }

  @override
  void didUpdateWidget(covariant _DemoMap old) {
    super.didUpdateWidget(old);
    final before = old.objects.markers.map((m) => m.markerId).toSet();
    final added = widget.objects.markers.where((m) => !before.contains(m.markerId)).toList();
    if (added.isEmpty || _size == Size.zero) return;
    if (_lite) {
      _needsFit = true;
      return;
    }
    // New search results off screen: bring everything into view, like the real app's camera fit.
    final p = _proj(_size);
    final view = (Offset.zero & _size).deflate(24);
    if (added.any((m) => !view.contains(p.toScreen(m.position)))) _needsFit = true;
  }

  _Projection _proj(Size size) => _Projection(_center, _zoom, size, widget.config.padding ?? EdgeInsets.zero);

  void _fit(Size size) {
    final pts = widget.objects.markers.map((m) => m.position).toList();
    if (pts.isEmpty) return;
    final lats = pts.map((p) => p.latitude), lngs = pts.map((p) => p.longitude);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    _center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    if (pts.length == 1) {
      _zoom = 14;
      return;
    }
    final pad = widget.config.padding ?? EdgeInsets.zero;
    final w = size.width - pad.horizontal - 72, h = size.height - pad.vertical - 96;
    final dx = (_Projection.nx(maxLng) - _Projection.nx(minLng)) * 256;
    final dy = (_Projection.ny(minLat) - _Projection.ny(maxLat)) * 256;
    final zx = dx <= 0 ? 16.0 : math.log(w / dx) / math.ln2;
    final zy = dy <= 0 ? 16.0 : math.log(h / dy) / math.ln2;
    _zoom = math.min(zx, zy).clamp(9.0, 16.0);
  }

  GoogleMap? get _host => context.findAncestorWidgetOfExactType<GoogleMap>();

  List<Marker> get _sortedMarkers =>
      widget.objects.markers.toList()..sort((a, b) => b.position.latitude.compareTo(a.position.latitude));

  Marker? _hit(Offset pos) {
    final p = _proj(_size);
    for (final m in _sortedMarkers.reversed) {
      final o = p.toScreen(m.position);
      if (Rect.fromLTRB(o.dx - 18, o.dy - 44, o.dx + 18, o.dy + 6).contains(pos)) return m;
    }
    return null;
  }

  void _zoomBy(double delta, Offset focal) {
    final p = _proj(_size);
    final before = p.toLatLng(focal);
    setState(() {
      _zoom = (_zoom + delta).clamp(3.0, 19.0);
      final after = _proj(_size).toLatLng(focal);
      _center = LatLng(_center.latitude + before.latitude - after.latitude, _center.longitude + before.longitude - after.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      _size = size;
      if (_needsFit) {
        _fit(size);
        _needsFit = false;
      }
      final painter = _MapPainter(_proj(size), _sortedMarkers, widget.objects.polylines,
          (widget.config.myLocationEnabled ?? false) ? widget.myLocation : null);
      final map = CustomPaint(painter: painter, size: size);
      return Listener(
        onPointerSignal: (e) {
          if (!_gestures || e is! PointerScrollEvent) return;
          GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
            _zoomBy(-(ev as PointerScrollEvent).scrollDelta.dy / 300, ev.localPosition);
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final m = _hit(d.localPosition);
            if (m != null) {
              m.onTap?.call();
            } else {
              _host?.onTap?.call(_proj(size).toLatLng(d.localPosition));
            }
          },
          onLongPressStart: (d) => _host?.onLongPress?.call(_proj(size).toLatLng(d.localPosition)),
          onDoubleTapDown: _gestures ? (d) => _zoomBy(1, d.localPosition) : null,
          onDoubleTap: _gestures ? () {} : null,
          onScaleStart: _gestures ? (_) => _startZoom = _zoom : null,
          onScaleUpdate: _gestures
              ? (d) {
                  setState(() {
                    if (d.pointerCount > 1) {
                      _zoom = (_startZoom + math.log(d.scale) / math.ln2).clamp(3.0, 19.0);
                    }
                    final p = _proj(size);
                    final moved = p.toLatLng(p.origin - d.focalPointDelta);
                    _center = moved;
                  });
                }
              : null,
          child: ClipRect(child: map),
        ),
      );
    });
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.p, this.markers, this.polylines, this.me);
  final _Projection p;
  final List<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng? me;

  static const _bg = Color(0xFFEDEAE3);
  static const _park = Color(0xFFCFE6C3);
  static const _water = Color(0xFFA9D3F2);
  static const _street = Color(0xFFFFFFFF);
  static const _streetEdge = Color(0xFFDCD5C8);
  static const _arterial = Color(0xFFFFF1C6);
  static const _highway = Color(0xFFF6C66E);
  static const _label = Color(0xFF7C7568);

  static const _lake = [
    LatLng(32.8475, -96.7290), LatLng(32.8440, -96.7175), LatLng(32.8340, -96.7130), LatLng(32.8240, -96.7155),
    LatLng(32.8180, -96.7230), LatLng(32.8230, -96.7310), LatLng(32.8330, -96.7330), LatLng(32.8420, -96.7340),
  ];
  static const _highways = [
    [LatLng(32.775, -96.800), LatLng(32.800, -96.798), LatLng(32.830, -96.790), LatLng(32.870, -96.772), LatLng(32.930, -96.765)],
    [LatLng(32.776, -96.900), LatLng(32.776, -96.780), LatLng(32.785, -96.720), LatLng(32.795, -96.640)],
    [LatLng(32.866, -96.900), LatLng(32.866, -96.800), LatLng(32.860, -96.740), LatLng(32.840, -96.690)],
  ];
  static const _places = [
    ('UPTOWN', LatLng(32.800, -96.802)), ('LAKEWOOD', LatLng(32.822, -96.748)), ('LOWER GREENVILLE', LatLng(32.812, -96.770)),
    ('DEEP ELLUM', LatLng(32.784, -96.781)), ('PRESTON HOLLOW', LatLng(32.872, -96.812)), ('KNOX-HENDERSON', LatLng(32.820, -96.790)),
    ('WHITE ROCK LAKE', LatLng(32.832, -96.722)), ('M STREETS', LatLng(32.832, -96.772)), ('LOVE FIELD', LatLng(32.846, -96.850)),
    ('OAK LAWN', LatLng(32.812, -96.820)), ('UNIVERSITY PARK', LatLng(32.850, -96.795)),
  ];

  int _hash(int a, int b) => ((a * 73856093) ^ (b * 19349663)) & 0x7fffffff;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    final nw = p.toLatLng(Offset.zero), se = p.toLatLng(Offset(size.width, size.height));
    final z = p.zoom;

    // Parks on a coarse grid, decided by a stable hash so they don't move.
    const cell = 0.012;
    for (var i = (se.latitude / cell).floor(); i <= (nw.latitude / cell).ceil(); i++) {
      for (var j = (nw.longitude / cell).floor(); j <= (se.longitude / cell).ceil(); j++) {
        final hsh = _hash(i, j);
        if (hsh % 6 != 0) continue;
        final a = p.toScreen(LatLng((i + 0.22 + (hsh % 7) / 40) * cell, (j + 0.2) * cell));
        final b = p.toScreen(LatLng((i + 0.78) * cell, (j + 0.72 + (hsh % 5) / 40) * cell));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(a, b), Radius.circular(z > 13 ? 10 : 4)), Paint()..color = _park);
      }
    }
    final lake = Path()..addPolygon(_lake.map(p.toScreen).toList(), true);
    canvas.drawPath(lake, Paint()..color = _water);

    // Street grid, density by zoom.
    final step = z >= 14.5 ? 0.0025 : z >= 13 ? 0.005 : z >= 11.5 ? 0.01 : 0.02;
    final w = (z - 10).clamp(1.0, 5.0);
    final edge = Paint()..color = _streetEdge..strokeWidth = w + 1.5;
    final street = Paint()..color = _street..strokeWidth = w;
    final art = Paint()..color = _arterial..strokeWidth = w + 3;
    final artEdge = Paint()..color = _streetEdge..strokeWidth = w + 4.5;
    void lines(Paint pe, Paint pf, double s, bool skipArterial) {
      for (var lat = (se.latitude / s).floor() * s; lat <= nw.latitude + s; lat += s) {
        if (skipArterial && ((lat / 0.02).round() * 0.02 - lat).abs() < 1e-6) continue;
        final y = p.toScreen(LatLng(lat, 0)).dy;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), pe);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), pf);
      }
      for (var lng = (nw.longitude / s).floor() * s; lng <= se.longitude + s; lng += s) {
        if (skipArterial && ((lng / 0.02).round() * 0.02 - lng).abs() < 1e-6) continue;
        final x = p.toScreen(LatLng(nw.latitude, lng)).dx;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), pe);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), pf);
      }
    }

    if (step < 0.02) lines(edge, street, step, true);
    lines(artEdge, art, 0.02, false);
    for (final hw in _highways) {
      final path = Path()..addPolygon(hw.map(p.toScreen).toList(), false);
      canvas.drawPath(path, Paint()..color = const Color(0xFFE2A94F)..style = PaintingStyle.stroke..strokeWidth = w + 7..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()..color = _highway..style = PaintingStyle.stroke..strokeWidth = w + 5..strokeJoin = StrokeJoin.round);
    }

    if (z >= 11 && z <= 15.5) {
      for (final (name, at) in _places) {
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(fontFamily: kFontFamily, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: _label),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p.toScreen(at) - Offset(tp.width / 2, tp.height / 2));
      }
    }

    for (final pl in polylines) {
      if (pl.points.length < 2) continue;
      final path = Path()..addPolygon(pl.points.map(p.toScreen).toList(), false);
      canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = pl.width + 4.0..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
      canvas.drawPath(path, Paint()..color = pl.color..style = PaintingStyle.stroke..strokeWidth = pl.width.toDouble()..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
    }

    if (me != null) {
      final o = p.toScreen(me!);
      canvas.drawCircle(o, 24, Paint()..color = const Color(0x2E4285F4));
      canvas.drawCircle(o, 9.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 7, Paint()..color = const Color(0xFF4285F4));
    }

    for (final m in markers) {
      final json = m.icon.toJson() as List;
      final hue = json.length > 1 ? (json[1] as num).toDouble() : 0.0;
      final color = HSVColor.fromAHSV(1, hue, 0.78, hue == 0 ? 0.92 : 0.86).toColor().withValues(alpha: m.alpha);
      final o = p.toScreen(m.position);
      final pin = Path()
        ..moveTo(o.dx, o.dy)
        ..cubicTo(o.dx - 4, o.dy - 12, o.dx - 14, o.dy - 19, o.dx - 14, o.dy - 30)
        ..arcToPoint(Offset(o.dx + 14, o.dy - 30), radius: const Radius.circular(14))
        ..cubicTo(o.dx + 14, o.dy - 19, o.dx + 4, o.dy - 12, o.dx, o.dy)
        ..close();
      canvas.drawShadow(pin, Colors.black, 3, false);
      canvas.drawPath(pin, Paint()..color = color);
      canvas.drawPath(pin, Paint()..color = Colors.black.withValues(alpha: 0.2 * m.alpha)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(Offset(o.dx, o.dy - 30), 5, Paint()..color = Colors.black.withValues(alpha: 0.35 * m.alpha));
    }

    final tp = TextPainter(
      text: const TextSpan(text: 'Demo map', style: TextStyle(fontFamily: kFontFamily, fontSize: 10, fontWeight: FontWeight.w600, color: _label)),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = p.padding;
    tp.paint(canvas, Offset(8 + pad.left, size.height - pad.bottom - tp.height - 6));
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
