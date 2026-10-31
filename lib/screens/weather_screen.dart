import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Used only when GPS is unavailable: roughly the middle of Biliran province.
const double _fallbackLat = 11.56;
const double _fallbackLon = 124.40;

class PlaceInfo {
  final double lat;
  final double lon;
  final bool fromGps;
  PlaceInfo(this.lat, this.lon, this.fromGps);
}

// Tries the phone's location; falls back to the middle of Biliran.
Future<PlaceInfo> getPlace() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) throw 'GPS is off';

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'No location permission';
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // rough is enough for weather
        timeLimit: Duration(seconds: 15),
      ),
    );
    return PlaceInfo(pos.latitude, pos.longitude, true);
  } catch (_) {
    // Try the last position the phone remembers before giving up.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return PlaceInfo(last.latitude, last.longitude, true);
    } catch (_) {}
    return PlaceInfo(_fallbackLat, _fallbackLon, false);
  }
}

// Turns coordinates into a readable name like "Barangay, Town, Province"
// using OpenStreetMap's free Nominatim service. Returns '' on any failure
// (no internet, slow server, unknown place), so the screen falls back to
// showing the coordinates only.
Future<String> placeName(double lat, double lon) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lon',
      'zoom': '14',
      'addressdetails': '1',
      'accept-language': 'en',
    });
    final res = await http.get(uri, headers: {
      // Nominatim's usage policy requires an identifying User-Agent.
      'User-Agent': 'BinuwadApp/1.0 (student rice-drying project)',
    }).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return '';

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final a = (json['address'] as Map<String, dynamic>?) ?? {};

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = (a[k] as String?)?.trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final parts = <String>[];
    for (final s in [
      pick(['suburb', 'village', 'neighbourhood', 'hamlet']),
      pick(['city', 'town', 'municipality']),
      pick(['county', 'state_district', 'province']),
    ]) {
      if (s.isNotEmpty && !parts.contains(s)) parts.add(s);
    }
    if (parts.isEmpty) {
      final s = pick(['state']);
      if (s.isNotEmpty) parts.add(s);
    }
    return parts.join(', ');
  } catch (_) {
    return '';
  }
}

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
  final DateTime now; // current time AT THE FORECAST LOCATION
  final double temperature;
  final int humidity;
  final double precipitation; // mm falling right now
  final double windKmh;
  final int cloudCover;
  final List<HourSlot> hours; // starts at the current hour
  final DateTime sunset;
  final String timezone; // e.g. Asia/Manila
  final double lat;
  final double lon;
  String placeName; // filled in after the weather loads

  WeatherData({
    required this.now,
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windKmh,
    required this.cloudCover,
    required this.hours,
    required this.sunset,
    required this.timezone,
    required this.lat,
    required this.lon,
    this.placeName = '',
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

// Example: "Fri, Oct 30, 2:15 PM"
String _dateTime(DateTime t) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${days[t.weekday - 1]}, ${months[t.month - 1]} ${t.day}, ${_clock(t)}';
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

Future<WeatherData> fetchWeather(double lat, double lon) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$lat',
    'longitude': '$lon',
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
    timezone: (json['timezone'] as String?) ?? 'unknown',
    lat: lat,
    lon: lon,
  );
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<WeatherData> _future;
  bool _usingGps = false;

  Future<WeatherData> _load() async {
    final place = await getPlace();
    if (mounted) setState(() => _usingGps = place.fromGps);

    // Look up the place name while the weather downloads.
    final nameFuture = placeName(place.lat, place.lon);
    final weather = await fetchWeather(place.lat, place.lon);
    weather.placeName = await nameFuture;
    return weather;
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

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

  // Date, time and location of the forecast, with a warning if the forecast
  // location's clock disagrees with the phone's clock.
  Widget _buildWhereWhen(WeatherData w) {
    final phoneNow = DateTime.now();
    final mismatch = phoneNow.difference(w.now).abs() > const Duration(hours: 1);

    final name = w.placeName.isNotEmpty
        ? w.placeName
        : '${w.lat.toStringAsFixed(3)}, ${w.lon.toStringAsFixed(3)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.place),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _usingGps ? name : 'Approximate Biliran ($name)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                '${w.lat.toStringAsFixed(3)}, ${w.lon.toStringAsFixed(3)}'
                    '  |  ${w.timezone}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today),
              const SizedBox(width: 8),
              Expanded(child: Text(_dateTime(w.now))),
            ]),
            if (mismatch) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Warning: the forecast location says it is ${_clock(w.now)}, '
                      'but your phone clock says ${_clock(phoneNow)}. '
                      'The forecast may be for a different place than where you are. '
                      'On an emulator, set its location under Extended controls.',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ],
        ),
      ),
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
          // Where and when
          _buildWhereWhen(w),

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
          Center(
            child: Text(
              _usingGps
                  ? 'Using your phone location. Pull down to refresh.'
                  : 'GPS unavailable: using approximate Biliran location.',
              textAlign: TextAlign.center,
            ),
          ),
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