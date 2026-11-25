import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'app_state.dart';
import 'firebase_options.dart';
import 'notification_service.dart';
import 'pairing_service.dart';
import 'strings.dart';
import 'timer_controller.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/monitor_hub_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/timer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();

  // Load the saved theme, language and sound before the first screen shows.
  await AppSettings.instance.load();

  // Not awaited on purpose: these must not delay the app from opening.
  // Start listening for alerts if this phone is a paired receiver, and tell
  // the Home screen whether this phone is paired.
  PairingService.instance.startListening();
  PairingService.instance
      .loadSaved()
      .then((saved) => AppState.instance.setPairing(saved?.role.name));

  runApp(const BinuwadApp());
}

class BinuwadApp extends StatelessWidget {
  const BinuwadApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app when the theme or language changes.
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          title: 'BinuWatch',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: Colors.green,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: settings.themeMode,
          // The key makes the screens start fresh when the language changes,
          // so every word is shown again in the new language.
          home: MainShell(key: ValueKey(settings.languageCode)),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Remembered across a language change, so you stay on the Menu tab.
  static int _lastTab = 0;

  int _selectedIndex = _lastTab;

  void _selectTab(int i) {
    _lastTab = i;
    setState(() => _selectedIndex = i);
  }

  @override
  void initState() {
    super.initState();
    TimerController.instance.finished.addListener(_onTimerFinished);
  }

  @override
  void dispose() {
    TimerController.instance.finished.removeListener(_onTimerFinished);
    super.dispose();
  }

  // Shows the "turn the rice" dialog on whichever tab is open.
  void _onTimerFinished() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.alarm, size: 48),
        title: Text(tr('dlg_turn_title')),
        content: Text(tr('dlg_turn_body')),
        actions: [
          FilledButton(
            onPressed: () {
              NotificationService.instance.stopAlarm();
              Navigator.of(ctx).pop();
            },
            child: Text(tr('dlg_stop_alarm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BinuWatch')),
      // IndexedStack keeps each screen alive, so the weather loads at start
      // and the Monitor tab keeps its state when you switch tabs.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(onOpenTab: _selectTab),
          const MonitorHubScreen(),
          const WeatherScreen(),
          const TimerScreen(),
          const MenuScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home), label: tr('nav_home')),
          NavigationDestination(
              icon: const Icon(Icons.pets), label: tr('nav_monitor')),
          NavigationDestination(
              icon: const Icon(Icons.wb_sunny), label: tr('nav_weather')),
          NavigationDestination(
              icon: const Icon(Icons.timer), label: tr('nav_timer')),
          NavigationDestination(
              icon: const Icon(Icons.menu), label: tr('nav_menu')),
        ],
      ),
    );
  }
}