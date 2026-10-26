import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Approximate location (Naval, Biliran area). Change to the drying site.
const double _lat = 11.56;
const double _lon = 124.40;

enum DryingAdvice { good, caution, avoid }

class HourSlot {
  final DateTime time;
  final int rainChance;
  final double temp;
  final int cloud;

  HourSlot({
    required this.time,
    required this.rainChance,
    required this.temp,
    required this.cloud,
  });
}

class WeatherData {
  final DateTime now;
  final double temperature;
  final int humidity;
  final double precipitation; // mm falling right now
  final double windKmh;
  final int cloudCover;
  final List<HourSlot> hours; // starts at the current hour
  final DateTime sunset;

  WeatherData({
    required this.now,
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windKmh,
    required this.cloudCover,
    required this.hours,
    required this.sunset,
  });

  // Highest rain chance over the next 3 hours.
  int get rainChance3h => hours
      .take(3)
      .fold<int>(0, (a, h) => a > h.rainChance ? a : h.rainChance);
}

// Starting rules only. Tune these with real drying experience.
DryingAdvice adviceFor(WeatherData w) {
  if (w.precipitation > 0 || w.rainChance3h >= 60) return DryingAdvice.avoid;
  if (w.rainChance3h >= 30 || w.humidity >= 85) return DryingAdvice.caution;
  return DryingAdvice.good;
}

// Plain-language reasons shown under the advice.
List<String> reasonsFor(WeatherData w) {
  final reasons = <String>[];
  if (w.precipitation > 0) reasons.add('It is raining right now.');
  if (w.rainChance3h >= 60) {
    reasons.add('Rain chance is up to ${w.rainChance3h}% in the next 3 hours.');
  } else if (w.rainChance3h >= 30) {
    reasons.add('Some chance of rain (${w.rainChance3h}%) in the next 3 hours.');
  }
  if (w.humidity >= 85) {
    reasons.add('Humidity is high (${w.humidity}%), so rice dries slowly.');
  }
  if (w.cloudCover >= 80) {
    reasons.add('Heavy cloud cover (${w.cloudCover}%) means less sun.');
  }
  if (reasons.isEmpty) {
    reasons.add('Low chance of rain and the humidity is fine.');
    if (w.cloudCover <= 40) reasons.add('Skies are fairly clear, good sun.');
  }
  return reasons;
}

String _hour(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String rainOutlook(WeatherData w) {
  if (w.precipitation > 0) return 'It is raining now.';
  final i = w.hours.indexWhere((h) => h.rainChance >= 50);
  if (i < 0) {
    return 'No significant rain expected in the next ${w.hours.length} hours.';
  }
  if (i == 0) return 'Rain is likely this hour.';
  return 'Rain likely around ${_hour(w.hours[i].time)} '
      '(in about $i hr${i == 1 ? '' : 's'}).';
}

String daylightLeft(WeatherData w) {
  final left = w.sunset.difference(w.now);
  if (left.isNegative) return 'The sun has already set.';
  return 'Sunset at ${_clock(w.sunset)} '
      '(${left.inHours}h ${left.inMinutes % 60}m of daylight left).';
}

Future<WeatherData> fetchWeather() async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$_lat',
    'longitude': '$_lon',
    'current':
    'temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m',
    'hourly': 'precipitation_probability,temperature_2m,cloud_cover',
    'daily': 'sunset',
    'forecast_days': '2',
    'timezone': 'auto',
  });

  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw Exception('Weather server error (${res.statusCode})');
  }

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final current = json['current'] as Map<String, dynamic>;
  final hourly = json['hourly'] as Map<String, dynamic>;
  final daily = json['daily'] as Map<String, dynamic>;

  final times = (hourly['time'] as List).cast<String>();
  final probs = hourly['precipitation_probability'] as List;
  final temps = hourly['temperature_2m'] as List;
  final clouds = hourly['cloud_cover'] as List;

  final slots = <HourSlot>[
    for (var i = 0; i < times.length; i++)
      HourSlot(
        time: DateTime.parse(times[i]),
        rainChance: (probs[i] as num?)?.toInt() ?? 0,
        temp: (temps[i] as num?)?.toDouble() ?? 0,
        cloud: (clouds[i] as num?)?.toInt() ?? 0,
      ),
  ];

  // Start from the hour that matches "now" and keep up to 24 hours.
  final nowStr = current['time'] as String;
  var start = times.indexWhere((t) => t.startsWith(nowStr.substring(0, 13)));
  if (start < 0) start = 0;
  final end = (start + 24).clamp(0, slots.length);

  return WeatherData(
    now: DateTime.parse(nowStr),
    temperature: (current['temperature_2m'] as num).toDouble(),
    humidity: (current['relative_humidity_2m'] as num).toInt(),
    precipitation: (current['precipitation'] as num).toDouble(),
    windKmh: (current['wind_speed_10m'] as num).toDouble(),
    cloudCover: (current['cloud_cover'] as num).toInt(),
    hours: slots.sublist(start, end),
    sunset: DateTime.parse((daily['sunset'] as List).first as String),
  );
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<WeatherData> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchWeather();
  }

  void _refresh() => setState(() => _future = fetchWeather());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not load weather.\nCheck your internet.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        return _buildContent(snapshot.data!);
      },
    );
  }

  Widget _buildContent(WeatherData w) {
    final advice = adviceFor(w);

    final (label, color, icon) = switch (advice) {
      DryingAdvice.good => ('Good to dry', Colors.green.shade600, Icons.wb_sunny),
      DryingAdvice.caution => ('Caution', Colors.orange.shade700, Icons.cloud),
      DryingAdvice.avoid =>
      ('Avoid drying', Colors.red.shade600, Icons.thunderstorm),
    };

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Advice + reasons
          Card(
            color: color,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 40, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final r in reasonsFor(w))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $r',
                          style: const TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
          ),

          // Decision helper
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.umbrella),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rainOutlook(w))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.wb_twilight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(daylightLeft(w))),
                  ]),
                ],
              ),
            ),
          ),

          // Next 12 hours
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Next 12 hours',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: w.hours.length < 12 ? w.hours.length : 12,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _HourCard(slot: w.hours[i], isNow: i == 0),
            ),
          ),

          // Current conditions
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Right now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _InfoTile(
              icon: Icons.thermostat,
              label: 'Temperature',
              value: '${w.temperature.toStringAsFixed(1)} °C'),
          _InfoTile(
              icon: Icons.water_drop,
              label: 'Humidity',
              value: '${w.humidity}%'),
          _InfoTile(
              icon: Icons.air,
              label: 'Wind',
              value: '${w.windKmh.toStringAsFixed(0)} km/h'),
          _InfoTile(
              icon: Icons.cloud_queue,
              label: 'Cloud cover',
              value: '${w.cloudCover}%'),
          const SizedBox(height: 8),
          const Center(child: Text('Pull down to refresh')),
        ],
      ),
    );
  }
}

class _HourCard extends StatelessWidget {
  final HourSlot slot;
  final bool isNow;

  const _HourCard({required this.slot, required this.isNow});

  @override
  Widget build(BuildContext context) {
    final IconData icon = slot.rainChance >= 50
        ? Icons.water_drop
        : (slot.cloud >= 70 ? Icons.cloud : Icons.wb_sunny);

    return Card(
      color: isNow ? Theme.of(context).colorScheme.primaryContainer : null,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isNow ? 'Now' : _hour(slot.time),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Icon(icon),
            const SizedBox(height: 6),
            Text('${slot.rainChance}%'),
            Text('${slot.temp.round()}°'),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}