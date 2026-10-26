import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class BirdScreen extends StatefulWidget {
  const BirdScreen({super.key});

  @override
  State<BirdScreen> createState() => _BirdScreenState();
}

class _BirdScreenState extends State<BirdScreen> {
  bool _monitoring = false;
  int _birdFrames = 0; // consecutive frames that contained a bird
  String _seen = 'Nothing yet';

  // A bird must appear in this many frames in a row before we raise an alert.
  // One-frame detections flicker, so this filters out false alarms.
  static const int _framesNeeded = 3;
  bool get _birdAlert => _birdFrames >= _framesNeeded;

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
  }

  void _toggle() {
    setState(() {
      _monitoring = !_monitoring;
      _birdFrames = 0;
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
            padding: const EdgeInsets.all(8),
            child: Text('Seeing: $_seen', textAlign: TextAlign.center),
          ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_monitoring ? Icons.stop : Icons.videocam),
            label: Text(_monitoring ? 'Stop monitoring' : 'Start monitoring'),
          ),
        ),
      ],
    );
  }
}
