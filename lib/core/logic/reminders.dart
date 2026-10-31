// Which follow-up reminders to schedule on the device. Pure; no Flutter.

typedef ReminderSource = ({String id, String title, String body, DateTime due});
typedef PlannedReminder = ({int notificationId, DateTime at, String title, String body});

/// iOS keeps at most 64 pending local notifications per app; stay under it.
const maxPendingReminders = 50;

/// A stable positive 31-bit id for a follow-up, so rescheduling replaces it.
int reminderId(String key) {
  var h = 0x811c9dc5; // FNV-1a
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// One reminder per follow-up at [hour]:[minute] on its due day, soonest first,
/// skipping times already past (those show as due in the app instead).
List<PlannedReminder> planFollowUpReminders(
  Iterable<ReminderSource> items,
  DateTime now, {
  int hour = 8,
  int minute = 30,
}) {
  final out = <PlannedReminder>[];
  for (final i in items) {
    final at = DateTime(i.due.year, i.due.month, i.due.day, hour, minute);
    if (!at.isAfter(now)) continue;
    out.add((notificationId: reminderId(i.id), at: at, title: i.title, body: i.body));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.take(maxPendingReminders).toList();
}
