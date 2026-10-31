import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/logic/csv_export.dart';
import '../../core/logic/recap.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/route_model.dart';
import '../../data/models/visit.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../state/visits_state.dart';
import '../../state/trips_state.dart';
import '../../ui/widgets/celebration.dart';
import '../../ui/widgets/kn_widgets.dart';
import 'recap_card.dart';

/// The finish line: a shareable recap card first, bookkeeping second.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.routeId});
  final String routeId;
  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;
  bool _buzzed = false;
  bool _tripLogged = false;

  Future<void> _shareRecap(RouteModel route, RunRecap recap) async {
    final pack = ref.read(modePackProvider);
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = (await image.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
      // The link is what brings the viewer in; guests can't create one, so they share the image alone.
      final link = ref.read(isAnonymousProvider) ? null : await ref.read(shareRepoProvider).createLink(route.id);
      await ref
          .read(shareServiceProvider)
          .shareImage(
            png,
            csvFileName(route.name, 'recap').replaceAll('.csv', '.png'),
            text:
                '${countNoun(recap.wins, pack.winNoun)} on my ${pack.label} ${pack.routeNoun}.'
                '${link == null ? ' Planned with CanvasRoute.' : ' Run it yourself: $link'}',
            subject: route.name,
          );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _exportCsv(RouteModel route, List<Visit> list) async {
    final pack = ref.read(modePackProvider);
    final fields = ref.read(effectiveExportFieldsProvider);
    final profile = ref.read(profileProvider).value;
    final byStop = {for (final v in list) v.stopId: v};
    final rows = route.stops.map((s) {
      final v = byStop[s.id];
      return CsvRow({
        'stopName': s.name,
        'address': s.address,
        'visitedAt': v == null ? '' : DateFormat.yMd().add_jm().format(v.updatedAt),
        for (final f in fields)
          if (f != 'stopName' && f != 'address' && f != 'visitedAt') f: _str(v?.valueFor(f)),
      });
    }).toList();
    final csv = buildCsv(
      meta: [
        if (profile?.name != null) 'Rep: ${profile!.name}',
        if (profile?.company != null) 'Company: ${profile!.company}',
        'Route: ${route.name}',
      ],
      fields: fields,
      headers: pack.exportHeaders,
      rows: rows,
    );
    await ref
        .read(shareServiceProvider)
        .shareCsv(csv, csvFileName(route.name, 'visits'), subject: 'Export: ${route.name}');
  }

  Future<void> _shareLink(RouteModel route) async {
    if (ref.read(isAnonymousProvider)) {
      context.push('/signin?reason=share');
      return;
    }
    final link = await ref.read(shareRepoProvider).createLink(route.id);
    await ref.read(shareServiceProvider).shareText('${route.name} — $link', subject: route.name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kn;
    final pack = ref.watch(modePackProvider);
    final route = ref.watch(routeByIdProvider(widget.routeId));
    final visits = ref.watch(visitsForRouteProvider(widget.routeId));
    if (route == null) return const Scaffold(body: LoadingView());

    return KnScaffold(
      title: route.allVisited ? '${pack.routesTab.substring(0, pack.routesTab.length - 1)} complete' : 'Summary',
      body: AsyncView(
        value: visits,
        data: (list) {
          if (!_tripLogged) {
            _tripLogged = true;
            // Mileage is bookkeeping: never block or fail the summary over it.
            Future.microtask(() => ref.read(tripLoggerProvider).logRun(route, list)).catchError((_) {});
          }
          final byStop = {for (final v in list) v.stopId: v};
          final recap = buildRecap([
            for (final s in route.stops)
              RecapStop(
                name: s.name,
                lat: s.lat,
                lng: s.lng,
                outcome: byStop[s.id]?.outcome,
                at: byStop[s.id]?.updatedAt,
              ),
          ], winOutcomes: pack.winOutcomes.toSet());
          final money = NumberFormat.simpleCurrency();
          final totals = {
            for (final key in pack.summaryTotals)
              pack.defaultVisitFields.where((f) => f.key == key).firstOrNull?.label ?? key: money.format(
                list.fold<double>(0, (s, v) => s + ((v.customFields[key] as num?)?.toDouble() ?? 0)),
              ),
          };
          final counted = pack.summaryCountField;
          final itemCount = counted == null
              ? 0
              : list.fold<int>(0, (s, v) => s + countLines(v.customFields[counted.key]));

          // Celebrate a run finished just now, not every reopen of an old summary.
          final lastVisit = list
              .map((v) => v.updatedAt)
              .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
          final justFinished =
              route.allVisited &&
              lastVisit != null &&
              DateTime.now().difference(lastVisit) < const Duration(minutes: 10);
          if (justFinished && !_buzzed) {
            _buzzed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => HapticFeedback.heavyImpact());
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, Sp.s6),
                children: [
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: justFinished ? 0.9 : 1, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) => Transform.scale(scale: s, child: child),
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: RecapCard(
                            pack: pack,
                            routeName: route.name,
                            recap: recap,
                            totals: totals,
                            extra: itemCount == 0 ? null : countNoun(itemCount, counted!.noun),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.s5),
                  KnButton(
                    label: 'Share recap',
                    icon: Icons.ios_share,
                    lime: true,
                    loading: _sharing,
                    onPressed: recap.visited == 0 ? null : () => _shareRecap(route, recap),
                  ),
                  const SizedBox(height: Sp.s2),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/map'),
                    icon: const Icon(Icons.bolt),
                    label: Text('${pack.planLabel} again'),
                  ),
                  const SizedBox(height: Sp.s3),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: list.isEmpty ? null : () => _exportCsv(route, list),
                          icon: const Icon(Icons.table_view_outlined),
                          label: const Text('Export CSV'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _shareLink(route),
                          icon: const Icon(Icons.link),
                          label: const Text('Route link'),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/routes'),
                    style: TextButton.styleFrom(foregroundColor: c.onSurfaceVariant),
                    child: Text('Back to ${pack.routesTitle.toLowerCase()}'),
                  ),
                ],
              ),
              if (justFinished) Positioned.fill(child: Celebration(colors: [c.tertiary, c.primary, c.onSurface])),
            ],
          );
        },
      ),
    );
  }

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is List) return v.map((e) => e is Map ? e['name'] : e).join('; ');
    if (v is bool) return v ? 'Yes' : 'No';
    return v.toString();
  }
}
