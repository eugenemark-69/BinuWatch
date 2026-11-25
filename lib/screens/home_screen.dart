import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../app_state.dart';
import '../strings.dart';
import '../timer_controller.dart';

class HomeScreen extends StatelessWidget {
  // Lets a card switch to another tab: 1 = Monitor, 2 = Weather, 3 = Timer.
  final void Function(int tabIndex) onOpenTab;

  const HomeScreen({super.key, required this.onOpenTab});

  static const int _monitorTab = 1;
  static const int _weatherTab = 2;
  static const int _timerTab = 3;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.instance,
        TimerController.instance,
        AppSettings.instance,
      ]),
      builder: (context, _) {
        final app = AppState.instance;
        final timer = TimerController.instance;
        final drying = timer.running || timer.paused;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _adviceCard(app),

            // Rice is drying while the weather looks bad.
            if (drying && app.advice == AdviceLevel.avoid)
              _banner(tr('banner_avoid'), Colors.red),
            if (drying && app.advice == AdviceLevel.caution)
              _banner(tr('banner_caution'), Colors.orange),

            _timerCard(timer),
            _birdCard(app),
            _activityCard(app),
          ],
        );
      },
    );
  }

  // ---------- Drying advice ----------

  Widget _adviceCard(AppState app) {
    final a = app.advice;
    if (a == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_queue, size: 32),
          title: Text(tr('home_drying_advice')),
          subtitle: Text(tr('home_advice_waiting')),
          onTap: () => onOpenTab(_weatherTab),
        ),
      );
    }

    final (label, color, icon) = switch (a) {
      AdviceLevel.good => (
      tr('advice_good'),
      Colors.green.shade600,
      Icons.wb_sunny
      ),
      AdviceLevel.caution => (
      tr('advice_caution'),
      Colors.orange.shade700,
      Icons.cloud
      ),
      AdviceLevel.avoid => (
      tr('advice_avoid'),
      Colors.red.shade600,
      Icons.thunderstorm
      ),
    };

    final checked = app.weatherCheckedAt;

    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenTab(_weatherTab),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 40, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(app.adviceReason,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 10),
              Text(
                app.placeName +
                    (checked == null
                        ? ''
                        : '  |  ${tr('home_checked', {'time': formatClock(checked)})}'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, MaterialColor color) {
    return Card(
      color: color.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: color.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Turn timer ----------

  Widget _timerCard(TimerController t) {
    final status = t.running
        ? tr('status_drying')
        : (t.paused ? tr('status_paused') : tr('status_ready'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer),
                const SizedBox(width: 8),
                Text(tr('timer_title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(status),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                TimerController.format(t.remainingSeconds),
                style:
                const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: Text(tr('timer_summary', {
                'n': '${t.intervalMinutes.round()}',
                'c': '${t.turnCount}',
              })),
            ),
            const SizedBox(height: 12),
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
                    label: Text(t.running ? tr('btn_pause') : tr('btn_resume')),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onOpenTab(_timerTab),
                child: Text(
                    t.idle ? tr('btn_change_interval') : tr('btn_open_timer')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Bird protection ----------

  String _pairingText(String? role) => switch (role) {
    'monitor' => tr('pair_monitor'),
    'receiver' => tr('pair_receiver'),
    _ => tr('pair_none'),
  };

  Widget _birdCard(AppState app) {
    final last = app.lastBirdAt;
    final lastAlert = app.lastAlertReceivedAt;
    final isReceiver = app.pairingRole == 'receiver';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pets),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr('bird_title'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: app.birdMonitoring ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(app.birdMonitoring
                    ? tr('bird_mon_on')
                    : tr('bird_mon_off')),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr('bird_today', {'n': '${app.birdsToday}'}) +
                (last == null
                    ? ''
                    : '  ${tr('bird_last', {'time': formatClock(last)})}')),
            const SizedBox(height: 6),
            Text(_pairingText(app.pairingRole)),
            if (isReceiver) ...[
              const SizedBox(height: 6),
              Text(lastAlert == null
                  ? tr('alert_none')
                  : tr('alert_last', {'time': formatClock(lastAlert)})),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onOpenTab(_monitorTab),
                child: Text(tr('btn_open_monitor')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Recent activity ----------

  IconData _iconFor(ActivityKind kind) => switch (kind) {
    ActivityKind.bird => Icons.pets,
    ActivityKind.turn => Icons.autorenew,
    ActivityKind.alert => Icons.notifications_active,
  };

  String _activityText(ActivityItem item) => switch (item.kind) {
    ActivityKind.bird => tr('act_bird'),
    ActivityKind.turn => tr('act_turn', {'n': '${item.n ?? ''}'}),
    ActivityKind.alert => tr('act_alert'),
  };

  Widget _activityCard(AppState app) {
    final items = app.activity.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text(tr('activity_title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(tr('activity_empty'))
            else
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(item.kind)),
                  title: Text(_activityText(item)),
                  trailing: Text(formatClock(item.time)),
                ),
          ],
        ),
      ),
    );
  }
}