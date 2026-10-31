// When a follow-up is due, relative to today. Pure; no Flutter.

enum FollowUpBucket { overdue, today, thisWeek, later }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Overdue before today, today, within the next 6 days, or later.
FollowUpBucket followUpBucket(DateTime due, DateTime now) {
  final days = _day(due).difference(_day(now)).inDays;
  if (days < 0) return FollowUpBucket.overdue;
  if (days == 0) return FollowUpBucket.today;
  if (days < 7) return FollowUpBucket.thisWeek;
  return FollowUpBucket.later;
}

String followUpBucketTitle(FollowUpBucket b) => switch (b) {
  FollowUpBucket.overdue => 'Overdue',
  FollowUpBucket.today => 'Today',
  FollowUpBucket.thisWeek => 'This week',
  FollowUpBucket.later => 'Later',
};

/// "Due today", "Due tomorrow", "1 day overdue", "Due Thu", "Due Nov 14".
String followUpDueLabel(DateTime due, DateTime now) {
  final days = _day(due).difference(_day(now)).inDays;
  if (days < 0) return '${-days} day${days == -1 ? '' : 's'} overdue';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return days < 7 ? 'Due ${wd[due.weekday - 1]}' : 'Due ${mo[due.month - 1]} ${due.day}';
}

/// A week from today, for "not yet, ask me next week".
DateTime snoozeWeek(DateTime now) => _day(now).add(const Duration(days: 7));
