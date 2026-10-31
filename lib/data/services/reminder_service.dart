import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/logic/reminders.dart';

/// Local notifications for follow-ups: scheduled on the device, no push server.
/// A no-op on the web (and so in the demo build).
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  bool _asked = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'follow_ups',
      'Follow-ups',
      channelDescription: 'Morning reminders for callbacks due that day',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// [onTap] receives the payload (a route path) when a reminder is tapped.
  Future<void> init({void Function(String? payload)? onTap}) => _ready ??= () async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ask for permission when there's something to remind about, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
  }();

  /// Replaces every pending reminder with [plan]. Asks for permission the first
  /// time there's at least one to schedule.
  Future<void> replaceAll(List<PlannedReminder> plan, {String? payload}) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancelAllPendingNotifications();
    if (plan.isEmpty) return;
    if (!_asked) {
      _asked = true;
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: r.notificationId,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details,
        // Inexact is fine for a morning nudge and needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: payload,
      );
    }
  }
}
