import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../strings.dart';
import '../timer_controller.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimerController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([t, AppSettings.instance]),
      builder: (context, _) {
        final status = t.running
            ? tr('status_drying')
            : (t.paused ? tr('status_paused') : tr('status_ready'));

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
              Text(tr('timer_turned', {'n': '${t.turnCount}'})),
              const SizedBox(height: 32),
              Text(tr('timer_every', {'n': '${t.intervalMinutes.round()}'})),
              Slider(
                value: t.intervalMinutes,
                min: 5,
                max: 120,
                divisions: 23,
                label: tr('timer_slider', {'n': '${t.intervalMinutes.round()}'}),
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
                      label: Text(tr('btn_start')),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: t.running ? t.pause : t.resume,
                      icon: Icon(t.running ? Icons.pause : Icons.play_arrow),
                      label:
                      Text(t.running ? tr('btn_pause') : tr('btn_resume')),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: t.stop,
                      icon: const Icon(Icons.stop),
                      label: Text(tr('btn_stop')),
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