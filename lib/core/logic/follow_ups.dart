// When a follow-up is due, relative to today. Pure; no Flutter.

import 'dates.dart';

export 'dates.dart' show calendarDaysBetween;

enum FollowUpBucket { overdue, today, thisWeek, later }

/// Overdue before today, today, within the next 6 days, or later.
FollowUpBucket followUpBucket(DateTime due, DateTime now) {
  final days = calendarDaysBetween(now, due);
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
  final days = calendarDaysBetween(now, due);
  if (days < 0) return '${-days} day${days == -1 ? '' : 's'} overdue';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return days < 7 ? 'Due ${wd[due.weekday - 1]}' : 'Due ${mo[due.month - 1]} ${due.day}';
}

/// A week later, for "not yet, ask me next week": a week after the due date, or a
/// week from today if it's already due. Never earlier than it was.
DateTime snoozeWeek(DateTime now, DateTime due) {
  final base = calendarDaysBetween(now, due) > 0 ? due : now;
  return dayPlus(base, 7);
}
