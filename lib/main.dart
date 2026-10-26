import 'notification_service.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/bird_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/timer_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
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

  final List<Widget> _screens = const [
    HomeScreen(),
    BirdScreen(),
    WeatherScreen(),
    TimerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BinuWatch')),
      // IndexedStack keeps each screen alive, so the timer keeps running
      // when you switch tabs.
      body: IndexedStack(index: _selectedIndex, children: _screens),
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