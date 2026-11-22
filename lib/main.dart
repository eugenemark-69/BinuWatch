import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'firebase_options.dart';
import 'notification_service.dart';
import 'pairing_service.dart';
import 'timer_controller.dart';
import 'screens/home_screen.dart';
import 'screens/monitor_hub_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/timer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();

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
    return MaterialApp(
      title: 'BinuWatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

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
        title: const Text('Time to turn the rice!'),
        content: const Text('Turn (karaw) the rice, then stop the alarm.'),
        actions: [
          FilledButton(
            onPressed: () {
              NotificationService.instance.stopAlarm();
              Navigator.of(ctx).pop();
            },
            child: const Text('Stop alarm'),
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
          HomeScreen(onOpenTab: (i) => setState(() => _selectedIndex = i)),
          const MonitorHubScreen(),
          const WeatherScreen(),
          const TimerScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Monitor'),
          NavigationDestination(icon: Icon(Icons.wb_sunny), label: 'Weather'),
          NavigationDestination(icon: Icon(Icons.timer), label: 'Timer'),
        ],
      ),
    );
  }
}