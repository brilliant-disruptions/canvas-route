import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/logic/csv_export.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/visit.dart';
import '../../state/auth_state.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/routes_state.dart';
import '../../state/visits_state.dart';
import '../../ui/widgets/kn_widgets.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.routeId});
  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final pack = ref.watch(modePackProvider);
    final route = ref.watch(routeByIdProvider(routeId));
    final visits = ref.watch(visitsForRouteProvider(routeId));
    final outcomes = ref.watch(effectiveOutcomesProvider);
    final fields = ref.watch(effectiveExportFieldsProvider);
    final profile = ref.watch(profileProvider).value;
    final anon = ref.watch(isAnonymousProvider);
    if (route == null) return const Scaffold(body: LoadingView());

    Future<void> export(List<Visit> list) async {
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
        meta: [if (profile?.name != null) 'Rep: ${profile!.name}', if (profile?.company != null) 'Company: ${profile!.company}', 'Route: ${route.name}'],
        fields: fields,
        headers: pack.exportHeaders,
        rows: rows,
      );
      await ref.read(shareServiceProvider).shareCsv(csv, csvFileName(route.name, 'visits'), subject: 'Export: ${route.name}');
    }

    return KnScaffold(
      title: 'Summary',
      body: AsyncView(
        value: visits,
        data: (list) {
          final counts = <String, int>{for (final o in outcomes) o: 0};
          for (final v in list) {
            if (v.outcome != null) counts[v.outcome!] = (counts[v.outcome!] ?? 0) + 1;
          }
          final totals = {
            for (final key in pack.summaryTotals)
              key: list.fold<double>(0, (s, v) => s + ((v.customFields[key] as num?)?.toDouble() ?? 0)),
          };
          return ListView(
            padding: const EdgeInsets.all(Sp.s4),
            children: [
              Text(route.name, style: t.headlineLarge),
              Text('${route.visitedCount} of ${route.stopCount} ${pack.stopNoun}s visited', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              const SectionHeader('Outcomes'),
              Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
                for (final e in counts.entries)
                  KnCard(tier: 2, padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s3), child: Column(children: [
                    Text('${e.value}', style: t.headlineMedium?.copyWith(color: c.tertiary)),
                    Text(e.key, style: t.labelMedium),
                  ])),
              ]),
              if (totals.isNotEmpty) ...[
                const SectionHeader('Totals'),
                for (final e in totals.entries)
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(pack.exportHeaders[e.key] ?? e.key), trailing: Text('\$${e.value.toStringAsFixed(2)}', style: t.titleLarge)),
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('Items logged'), trailing: Text('${list.fold<int>(0, (s, v) => s + ((v.customFields['items'] as String?)?.split('\n').where((l) => l.trim().isNotEmpty).length ?? 0))}', style: t.titleLarge)),
              ],
              const SizedBox(height: Sp.s6),
              KnButton(label: 'Export CSV', icon: Icons.ios_share, onPressed: list.isEmpty ? null : () => export(list)),
              const SizedBox(height: Sp.s2),
              OutlinedButton.icon(
                onPressed: () async {
                  if (anon) {
                    context.push('/signin?reason=share');
                    return;
                  }
                  final link = await ref.read(shareRepoProvider).createLink(route.id);
                  await ref.read(shareServiceProvider).shareText('${route.name} — $link', subject: route.name);
                },
                icon: const Icon(Icons.link),
                label: const Text('Share route link'),
              ),
              const SizedBox(height: Sp.s2),
              TextButton(onPressed: () => context.go('/routes'), child: const Text('Back to routes')),
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
