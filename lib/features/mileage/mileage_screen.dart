import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logic/csv_export.dart';
import '../../core/logic/geo.dart';
import '../../core/logic/mileage.dart';
import '../../core/theme/kn_colors.dart';
import '../../core/theme/kn_theme.dart';
import '../../data/models/trip.dart';
import '../../state/profile_state.dart';
import '../../state/providers.dart';
import '../../state/trips_state.dart';
import '../../ui/widgets/kn_widgets.dart';
import '../settings/paywall_sheet.dart';

/// Miles driven per run, totalled by month with the IRS business rate applied.
/// Viewing is free; the CSV for an expense report is the paid tier.
class MileageScreen extends ConsumerWidget {
  const MileageScreen({super.key});

  static final _money = NumberFormat.simpleCurrency();
  static String _mi(num miles) => '${miles.toStringAsFixed(1)} mi';

  Future<void> _export(BuildContext context, WidgetRef ref, List<Trip> trips) async {
    final pack = ref.read(modePackProvider);
    if (!await requirePro(context, ref, 'Mileage export for expense reports is part of ${pack.proLabel}.')) return;
    final profile = ref.read(profileProvider).value;
    const fields = ['date', 'route', 'stops', 'miles', 'rate', 'amount', 'source'];
    final csv = buildCsv(
      meta: [
        if (profile?.name != null) 'Driver: ${profile!.name}',
        if (profile?.company != null) 'Company: ${profile!.company}',
        'Mileage log',
      ],
      fields: fields,
      headers: const {
        'date': 'Date',
        'route': 'Route',
        'stops': 'Stops',
        'miles': 'Miles',
        'rate': 'IRS rate (\$/mi)',
        'amount': 'Amount (\$)',
        'source': 'Distance source',
      },
      rows: [
        for (final t in trips)
          CsvRow({
            'date': DateFormat('yyyy-MM-dd').format(t.day),
            'route': t.routeName,
            'stops': '${t.stopsVisited}',
            'miles': metersToMiles(t.distanceMeters.toDouble()).toStringAsFixed(1),
            'rate': irsBusinessRate(t.day).toStringAsFixed(3),
            'amount': (metersToMiles(t.distanceMeters.toDouble()) * irsBusinessRate(t.day)).toStringAsFixed(2),
            'source': t.estimated ? 'Estimated' : 'Google Routes',
          }),
      ],
    );
    await ref.read(shareServiceProvider).shareCsv(csv, csvFileName('mileage', DateFormat('yyyy_MM').format(DateTime.now())), subject: 'Mileage log');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.kn;
    final t = Theme.of(context).textTheme;
    final trips = ref.watch(tripsProvider);
    return KnScaffold(
      title: 'Mileage',
      actions: [
        if ((trips.value ?? const []).isNotEmpty)
          TextButton.icon(
            onPressed: () => _export(context, ref, trips.value!),
            icon: const Icon(Icons.ios_share),
            label: const Text('Export'),
          ),
      ],
      body: AsyncView(
        value: trips,
        onRetry: () => ref.invalidate(tripsProvider),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.speed,
              title: 'No miles yet',
              body: 'Finish a route and its miles land here, ready for your expense report.',
            );
          }
          final months = mileageByMonth([
            for (final x in list) (day: x.day, miles: metersToMiles(x.distanceMeters.toDouble())),
          ]);
          final byMonth = <DateTime, List<Trip>>{};
          for (final x in list) {
            byMonth.putIfAbsent(DateTime(x.day.year, x.day.month), () => []).add(x);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s6),
            children: [
              for (final m in months) ...[
                SectionHeader(DateFormat.yMMMM().format(m.month)),
                KnCard(
                  tier: 3,
                  accent: c.tertiary,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_mi(m.miles), style: t.headlineSmall),
                            Text('${m.trips} ${m.trips == 1 ? 'trip' : 'trips'}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_money.format(m.deduction), style: t.headlineSmall?.copyWith(color: c.tertiary)),
                          Text('at the IRS rate', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Sp.s2),
                for (final x in byMonth[m.month]!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alt_route),
                    title: Text(x.routeName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${DateFormat.MMMEd().format(x.day)} · ${x.stopsVisited} stops${x.estimated ? ' · estimated' : ''}',
                    ),
                    trailing: Text(_mi(metersToMiles(x.distanceMeters.toDouble())), style: t.titleMedium),
                  ),
              ],
              const SizedBox(height: Sp.s4),
              Text(
                'Miles are the drive between visited stops, in the order you visited them. The drive from home to '
                'your first stop is usually commuting, so it isn\'t counted. IRS business rate: 72.5¢ (Jan–Jun 2026), '
                '76¢ (from Jul 2026). Check with your accountant.',
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}
