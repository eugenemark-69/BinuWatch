import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _StatusCard(
          icon: Icons.pets,
          title: 'Bird Protection',
          subtitle: 'No detections yet',
        ),
        _StatusCard(
          icon: Icons.wb_sunny,
          title: 'Weather',
          subtitle: 'Drying advice coming soon',
        ),
        _StatusCard(
          icon: Icons.timer,
          title: 'Turn Timer',
          subtitle: 'Not running',
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}