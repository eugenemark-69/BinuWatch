# BinuWatch Technical Reference

This document summarizes the key implementation paths, algorithms, computational procedures, functions, and modules in BinuWatch. It describes the source as currently implemented.

## 1. System Overview

BinuWatch is a Flutter application for rice-drying management. It combines:

- Weather and rain-risk guidance
- A YOLO-based bird monitoring camera
- Optional Firestore pairing and cross-phone alerts
- A shared rice-turn countdown timer
- Persistent theme, language, and scare-sound settings

The app follows a lightweight singleton and `ChangeNotifier` architecture. Feature screens publish and consume shared state rather than using a larger state-management framework.

```text
main()
  -> Firebase.initializeApp()
  -> NotificationService.init()
  -> AppSettings.load()
  -> PairingService.startListening()
  -> runApp(BinuwadApp)
        -> IndexedStack
             HomeScreen
             MonitorHubScreen / BirdScreen
             WeatherScreen
             TimerScreen
             MenuScreen
```

## 2. Key Modules

| Module | Responsibility |
|---|---|
| `lib/main.dart` | Application startup, navigation shell, theme/language rebuild, and timer-finished dialog |
| `lib/app_state.dart` | Shared in-memory weather, bird, pairing, activity, and alert state |
| `lib/app_settings.dart` | Persistent theme, language, and scare-sound settings |
| `lib/timer_controller.dart` | Shared countdown logic and turn completion |
| `lib/screens/weather_screen.dart` | GPS, geocoding, weather retrieval, drying advice, and weather UI |
| `lib/screens/bird_screen.dart` | YOLO camera processing, temporal filtering, scare sound, and alert sending |
| `lib/pairing_service.dart` | Firebase anonymous authentication, pairing records, listener, and alert delivery |
| `lib/bird_alert_notifier.dart` | Android local notifications for received bird alerts |
| `lib/notification_service.dart` | Exact local alarm notifications for rice-turn reminders |
| `lib/strings.dart` | English and Bisaya/Cebuano translation lookup |
| `lib/screens/home_screen.dart` | Aggregated status dashboard |
| `lib/screens/monitor_hub_screen.dart` | Monitor/receiver pairing workflow |

## 3. Bird Detection Algorithm

The monitor uses Ultralytics YOLO through `YOLOView`.

### Consecutive-frame confirmation

A YOLO result is confirmed only after the bird is present in three consecutive inference frames. This temporal filter reduces one-frame flicker and false positives.

```dart
static const int _framesNeeded = 3;

bool get _birdAlert => _birdFrames >= _framesNeeded;

void _onResult(List<YOLOResult> results) {
  if (!mounted) return;

  final hasBird = results.any((r) => r.className == 'bird');
  if (hasBird) _lastBirdSeenAt = DateTime.now();

  setState(() {
    _birdFrames = hasBird ? _birdFrames + 1 : 0;
  });

  if (_birdAlert) {
    _beginEpisodeIfNeeded();
    _startSoundIfNeeded();
    _maybeSendAlert(results);
  }
}
```

The detection procedure is:

1. Receive a list of YOLO detections for the current frame.
2. Search for a result whose `className` is exactly `bird`.
3. Increment the consecutive positive-frame counter if a bird is found.
4. Reset the counter to zero if the frame contains no bird.
5. Begin a detection episode only when the counter reaches three.
6. Start looping the selected scare sound and send a remote alert if paired.

This is a state-machine-style filter where each processing frame is O(n), where n is the number of detections in the frame.

### Detection episode and inactivity grace period

The app groups sustained bird visibility into one episode. `_episodeActive` remains true until no bird has been seen for ten seconds.

```dart
watchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
  final seen = _lastBirdSeenAt;
  final gone = seen == null ||
      DateTime.now().difference(seen) >
          const Duration(seconds: 10);
  if (!gone) return;

  _episodeActive = false;
  if (_soundPlaying) _stopSound();
});
```

