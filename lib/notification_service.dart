import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // New channel id on purpose: Android freezes a channel's sound/importance
  // after it is first created, so editing the old one would do nothing.
  static final _alarmDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'turn_alarm',
      'Turn alarm',
      channelDescription: 'Loud alarm that rings until you stop it',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      // 4 = FLAG_INSISTENT: keeps repeating the sound until dismissed.
      additionalFlags: Int32List.fromList([4]),
      ongoing: true, // can't be swiped away
      autoCancel: true, // tapping it opens the app and stops it
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      actions: const [
        AndroidNotificationAction(
          'stop_alarm',
          'STOP ALARM',
          cancelNotification: true,
        ),
      ],
    ),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedules a single alarm [delay] from now.
  Future<void> scheduleTurnReminder(Duration delay) async {
    await cancelAll();
    await _plugin.zonedSchedule(
      id: 1,
      title: 'Binuwad: TURN THE RICE!',
      body: 'Time to turn (karaw) the rice. Tap to stop the alarm.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: _alarmDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> stopAlarm() => _plugin.cancelAll();

  Future<void> cancelAll() => _plugin.cancelAll();
}