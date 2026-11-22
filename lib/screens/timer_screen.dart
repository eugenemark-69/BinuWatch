import 'package:flutter/material.dart';
import '../timer_controller.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimerController.instance;

    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        final status = t.running ? 'Drying...' : (t.paused ? 'Paused' : 'Ready');

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(status, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                TimerController.format(t.remainingSeconds),
                style:
                const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Times turned: ${t.turnCount}'),
              const SizedBox(height: 32),
              Text('Turn every ${t.intervalMinutes.round()} minutes'),
              Slider(
                value: t.intervalMinutes,
                min: 5,
                max: 120,
                divisions: 23,
                label: '${t.intervalMinutes.round()} min',
                // Only adjustable when nothing is running or paused.
                onChanged: t.idle ? t.setInterval : null,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (t.idle)
                    FilledButton.icon(
                      onPressed: t.start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start drying'),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: t.running ? t.pause : t.resume,
                      icon: Icon(t.running ? Icons.pause : Icons.play_arrow),
                      label: Text(t.running ? 'Pause' : 'Resume'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: t.stop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}