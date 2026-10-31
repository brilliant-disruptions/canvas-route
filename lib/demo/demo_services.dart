import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/router.dart';
import '../core/logic/geo.dart';
import '../core/theme/kn_colors.dart';
import '../core/theme/kn_theme.dart';
import '../data/models/business.dart';
import '../data/models/directions.dart';
import '../data/models/stop.dart';
import '../data/services/directions_service.dart';
import '../data/services/location_service.dart';
import '../data/services/places_service.dart';
import '../data/services/share_service.dart';
import '../data/services/storage_service.dart';
import 'demo_db.dart';

int _hash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

class DemoPlacesService implements PlacesService {
  static const _stop = {'store', 'stores', 'near', 'me', 'the', 'a', 'in', 'dallas', 'offices', 'office', 'shop', 'shops'};
  static const _brands = {'target', 'walmart', 'costco', 'gamestop', 'barnes', 'walgreens'};

  Business _biz(Map<String, dynamic> p, String category) => Business(
        placeId: p['place_id'] as String,
        name: p['name'] as String,
        address: p['address'] as String,
        lat: (p['lat'] as num).toDouble(),
        lng: (p['lng'] as num).toDouble(),
        rating: (p['rating'] as num?)?.toDouble(),
        types: [category],
        source: StopSource.places,
      );

  @override
  Future<List<Business>> textSearch(String query, double lat, double lng, {int radiusMeters = 5000}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final q = query.toLowerCase();
    final tokens = q.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty && !_stop.contains(t)).toList();
    final out = <Business>[];
    for (final e in demoCatalogKeywords.entries) {
      final hit = e.value.any((k) => q.contains(k)) || tokens.any((t) => e.value.any((k) => k.startsWith(t) && t.length >= 3));
      if (!hit) continue;
      var places = demoCatalog[e.key]!;
      final brand = tokens.where(_brands.contains).toList();
      if (e.key == 'stores' && brand.isNotEmpty) {
        places = places.where((p) => brand.any((b) => (p['name'] as String).toLowerCase().contains(b))).toList();
      }
      out.addAll(places.map((p) => _biz(p, e.key)));
    }
    if (out.isNotEmpty) return out;
    // Anything else: plausible generic results around the search point.
    final title = query.trim().split(RegExp(r'\s+')).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    const suffixes = ['Dallas', 'on Greenville', 'Uptown', '& Co.', 'Lakewood', 'Studio'];
    final seed = _hash(q);
    return [
      for (var i = 0; i < suffixes.length; i++)
        Business(
          placeId: 'pl_gen_${seed}_$i',
          name: '$title ${suffixes[i]}',
          address: '${1000 + (seed + i * 377) % 8000} ${['Ross Ave', 'Gaston Ave', 'Live Oak St', 'Swiss Ave', 'McKinney Ave', 'Lemmon Ave'][i]}, Dallas, TX',
          lat: lat + (((seed >> i) % 100) - 50) / 1800,
          lng: lng + (((seed >> (i + 3)) % 100) - 50) / 1500,
          rating: 3.8 + ((seed + i) % 12) / 10,
          types: const ['establishment'],
          source: StopSource.places,
        ),
    ];
  }

  @override
  Future<({String? phone, String? website, List<String> hours})> details(String placeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final h = _hash(placeId);
    final slug = placeId.replaceFirst('pl_', '').replaceAll('_', '-');
    final open = 7 + h % 3;
    final close = 17 + h % 5;
    String t(int x) => '${x > 12 ? x - 12 : x}:00 ${x >= 12 ? 'PM' : 'AM'}';
    return (
      phone: '(214) 555-${(100 + h % 900).toString().padLeft(4, '0')}',
      website: 'https://example.com/$slug',
      hours: [
        for (final d in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']) '$d: ${t(open)} – ${t(close)}',
        'Saturday: ${t(open + 1)} – ${t(close - 2)}',
        'Sunday: Closed',
      ],
    );
  }

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    final h = _hash('${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}');
    return '${1000 + h % 8000} ${['Prospect Ave', 'Llano Ave', 'Vanderbilt Ave', 'Richmond Ave', 'Monticello Ave'][h % 5]}, Dallas, TX';
  }

  @override
  Future<({double lat, double lng, String formatted})?> geocode(String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (address.trim().isEmpty) return null;
    for (final list in demoCatalog.values) {
      for (final p in list) {
        if ((p['address'] as String).toLowerCase().startsWith(address.toLowerCase().trim())) {
          return (lat: (p['lat'] as num).toDouble(), lng: (p['lng'] as num).toDouble(), formatted: p['address'] as String);
        }
      }
    }
    final h = _hash(address.toLowerCase());
    final formatted = address.contains(',') ? address.trim() : '${address.trim()}, Dallas, TX';
    return (
      lat: DemoDb.home.lat + ((h % 200) - 100) / 3000,
      lng: DemoDb.home.lng + (((h >> 8) % 200) - 100) / 2500,
      formatted: formatted,
    );
  }
}