The grace period prevents the sound from cutting off and restarting due to an occasional missed camera frame.

### Maximum-confidence alert procedure

Before sending an alert, the app selects the largest confidence value among the bird detections in the current frame.

```dart
var best = 0.0;
for (final r in results) {
  if (r.className != 'bird') continue;
  final confidence = r.confidence.toDouble();
  if (confidence > best) best = confidence;
}

final result = await PairingService.instance.sendAlert(
  label: 'bird',
  confidence: best,
);
```

Outgoing alerts are limited to one attempt every two seconds by `_lastAlertAt`, but every accepted attempt is still subject to network and pairing state.

## 4. Pairing and Alert Algorithm

Pairing uses Firebase Anonymous Authentication and Cloud Firestore.

### Six-digit code generation

The monitor creates a cryptographically secure random number in the range 100000–999999 and checks that the Firestore document is unused.

```dart
final rng = Random.secure();

for (var i = 0; i < 8; i++) {
  final code = (100000 + rng.nextInt(900000)).toString();
  final ref = _ref(code);
  if ((await ref.get()).exists) continue;

  await ref.set({
    'monitorUid': uid,
    'receiverUid': null,
    'paired': false,
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 10)),
    ),
  });
  await _save(PairRole.monitor, code);
  return code;
}
```

The creation procedure performs up to eight collision checks. An existing code is skipped; an available code is stored with a ten-minute expiry.

### Receiver transaction

Joining the pairing uses a Firestore transaction so that the receiver UID and paired state are updated atomically.

```dart
await _db.runTransaction((tx) async {
  final snap = await tx.get(ref);
  if (!snap.exists) throw PairingException('Code not found.');

  final data = snap.data()!;
  final receiver = data['receiverUid'];
  if (receiver != null && receiver != uid) {
    throw PairingException('This code is already used by another phone.');
  }

  tx.update(ref, {
    'receiverUid': uid,
    'paired': true,
    'pairedAt': FieldValue.serverTimestamp(),
  });
});
```

The transaction rejects a code claimed by another UID and stores the receiver identity and pairing timestamp.

### Alert delivery

The monitor writes alert documents under the shared pairing:

```text
pairings/{code}/alerts/{alertId}
```

Each alert contains:

- `label`
- `confidence`
- `createdAt`

```dart
await _ref(saved.code).collection('alerts').add({
  'label': label,
  'confidence': confidence,
  'createdAt': FieldValue.serverTimestamp(),
}).timeout(const Duration(seconds: 8));
```

The return value distinguishes four outcomes:

| Result | Meaning |
|---|---|
| `sent` | Firestore write completed |
| `queued` | Eight-second timeout occurred; Firestore may deliver later when offline |
| `notPaired` | No saved monitor pairing exists |
| `failed` | Write failed and was logged |

### Receiver baseline and live updates

The receiver listener retrieves the last twenty alert documents. It skips the initial snapshot, treating it as historical data, then processes later `added` document changes.

```dart
var baselineDone = false;

_alertSub = _ref(saved.code)
    .collection('alerts')
    .orderBy('createdAt', descending: true)
    .limit(20)
    .snapshots()
    .listen((snap) {
  if (!baselineDone) {
    if (!snap.metadata.isFromCache) baselineDone = true;
    return;
  }

  for (final change in snap.docChanges) {
    if (change.type != DocumentChangeType.added) continue;
    final d = change.doc.data();
    BirdAlertNotifier.instance.show(
      label: (d['label'] as String?) ?? 'bird',
      confidence: (d['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
});
```

This is a foreground snapshot-listener procedure. It is not a Firebase Cloud Messaging push implementation.

## 5. Weather and Drying Procedure

### Location resolution

`getPlace()` resolves coordinates using this fallback chain:

1. Location service and permission check
2. Current GPS position with low accuracy and a fifteen-second limit
3. Last known position
4. Fixed Biliran fallback coordinates `(11.56, 124.40)`

