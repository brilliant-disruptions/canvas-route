// Calendar-day arithmetic that survives daylight-saving changes. Pure; no Flutter.
//
// Adding Duration(days: n) adds n×24 hours, which across a 23- or 25-hour DST day
// lands an hour off and, near midnight, on the wrong date. Build dates from their
// fields instead; DateTime normalises overflow (day 32 → next month).

/// Midnight [n] calendar days after [d]'s date, in local time.
DateTime dayPlus(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Calendar days from [from] to [to]. UTC dates, so a 23- or 25-hour day counts as one.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