String encodePolyline(List<Waypoint> pts) {
  final sb = StringBuffer();
  var pLat = 0, pLng = 0;
  void enc(int v) {
    var x = v < 0 ? -2 * v - 1 : 2 * v; // arithmetic zigzag; `~` is unsigned on the web
    while (x >= 0x20) {
      sb.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    sb.writeCharCode(x + 63);
  }

  for (final p in pts) {
    final lat = (p.lat * 1e5).round(), lng = (p.lng * 1e5).round();
    enc(lat - pLat);
    enc(lng - pLng);
    pLat = lat;
    pLng = lng;
  }
  return sb.toString();
}

/// Straight-line routing with a city-grid shape and a road factor. Optimizes
/// with nearest-neighbor, which is what a demo needs.
class DemoDirectionsService implements DirectionsService {
  static double _m(Waypoint a, Waypoint b) => haversineMeters(a.lat, a.lng, b.lat, b.lng) * 1.3;
  static int _sec(double meters) => (meters / 11.0 + 90).round();

  @override
  Future<DirectionsResult> route(List<Waypoint> waypoints, {bool optimize = false, Waypoint? origin, Waypoint? destination}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (waypoints.length < 2 && origin == null) throw DirectionsException('At least two waypoints are required');
    if (waypoints.length > DirectionsService.maxWaypoints) {
      throw DirectionsException('Routes support up to ${DirectionsService.maxWaypoints} stops');
    }
    final Waypoint o, d;
    final List<Waypoint> mids;
    if (origin != null && destination != null && optimize) {
      o = origin;
      d = destination;
      mids = waypoints;
    } else if (origin != null) {
      o = origin;
      d = waypoints.last;
      mids = waypoints.sublist(0, waypoints.length - 1);
    } else {
      o = waypoints.first;
      d = waypoints.last;
      mids = waypoints.sublist(1, waypoints.length - 1);
    }
    var order = [for (var i = 0; i < mids.length; i++) i];
    if (optimize && mids.length > 1) {
      final left = {...order};
      order = [];
      var cur = o;
      while (left.isNotEmpty) {
        final next = left.reduce((a, b) => _m(cur, mids[a]) <= _m(cur, mids[b]) ? a : b);
        order.add(next);
        left.remove(next);
        cur = mids[next];
      }
    }
    final pts = [o, for (final i in order) mids[i], d];
    final legs = [for (var i = 1; i < pts.length; i++) _m(pts[i - 1], pts[i])];
    final road = <Waypoint>[];
    for (var i = 0; i < pts.length; i++) {
      if (i > 0) road.add(Waypoint(pts[i - 1].lat, pts[i].lng));
      road.add(pts[i]);
    }
    return DirectionsResult(
      encodedPolyline: encodePolyline(road),
      totalDistanceMeters: legs.fold(0.0, (s, x) => s + x).round(),
      totalDurationSeconds: legs.fold(0, (s, x) => s + _sec(x)),
      legDurationSeconds: [for (final l in legs) _sec(l)],
      optimizedOrder: optimize ? order : null,
    );
  }
}

class DemoLocationService implements LocationService {
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<Waypoint?> current() async => DemoDb.home;
}

/// Photos stay in the browser for the session; the picked file's blob URL is the path.
class DemoStorageService implements StorageService {
  @override
  Future<String> upload(String bucket, XFile file) async => file.path;
  @override
  String publicUrl(String bucket, String path) => path;
  @override
  Future<String> signedUrl(String bucket, String path, {int seconds = 3600}) async => path;
  @override
  Future<void> remove(String bucket, String path) async {}
}

/// Browsers inside the artifact can't open the system share sheet, so show
/// what would be shared in a dialog with a copy button.
class DemoShareService implements ShareService {
  @override
  Future<void> shareCsv(String csv, String fileName, {String? subject}) =>
      _show(title: 'Export · $fileName', body: csv, monospace: true, note: 'On a phone this opens the share sheet with the CSV attached.');

  @override
  Future<void> shareImage(Uint8List png, String fileName, {String? text, String? subject}) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(subject ?? 'Share'),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('On a phone this opens the share sheet with this image attached.',
                style: Theme.of(c).textTheme.bodySmall?.copyWith(color: c.kn.onSurfaceVariant)),
            const SizedBox(height: Sp.s3),
            ClipRRect(borderRadius: BorderRadius.circular(Rad.md), child: Image.memory(png)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
      ),
    );
  }

  @override
  Future<void> shareText(String text, {String? subject}) =>
      _show(title: subject ?? 'Share', body: text, note: 'On a phone this opens the share sheet. Links point at the future web app.');

  Future<void> _show({required String title, required String body, required String note, bool monospace = false}) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog<void>(context: ctx, builder: (c) => _ShareDialog(title: title, body: body, note: note, monospace: monospace));
  }
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.title, required this.body, required this.note, required this.monospace});
  final String title;
  final String body;
  final String note;
  final bool monospace;
  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.note, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: Sp.s3),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.all(Sp.s3),
            decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(Rad.md)),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.body,
                style: (widget.monospace ? t.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11) : t.bodyMedium),
              ),
            ),
          ),
          if (_status != null) ...[const SizedBox(height: Sp.s2), Text(_status!, style: t.labelMedium?.copyWith(color: c.tertiary))],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: widget.body));
              setState(() => _status = 'Copied');
            } catch (_) {
              setState(() => _status = 'Copy is blocked here. Select the text instead.');
            }
          },
          child: const Text('Copy'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