The result distinguishes GPS-backed coordinates from the approximate fallback.

### Forecast retrieval

`fetchWeather()` requests Open-Meteo data with:

- Current temperature
- Relative humidity
- Precipitation
- Wind speed
- Cloud cover
- Hourly rain probability, temperature, and cloud cover
- Daily sunset
- Automatic timezone

It locates the hourly slot matching the current forecast hour and retains up to twenty-four hourly entries.

```dart
var start = times.indexWhere(
  (t) => t.startsWith(nowStr.substring(0, 13)),
);
if (start < 0) start = 0;

final end = (start + 24).clamp(0, slots.length);
hours: slots.sublist(start, end),
```

The search is linear with respect to hourly forecast entries. Sublist extraction is O(k), where k is the number of retained hours.

### Three-hour rain maximum

The weather model defines the rain probability for the next three hours as the maximum of the first three hourly entries.

```dart
int get rainChance3h => hours
    .take(3)
    .fold<int>(0, (a, h) => a > h.rainChance ? a : h.rainChance);
```

The complexity is O(3) in practice, or O(1) relative to the bounded three-hour window.

### Drying advice classification

The procedure uses ordered rules:

```dart
DryingAdvice adviceFor(WeatherData w) {
  if (w.precipitation > 0 || w.rainChance3h >= 60) {
    return DryingAdvice.avoid;
  }
  if (w.rainChance3h >= 30 || w.humidity >= 85) {
    return DryingAdvice.caution;
  }
  return DryingAdvice.good;
}
```

| Category | Condition |
|---|---|
| Avoid | Current precipitation is positive, or three-hour rain chance is at least 60% |
| Caution | Three-hour rain chance is at least 30%, or humidity is at least 85% |
| Good | None of the above conditions apply |

Cloud cover does not change the category; it is used only in the explanation text.

### Reverse geocoding

Nominatim reverse geocoding prefers municipality/city/town fields and falls back to county, province, or state. The procedure removes common administrative prefixes, such as “Municipality of” or “City of.”

## 6. Timer and Countdown Algorithm

`TimerController` is a singleton `ChangeNotifier` shared by the Home and Timer screens.

### Clock-derived countdown

The timer stores an absolute end timestamp and recalculates the remaining time from the device clock instead of decrementing a counter every tick.

```dart
void _begin() {
  _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
  _ticker = Timer.periodic(
    const Duration(seconds: 1),
    (_) => _tick(),
  );
}

void _updateRemaining() {
  final left = _endTime!.difference(DateTime.now());
  _remainingSeconds =
      left <= Duration.zero ? 0 : (left.inMilliseconds / 1000).ceil();
}
```

This makes the countdown recover from delayed ticks and locked or suspended UI updates.

### Interval lifecycle

| State | Behavior |
|---|---|
| Idle | Interval can be changed |
| Running | Stores end time, schedules a local turn alarm, ticks every second |
| Paused | Recalculates remaining seconds, cancels periodic tick and alarm |
| Resumed | Creates a new end time from the remaining seconds |
| Stopped | Resets remaining time and cancels alarm |
| Finished | Increment turn count, records activity, opens the turn-rice dialog |

### Turn completion

```dart
void _finish() {
  _ticker?.cancel();
  _ticker = null;
  _paused = false;
  _turnCount++;
  _remainingSeconds = _fullSeconds;

  AppState.instance.addActivity(
    ActivityKind.turn,
    n: _turnCount,
  );
  notifyListeners();
  finished.value++;
}
```

The root shell listens to `finished` and displays a blocking “turn the rice” dialog on whichever tab is open.

## 7. Shared Application State

`AppState` is a singleton `ChangeNotifier` used as an in-memory cross-feature repository.

Important state includes:

- Latest weather advice and reason
- Bird-monitoring status
- Bird detections for the current day
- Pairing role
- Last received alert timestamp
- Last thirty activity items

### Daily bird counter

