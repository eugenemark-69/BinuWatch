import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundOption {
  final String id;
  final String nameKey; // translation key, see strings.dart
  final String? asset; // null means "rotate between all the sounds"
  const SoundOption(this.id, this.nameKey, this.asset);
}

// Saved settings (theme, language, scare sound). Screens listen to this, so
// changing a setting updates the app straight away.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  // The files must exist in assets/sounds/.
  static const List<SoundOption> soundOptions = [
    SoundOption('default', 'sound_default', 'sounds/SO-sound.m4a'),
    SoundOption('siren', 'sound_siren', 'sounds/scare.wav'),
    SoundOption('pulse', 'sound_pulse', 'sounds/pulse.wav'),
    SoundOption('warble', 'sound_warble', 'sounds/warble.wav'),
    SoundOption('rotate', 'sound_rotate', null),
  ];

  ThemeMode themeMode = ThemeMode.system;
  String languageCode = 'en'; // 'en' = English, 'ceb' = Bisaya
  String soundId = 'default';

  SoundOption get soundOption => soundOptions.firstWhere(
        (o) => o.id == soundId,
    orElse: () => soundOptions.first,
  );

  // Called once in main() before the app starts.
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    languageCode = p.getString('setting_lang') ?? 'en';
    soundId = p.getString('setting_sound') ?? 'default';
    themeMode = switch (p.getString('setting_theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('setting_theme', mode.name);
  }

  Future<void> setLanguage(String code) async {
    languageCode = code;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('setting_lang', code);
  }

  Future<void> setSound(String id) async {
    soundId = id;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('setting_sound', id);
  }

  // A random one of the real sound files (used by "Rotate").
  String randomSoundAsset() {
    final files = [for (final o in soundOptions) if (o.asset != null) o.asset!];
    return files[Random().nextInt(files.length)];
  }

  // The file to play when a bird is detected.
  String pickSoundAsset() => soundOption.asset ?? randomSoundAsset();
}