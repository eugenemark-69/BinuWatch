import 'package:flutter/material.dart';
import '../../app_settings.dart';
import '../../strings.dart';
import 'menu_pages.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _sectionTitle(context, tr('menu_settings')),

            // Scare sound
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: Text(tr('menu_sound')),
              subtitle: Text(tr(s.soundOption.nameKey)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const SoundPickerPage()),
            ),

            // Language
            _controlTile(
              context,
              icon: Icons.language,
              title: tr('menu_language'),
              control: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ceb', label: Text('Bisaya')),
                ],
                selected: {s.languageCode},
                onSelectionChanged: (v) => s.setLanguage(v.first),
              ),
            ),

            // Theme
            _controlTile(
              context,
              icon: Icons.brightness_6,
              title: tr('menu_theme'),
              control: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(tr('theme_light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(tr('theme_dark')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.phone_android),
                    label: Text(tr('theme_system')),
                  ),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setTheme(v.first),
              ),
            ),

            const Divider(height: 32),
            _sectionTitle(context, tr('menu_more')),

            ListTile(
              leading: const Icon(Icons.support_agent),
              title: Text(tr('menu_support')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const SupportPage()),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(tr('menu_about')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const AboutPage()),
            ),
            ListTile(
              leading: const Icon(Icons.gavel),
              title: Text(tr('menu_licenses')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const LicensesPage()),
            ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _controlTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget control,
      }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 16),
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: control),
          ],
        ),
      );
}