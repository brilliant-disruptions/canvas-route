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

  /// [onTap] receives the payload (a route path) when a reminder is tapped,
  /// including the tap that launched the app from closed.
  Future<void> init({void Function(String? payload)? onTap}) {
    final ready = _ready ??= _init(onTap);
    // A failed setup (time-zone lookup, plugin) is retried next time, not cached.
    return ready.catchError((Object e) {
      _ready = null;
      throw e;
    });
  }

  Future<void> _init(void Function(String? payload)? onTap) async {
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
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) onTap?.call(launch!.notificationResponse?.payload);
  }

  final _applied = <String, String>{};
  final _pending = <String, List<PlannedReminder>>{};
  Future<void>? _running;

  /// Replaces the pending reminders of one [group] (its tap-through route, e.g.
  /// '/follow-ups') with [plan], leaving other groups alone. Calls are serialised
  /// and only the latest plan per group is applied, so a slow reschedule can't
  /// resurrect a reminder a newer plan dropped. Asks for permission the first
  /// time there's at least one to schedule.
  Future<void> replaceAll(List<PlannedReminder> plan, {required String group}) {
    if (kIsWeb) return Future.value();
    _pending[group] = plan;
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    await init();
    while (_pending.isNotEmpty) {
      final group = _pending.keys.first;
      final plan = _pending.remove(group)!;
      final key = [for (final r in plan) '${r.notificationId}@${r.at.toIso8601String()}:${r.title}:${r.body}'].join('|');
      if (key == _applied[group]) continue;
      await _apply(group, plan);
      _applied[group] = key;
    }
  }

  Future<void> _apply(String group, List<PlannedReminder> plan) async {
    // The payload is the group: cancel just this group's pending reminders.
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.payload == group) await _plugin.cancel(id: p.id);
    }
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
        payload: group,
      );
    }
  }
}
