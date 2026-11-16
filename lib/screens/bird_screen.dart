import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../pairing_service.dart';

class BirdScreen extends StatefulWidget {
  const BirdScreen({super.key});

  @override
  State<BirdScreen> createState() => _BirdScreenState();
}

class _BirdScreenState extends State<BirdScreen> {
  // ---- Settings you can tune ----

  // The sound file, relative to the assets folder.
  // assets/sounds/'sounds/SO-sound.m4a' ->  'sounds/scare.wav'
  // If you use your own file, change the name here to match exactly.
  static const String _soundFile = 'sounds/SO-sound.m4a';

  // A bird must appear in this many frames in a row before we react.
  // One-frame detections flicker, so this filters out false alarms.
  static const int _framesNeeded = 3;

  // How long the scare sound plays, then how long it stays quiet afterward.
  static const int _soundSeconds = 10;
  static const int _soundCooldownSeconds = 2;

  // Minimum time between alerts sent to the paired phone.
  static const int _alertCooldownSeconds = 60;

  // ---- State ----
  final AudioPlayer _player = AudioPlayer();
  Timer? _stopTimer;
  DateTime? _soundCooldownUntil;
  DateTime? _lastAlertAt;

  bool _monitoring = false;
  bool _soundEnabled = true;
  bool _soundPlaying = false;
  int _birdFrames = 0; // consecutive frames that contained a bird
  int _detections = 0; // how many times the deterrent was triggered
  String _seen = 'Nothing yet';
  String _alertStatus = 'No alert sent yet';

  bool get _birdAlert => _birdFrames >= _framesNeeded;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _player.dispose(); // also stops any sound that is still playing
    super.dispose();
  }

  void _onResult(List<YOLOResult> results) {
    if (!mounted) return;
    final hasBird = results.any((r) => r.className == 'bird');
    setState(() {
      _birdFrames = hasBird ? _birdFrames + 1 : 0;
      _seen = results.isEmpty
          ? 'Nothing detected'
          : results
          .map((r) => '${r.className} ${(r.confidence * 100).round()}%')
          .join(', ');
    });
    if (_birdAlert) {
      _triggerDeterrent();
      _maybeSendAlert(results);
    }
  }

  // ---------- Scare sound ----------

  // Runs on every frame while a bird is confirmed, so the cooldown is checked
  // and set first, before anything slow happens.
  void _triggerDeterrent() {
    final now = DateTime.now();
    final until = _soundCooldownUntil;
    if (until != null && now.isBefore(until)) return;
    _soundCooldownUntil =
        now.add(const Duration(seconds: _soundSeconds + _soundCooldownSeconds));
    setState(() => _detections++);
    if (_soundEnabled) _playSound();
  }

  Future<void> _playSound() async {
    _stopTimer?.cancel();
    try {
      await _player.setVolume(1.0);
      await _player.play(AssetSource(_soundFile));
      if (mounted) setState(() => _soundPlaying = true);
      _stopTimer = Timer(const Duration(seconds: _soundSeconds), _stopSound);
    } catch (e) {
      debugPrint('Sound error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not play the sound. Check the file name and the assets entry in pubspec.yaml.'),
          ),
        );
      }
    }
  }

  Future<void> _stopSound() async {
    _stopTimer?.cancel();
    await _player.stop();
    if (mounted) setState(() => _soundPlaying = false);
  }

  // ---------- Alert to the paired phone ----------

  Future<void> _maybeSendAlert(List<YOLOResult> results) async {
    final now = DateTime.now();
    final last = _lastAlertAt;
    if (last != null &&
        now.difference(last) < const Duration(seconds: _alertCooldownSeconds)) {
      return;
    }
    _lastAlertAt = now;

    // Use the most confident bird in this frame.
    var best = 0.0;
    for (final r in results) {
      if (r.className != 'bird') continue;
      final c = r.confidence.toDouble();
      if (c > best) best = c;
    }
    await _send('bird', best);
  }

  Future<void> _send(String label, double confidence) async {
    final result = await PairingService.instance
        .sendAlert(label: label, confidence: confidence);
    if (!mounted) return;
    setState(() {
      _alertStatus = switch (result) {
        AlertResult.sent => 'Alert sent to the paired phone at ${_stamp()}',
        AlertResult.queued =>
        'Alert saved. It will be sent when the internet is back.',
        AlertResult.notPaired =>
        'Not paired, so no alert was sent to another phone.',
        AlertResult.failed => 'Alert could not be sent. Check the internet.',
      };
    });
  }

  String _stamp() {
    final t = DateTime.now();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  void _toggle() {
    if (_monitoring) _stopSound();
    setState(() {
      _monitoring = !_monitoring;
      _birdFrames = 0;
      _soundCooldownUntil = null;
      _seen = 'Nothing yet';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status banner
        Container(
          width: double.infinity,
          color: !_monitoring
              ? Colors.grey.shade600
              : (_birdAlert ? Colors.red.shade600 : Colors.green.shade600),
          padding: const EdgeInsets.all(12),
          child: Text(
            !_monitoring
                ? 'Monitoring is off'
                : (_birdAlert ? 'BIRD DETECTED!' : 'Watching... all clear'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        // Camera view (only created while monitoring, so the camera is off otherwise)
        Expanded(
          child: _monitoring
              ? YOLOView(
            modelPath: 'yolo26n',
            onResult: _onResult,
          )
              : const Center(
            child: Text(
              'Tap Start to turn on the camera.\n'
                  'The first start downloads the model, so you need internet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Debug line: shows everything the model sees, with confidence
        if (_monitoring)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text('Seeing: $_seen', textAlign: TextAlign.center),
          ),

        // Scare sound controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.volume_up),
              const SizedBox(width: 8),
              const Expanded(child: Text('Scare sound')),
              Switch(
                value: _soundEnabled,
                onChanged: (v) {
                  setState(() => _soundEnabled = v);
                  if (!v) _stopSound();
                },
              ),
              TextButton(
                onPressed: _soundPlaying ? _stopSound : _playSound,
                child: Text(_soundPlaying ? 'Stop' : 'Test'),
              ),
            ],
          ),
        ),
        Text('Birds detected this session: $_detections'),

        // Result of the last alert sent to the paired phone
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Text(_alertStatus, textAlign: TextAlign.center),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(_monitoring ? Icons.stop : Icons.videocam),
                label:
                Text(_monitoring ? 'Stop monitoring' : 'Start monitoring'),
              ),
              const SizedBox(width: 12),
              // Sends an alert without needing a real bird, to test pairing.
              OutlinedButton(
                onPressed: () => _send('test', 1.0),
                child: const Text('Test alert'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}