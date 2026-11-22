import 'package:flutter/foundation.dart';

// Shared information that the Home screen reads. Each feature (weather,
// timer, bird monitor, pairing) publishes its status here.

enum AdviceLevel { good, caution, avoid }

enum ActivityKind { bird, turn, alert }

class ActivityItem {
  final DateTime time;
  final String text;
  final ActivityKind kind;
  const ActivityItem(this.time, this.text, this.kind);
}

// Example: "2:15 PM"
String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  // ---------- Weather ----------
  AdviceLevel? advice; // null until the weather has loaded once
  String adviceReason = '';
  String placeName = '';
  DateTime? weatherCheckedAt;

  void setWeather({
    required AdviceLevel advice,
    required String reason,
    required String place,
    required DateTime checkedAt,
  }) {
    this.advice = advice;
    adviceReason = reason;
    placeName = place;
    weatherCheckedAt = checkedAt;
    notifyListeners();
  }

  // ---------- Bird monitor ----------
  bool birdMonitoring = false;
  int _birdsToday = 0;
  DateTime? lastBirdAt;

  // Counts only today's detections; resets by itself on a new day.
  int get birdsToday =>
      (lastBirdAt != null && _sameDay(lastBirdAt!, DateTime.now()))
          ? _birdsToday
          : 0;

  void setMonitoring(bool value) {
    if (birdMonitoring == value) return;
    birdMonitoring = value;
    notifyListeners();
  }

  // Called once each time a bird shows up (not once per camera frame).
  void recordBird() {
    final now = DateTime.now();
    if (lastBirdAt == null || !_sameDay(lastBirdAt!, now)) _birdsToday = 0;
    _birdsToday++;
    lastBirdAt = now;
    _addActivity('Bird detected', ActivityKind.bird);
    notifyListeners();
  }

  // ---------- Pairing ----------
  String? pairingRole; // 'monitor', 'receiver' or null
  DateTime? lastAlertReceivedAt;

  void setPairing(String? role) {
    pairingRole = role;
    notifyListeners();
  }

  // Called on the alert phone when an alert arrives.
  void recordAlertReceived(String label) {
    lastAlertReceivedAt = DateTime.now();
    _addActivity('Bird alert received', ActivityKind.alert);
    notifyListeners();
  }

  // ---------- Recent activity ----------
  final List<ActivityItem> _activity = [];
  List<ActivityItem> get activity => List.unmodifiable(_activity);

  void addActivity(String text, ActivityKind kind) {
    _addActivity(text, kind);
    notifyListeners();
  }

  void _addActivity(String text, ActivityKind kind) {
    _activity.insert(0, ActivityItem(DateTime.now(), text, kind));
    if (_activity.length > 30) _activity.removeLast();
  }
}