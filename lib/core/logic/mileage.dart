// Mileage totals and the IRS business rate. Pure; no Flutter.

/// IRS business standard mileage rate in dollars per mile for a driving day.
/// 2026 changed mid-year (72.5¢ from Jan 1, 76¢ from Jul 1 per Announcement
/// 2026-11). Add each new rate here; days before the table use the oldest.
double irsBusinessRate(DateTime day) {
  const table = [
    (from: (2025, 1, 1), rate: 0.70),
    (from: (2026, 1, 1), rate: 0.725),
    (from: (2026, 7, 1), rate: 0.76),
  ];
  var rate = table.first.rate;
  for (final t in table) {
    if (!day.isBefore(DateTime(t.from.$1, t.from.$2, t.from.$3))) rate = t.rate;
  }
  return rate;
}

class MileageMonth {
  const MileageMonth({required this.month, required this.miles, required this.deduction, required this.trips});
  final DateTime month; // first of the month
  final double miles;
  final double deduction; // miles × that day's IRS rate, summed
  final int trips;
}

/// Groups (day, miles) trips by month, newest first.
List<MileageMonth> mileageByMonth(Iterable<({DateTime day, double miles})> trips) {
  final acc = <DateTime, ({double miles, double deduction, int trips})>{};
  for (final t in trips) {
    final m = DateTime(t.day.year, t.day.month);
    final a = acc[m] ?? (miles: 0.0, deduction: 0.0, trips: 0);
    acc[m] = (miles: a.miles + t.miles, deduction: a.deduction + t.miles * irsBusinessRate(t.day), trips: a.trips + 1);
  }
  final months = acc.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final m in months)
      MileageMonth(month: m, miles: acc[m]!.miles, deduction: acc[m]!.deduction, trips: acc[m]!.trips),
  ];
}
