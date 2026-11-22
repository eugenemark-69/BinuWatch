import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../app_state.dart';
import '../pairing_service.dart';

class BirdScreen extends StatefulWidget {
  const BirdScreen({super.key});

  @override
  State<BirdScreen> createState() => _BirdScreenState();
}

class _BirdScreenState extends State<BirdScreen> {
  // ---- Settings you can tune ----

  // The sound file, relative to the assets folder.
  // assets/sounds/SO-sound.m4a  ->  'sounds/SO-sound.m4a'
  // The name must match the file exactly, including capital letters.
  static const String _soundFile = 'sounds/SO-sound.m4a';

  // A bird must appear in this many frames in a row before the sound starts.
  // One-frame detections flicker, so this filters out false alarms.
  static const int _framesNeeded = 3;

  // The sound keeps playing while birds are seen, and stops once no bird has
  // been seen for this many seconds. A short grace period stops the sound from
  // cutting on and off when the camera misses the bird for a moment.
  static const int _soundGraceSeconds = 2;

  // Minimum time between alerts sent to the paired phone.
  static const int _alertCooldownSeconds = 10;

  // ---- State ----
  final AudioPlayer _player = AudioPlayer();
  Timer? _watchTimer; // checks whether the bird has gone away
  DateTime? _lastBirdSeenAt;
  DateTime? _lastAlertAt;

  bool _monitoring = false;
  bool _soundEnabled = true;
  bool _soundPlaying = false;
  bool _episodeActive = false; // a bird is currently in view
  int _birdFrames = 0; // consecutive frames that contained a bird
  int _detections = 0; // how many separate times a bird triggered the sound
  String _seen = 'Nothing yet';
  String _alertStatus = 'No alert sent yet';

  bool get _birdAlert => _birdFrames >= _framesNeeded;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop); // loops until we stop it

    // Every half second: if the sound is playing and no bird has been seen
    // for a few seconds, stop it.
    _watchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final seen = _lastBirdSeenAt;
      final gone = seen == null ||
          DateTime.now().difference(seen) >
              const Duration(seconds: _soundGraceSeconds);
      if (!gone) return;
      _episodeActive = false; // the bird has left; the next one counts again
      if (_soundPlaying) _stopSound();
    });
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _player.dispose(); // also stops any sound that is still playing
    // Tell the Home screen monitoring has stopped. Done a moment later because
    // the screen tree is being torn down right now.
    scheduleMicrotask(() => AppState.instance.setMonitoring(false));
    super.dispose();
  }

  void _onResult(List<YOLOResult> results) {
    if (!mounted) return;
    final hasBird = results.any((r) => r.className == 'bird');
    if (hasBird) _lastBirdSeenAt = DateTime.now();

    setState(() {
      _birdFrames = hasBird ? _birdFrames + 1 : 0;
      _seen = results.isEmpty
          ? 'Nothing detected'
          : results
          .map((r) => '${r.className} ${(r.confidence * 100).round()}%')
          .join(', ');
    });

    if (_birdAlert) {
      _beginEpisodeIfNeeded();
      _startSoundIfNeeded();
      _maybeSendAlert(results);
    }
  }

  // ---------- Scare sound ----------

  // Called on every frame while a bird is confirmed. Does nothing if the
  // sound is already playing, so it keeps going until the bird is gone.
  void _startSoundIfNeeded() {
    if (_soundPlaying || !_soundEnabled) return;
    _playSound();
  }

  // Counts one detection each time a bird appears (not once per frame), and
  // tells the Home screen. This works even when the scare sound is switched off.
  void _beginEpisodeIfNeeded() {
    if (_episodeActive) return;
    _episodeActive = true;
    setState(() => _detections++);
    AppState.instance.recordBird();
  }

  Future<void> _playSound() async {
    // Mark as playing straight away, because frames arrive faster than the
    // player can start and we must not start it twice.
    _soundPlaying = true;
    try {
      await _player.setVolume(1.0);
      await _player.play(AssetSource(_soundFile));
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Sound error: $e');
      _soundPlaying = false;
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
    _soundPlaying = false; // set first so the watcher does not stop it twice
    await _player.stop();
    if (mounted) setState(() {});
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

    final result = await PairingService.instance
        .sendAlert(label: 'bird', confidence: best);
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
      _episodeActive = false;
      _lastBirdSeenAt = null;
      _seen = 'Nothing yet';
    });
    AppState.instance.setMonitoring(_monitoring);
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea keeps the controls clear of the phone's navigation buttons or
    // gesture bar at the bottom of the screen.
    return SafeArea(
      top: false,
      child: Column(
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
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
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

          // What the model sees, with confidence
          if (_monitoring)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text('Seeing: $_seen', textAlign: TextAlign.center),
            ),

          // Scare sound switch
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
              ],
            ),
          ),
          Text('Times a bird triggered the sound: $_detections'),

          // Result of the last alert sent to the paired phone
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(_alertStatus, textAlign: TextAlign.center),
          ),

          // Extra bottom padding so the button sits well above the screen edge
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            child: FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_monitoring ? Icons.stop : Icons.videocam),
              label: Text(_monitoring ? 'Stop monitoring' : 'Start monitoring'),
            ),
          ),
        ],
      ),
    );
  }
}