The bird counter is reset without persistent storage when the first detection occurs on a new calendar day.

```dart
void recordBird() {
  final now = DateTime.now();
  if (lastBirdAt == null || !_sameDay(lastBirdAt!, now)) {
    _birdsToday = 0;
  }
  _birdsToday++;
  lastBirdAt = now;
  _addActivity(ActivityKind.bird);
  notifyListeners();
}
```

### Activity history

Activity insertion is newest-first. The list has a fixed bound of thirty entries:

```dart
_activity.insert(0, ActivityItem(DateTime.now(), kind, n: n));
if (_activity.length > 30) _activity.removeLast();
```

The list is exposed as `List.unmodifiable(...)`, while only timestamps and activity kinds/numbers are retained. This lets translations select text when the list is displayed.

## 8. Settings and Localization

`AppSettings` persists:

- `setting_theme`
- `setting_lang`
- `setting_sound`

Supported languages are English and Bisaya/Cebuano. Missing translation keys fall back to English.

Scare-sound selection has five options:

| ID | Behavior |
|---|---|
| `default` | Play `SO-sound.m4a` |
| `siren` | Play `scare.wav` |
| `pulse` | Play `pulse.wav` |
| `warble` | Play `warble.wav` |
| `rotate` | Choose a bundled asset randomly |

The random procedure is:

```dart
final files = [
  for (final option in soundOptions)
    if (option.asset != null) option.asset!,
];
return files[Random().nextInt(files.length)];
```

## 9. Main Startup Procedure

`main()` initializes services before creating the UI:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.init();
  await AppSettings.instance.load();

  PairingService.instance.startListening();
  PairingService.instance
      .loadSaved()
      .then((saved) => AppState.instance.setPairing(saved?.role.name));

  runApp(const BinuwadApp());
}
```

Pairing listener startup and saved-role loading are intentionally not awaited before `runApp`, so these operations do not block the first screen.

## 10. Computational and Data-Flow Summary

| Procedure | Input | Output | Complexity |
|---|---|---|---|
| YOLO frame confirmation | Detection list | Bird present/absent and episode state | O(n) per frame |
| Bird confidence selection | YOLO detection list | Maximum bird confidence | O(n) |
| Alert cooldown | Frame timestamp and last alert timestamp | Send or suppress | O(1) |
| Three-hour rain maximum | Hourly forecast entries | Maximum probability for first three hours | O(3) |
| Drying advice | Rain, humidity, precipitation | Good/caution/avoid | O(1) |
| Forecast hour alignment | Forecast time strings | Starting hourly index | O(m) |
| Countdown update | End timestamp and device clock | Remaining seconds | O(1) |
| Activity insertion | Activity type and optional turn number | Updated bounded history | O(1) insertion/O(30) bounded cleanup |
| Pairing code creation | Anonymous UID and Firestore | Six-digit code or exception | Up to eight reads/writes |
| Alert snapshot processing | Firestore alert changes | Notification and app activity update | O(k) for a snapshot batch |

## 11. External Dependencies and Data Services

| Service | Purpose | Location |
|---|---|---|
| Open-Meteo | Current and hourly weather forecast | `lib/screens/weather_screen.dart` |
| OpenStreetMap Nominatim | Reverse geocoding | `lib/screens/weather_screen.dart` |
| Firebase Authentication | Anonymous user identity | `lib/pairing_service.dart` |
| Cloud Firestore | Pairing records and alert subcollections | `lib/pairing_service.dart` |
| Ultralytics YOLO | On-device model inference | `lib/screens/bird_screen.dart` |
| Flutter Local Notifications | Rice-turn and received-bird notifications | `lib/notification_service.dart`, `lib/bird_alert_notifier.dart` |
| Geolocator | GPS and last-known location | `lib/screens/weather_screen.dart` |
| Shared Preferences | Persistent settings and local pairing state | `lib/app_settings.dart`, `lib/pairing_service.dart` |
