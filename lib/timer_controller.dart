import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_state.dart';
import 'notification_service.dart';

// The turn timer lives here (not inside a screen) so that the Home screen and
// the Timer screen both show and control the same timer.
class TimerController extends ChangeNotifier {
  TimerController._();
  static final instance = TimerController._();

  // Set to 1 to test quickly (minutes become seconds). Use 60 for real use.
  static const int secondsPerMinute = 60;

  Timer? _ticker;
  DateTime? _endTime;
  bool _paused = false;
  double _intervalMinutes = 30;
  int _remainingSeconds = 30 * secondsPerMinute;
  int _turnCount = 0;

  // Goes up by one every time an interval finishes. The main shell listens to
  // this to show the "turn the rice" dialog on any tab.
  final ValueNotifier<int> finished = ValueNotifier<int>(0);

  bool get running => _ticker != null;
  bool get paused => _paused;
  bool get idle => !running && !_paused;
  double get intervalMinutes => _intervalMinutes;
  int get remainingSeconds => _remainingSeconds;
  int get turnCount => _turnCount;

  int get _fullSeconds => _intervalMinutes.round() * secondsPerMinute;

  static String format(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  // Only adjustable when nothing is running or paused.
  void setInterval(double minutes) {
    if (!idle) return;
    _intervalMinutes = minutes;
    _remainingSeconds = _fullSeconds;
    notifyListeners();
  }

  void start() {
    _paused = false;
    _remainingSeconds = _fullSeconds;
    _begin();
    notifyListeners();
  }

  void pause() {
    _updateRemaining();
    _ticker?.cancel();
    _ticker = null;
    _paused = true;
    NotificationService.instance.cancelAll();
    notifyListeners();
  }

  void resume() {
    _paused = false;
    _begin();
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _paused = false;
    _remainingSeconds = _fullSeconds;
    NotificationService.instance.cancelAll();
    notifyListeners();
  }

  // Starts (or continues) counting down from _remainingSeconds.
  void _begin() {
    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    NotificationService.instance
        .scheduleTurnReminder(Duration(seconds: _remainingSeconds))
        .catchError((Object e) {
      debugPrint('Could not schedule the turn alarm: $e');
    });
  }

  // Works out the remaining time from the clock, not by subtracting 1 each
  // tick, so it stays correct even if the phone was locked for a while.
  void _updateRemaining() {
    final end = _endTime;
    if (end == null) return;
    final left = end.difference(DateTime.now());
    _remainingSeconds =
    left <= Duration.zero ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  void _tick() {
    _updateRemaining();
    if (_remainingSeconds <= 0) {
      _finish();
    } else {
      notifyListeners();
    }
  }

  // Interval finished: stop and wait for the farmer to start again.
  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _paused = false;
    _turnCount++;
    _remainingSeconds = _fullSeconds;
    AppState.instance.addActivity(ActivityKind.turn, n: _turnCount);
    notifyListeners();
    finished.value++;
  }
}