import 'dates.dart';

/// One choice in the map's single "When" filter.
typedef WhenOption = ({String label, bool openNow, DateTime? day});

/// The choices, in menu order: open now, any day, then the days of this (or
/// the next) weekend. On a weekend, "Today" leads, so a Sunday's sales are
/// never hidden behind next Saturday.
List<WhenOption> whenOptions(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  String md(DateTime d) => '${d.month}/${d.day}';
  final days = switch (now.weekday) {
    DateTime.saturday => [(today, 'Today'), (dayPlus(today, 1), 'Tomorrow'), (dayPlus(today, 7), 'Next Sat')],
    DateTime.sunday => [(today, 'Today'), (dayPlus(today, 6), 'Next Sat'), (dayPlus(today, 7), 'Next Sun')],
    _ => () {
      final sat = dayPlus(today, DateTime.saturday - now.weekday);
      final sun = dayPlus(sat, 1);
      return [(sat, 'Sat ${md(sat)}'), (sun, 'Sun ${md(sun)}'), (dayPlus(sat, 7), 'Next Sat')];
    }(),
  };
  return [
    (label: 'Open now', openNow: true, day: null),
    (label: 'Any day', openNow: false, day: null),
    for (final (d, label) in days) (label: label, openNow: false, day: d),
  ];
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Whether [o] is the current selection.
bool whenSelected(WhenOption o, {required bool openNow, DateTime? day}) =>
    o.openNow ? openNow : !openNow && (o.day == null ? day == null : day != null && _sameDay(o.day!, day));

/// The chip's label for the current selection. A day that's no longer in the
/// menu (picked last week) shows as its date.
String whenLabel({required bool openNow, DateTime? day, required DateTime now}) {
  for (final o in whenOptions(now)) {
    if (whenSelected(o, openNow: openNow, day: day)) return o.label;
  }
  return '${day!.month}/${day.day}';
}
