import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_info.dart';
import '../../app_settings.dart';
import '../../strings.dart';

// ---------------------------------------------------------------------------
// Choose the scare sound
// ---------------------------------------------------------------------------

class SoundPickerPage extends StatefulWidget {
  const SoundPickerPage({super.key});

  @override
  State<SoundPickerPage> createState() => _SoundPickerPageState();
}

class _SoundPickerPageState extends State<SoundPickerPage> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _doneSub;
  String? _previewing; // id of the sound being previewed

  @override
  void initState() {
    super.initState();
    // The preview plays once, then stops by itself.
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewing = null);
    });
  }

  @override
  void dispose() {
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(SoundOption option) async {
    if (_previewing == option.id) {
      await _player.stop();
      if (mounted) setState(() => _previewing = null);
      return;
    }
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      await _player
          .play(AssetSource(option.asset ?? AppSettings.instance.randomSoundAsset()));
      if (mounted) setState(() => _previewing = option.id);
    } catch (e) {
      debugPrint('Sound preview error: $e');
      if (mounted) {
        setState(() => _previewing = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('sound_error'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('sound_title'))),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AppSettings.instance,
          builder: (context, _) {
            final s = AppSettings.instance;
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tr('sound_hint')),
                ),
                for (final option in AppSettings.soundOptions)
                  ListTile(
                    leading: Icon(
                      s.soundId == option.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: s.soundId == option.id
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(tr(option.nameKey)),
                    trailing: IconButton(
                      icon: Icon(_previewing == option.id
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline),
                      onPressed: () => _preview(option),
                    ),
                    onTap: () => s.setSound(option.id),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr('sound_tip'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Support
// ---------------------------------------------------------------------------

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      ('faq_sound_q', 'faq_sound_a'),
      ('faq_notif_q', 'faq_notif_a'),
      ('faq_weather_q', 'faq_weather_a'),
      ('faq_pair_q', 'faq_pair_a'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr('support_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('support_contact'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(supportEmail),
                trailing: TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                        const ClipboardData(text: supportEmail));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('support_copied'))));
                    }
                  },
                  child: Text(tr('support_copy')),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(tr('support_faq'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (q, a) in faqs)
              Card(
                child: ExpansionTile(
                  title: Text(tr(q)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(tr(a))],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About us
// ---------------------------------------------------------------------------

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('about_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.agriculture, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(tr('about_version', {'v': appVersion}),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text(tr('about_text'), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Text(tr('about_made_by'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final name in developers) Text(name),
            const SizedBox(height: 16),
            Text(tr('about_school'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text(schoolName),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Licenses
// ---------------------------------------------------------------------------

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  // Names and licenses stay in English on purpose: they are proper names.
  static const List<(String, String)> _credits = [
    ('Weather data', 'Open-Meteo.com (CC BY 4.0)'),
    ('Place names', '\u00a9 OpenStreetMap contributors (ODbL)'),
    ('Bird detection', 'Ultralytics YOLO (AGPL-3.0)'),
    ('Notifications and pairing', 'Google Firebase'),
    ('Built with', 'Flutter'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('lic_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(tr('lic_open_source')),
                subtitle: Text(tr('lic_open_source_sub')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: appName,
                  applicationVersion: appVersion,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('lic_credits'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (label, value) in _credits)
              ListTile(
                dense: true,
                title: Text(label),
                subtitle: Text(value),
              ),
          ],
        ),
      ),
    );
  }
}