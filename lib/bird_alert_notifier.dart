import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Shows the "bird detected" notification on the receiver phone.
// NotificationService.init() (called in main) must have run first.
class BirdAlertNotifier {
  BirdAlertNotifier._();
  static final instance = BirdAlertNotifier._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Its own channel, so it is separate from the turn-the-rice alarm.
  static final _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'bird_alert',
      'Bird alerts',
      channelDescription: 'Alerts when a bird or chicken is detected',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
      visibility: NotificationVisibility.public,
    ),
  );

  Future<void> show({required String label, required double confidence}) async {
    final name =
    label.isEmpty ? 'Bird' : '${label[0].toUpperCase()}${label.substring(1)}';

    // A different id each time, so a new alert does not replace the last one.
    final id = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000) + 100;

    await _plugin.show(
      id: id,
      title: 'Bird alert!',
      body: '$name detected (${(confidence * 100).round()}%). Check the rice!',
      notificationDetails: _details,
    );
  }
}