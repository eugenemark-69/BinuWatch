import 'dart:async';
import 'package:flutter/material.dart';
import '../notification_service.dart';

// Set to 1 to test quickly (minutes become seconds). Use 60 for real use.
const int _secondsPerMinute = 60;

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _ticker;
  DateTime? _endTime;
  bool _paused = false;
  double _intervalMinutes = 30;
  int _remainingSeconds = 30 * _secondsPerMinute;
  int _turnCount = 0;

  bool get _running => _ticker != null;
  bool get _idle => !_running && !_paused;

  int get _fullIntervalSeconds => _intervalMinutes.round() * _secondsPerMinute;

  // Starts (or continues) counting down from _remainingSeconds.
  void _beginCountdown() {
    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    NotificationService.instance
        .scheduleTurnReminder(Duration(seconds: _remainingSeconds));
  }

  void _start() {
    setState(() {
      _paused = false;
      _remainingSeconds = _fullIntervalSeconds;
      _beginCountdown();
    });
  }

  void _pause() {
    _updateRemaining();
    _ticker?.cancel();
    setState(() {
      _ticker = null;
      _paused = true;
    });
    NotificationService.instance.cancelAll();
  }

  void _resume() {
    setState(() {
      _paused = false;
      _beginCountdown();
    });
  }

  void _stop() {
    _ticker?.cancel();
    setState(() {
      _ticker = null;
      _paused = false;
      _remainingSeconds = _fullIntervalSeconds;
    });
    NotificationService.instance.cancelAll();
  }

  // Works out the remaining time from the clock, not by subtracting 1 each
  // tick, so it stays correct even if the phone was locked for a while.
  void _updateRemaining() {
    final left = _endTime!.difference(DateTime.now());
    _remainingSeconds =
    left <= Duration.zero ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  void _tick() {
    _updateRemaining();
    if (_remainingSeconds <= 0) {
      _finish();
    } else {
      setState(() {});
    }
  }

  // Interval finished: stop and wait for the farmer to start again.
  // Interval finished: stop and wait for the farmer to start again.
  void _finish() {
    _ticker?.cancel();
    setState(() {
      _ticker = null;
      _paused = false;
      _turnCount++;
      _remainingSeconds = _fullIntervalSeconds;
    });
    _showAlarmDialog();
  }

  void _showAlarmDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.alarm, size: 48),
        title: const Text('Time to turn the rice!'),
        content: const Text('Turn (karaw) the rice, then stop the alarm.'),
        actions: [
          FilledButton(
            onPressed: () {
              NotificationService.instance.stopAlarm();
              Navigator.of(ctx).pop();
            },
            child: const Text('Stop alarm'),
          ),
        ],
      ),
    );
  }

  String _format(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // Only stop the on-screen ticker. Scheduled notifications stay.
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _running ? 'Drying...' : (_paused ? 'Paused' : 'Ready');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(status, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            _format(_remainingSeconds),
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Times turned: $_turnCount'),
          const SizedBox(height: 32),
          Text('Turn every ${_intervalMinutes.round()} minutes'),
          Slider(
            value: _intervalMinutes,
            min: 5,
            max: 120,
            divisions: 23,
            label: '${_intervalMinutes.round()} min',
            // Only adjustable when nothing is running or paused.
            onChanged: _idle
                ? (v) => setState(() {
              _intervalMinutes = v;
              _remainingSeconds = _fullIntervalSeconds;
            })
                : null,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_idle)
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start drying'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: _running ? _pause : _resume,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : 'Resume'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}