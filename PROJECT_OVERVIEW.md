# BinuWatch - Project Overview

## What this project is

BinuWatch (the package and some platform metadata still use the template name
`binuwad_v1`) is a Flutter app intended to help rice farmers in Biliran,
Philippines manage outdoor rice drying. It combines local weather guidance,
turning reminders, camera-based bird detection, locally played deterrent sounds,
and optional alerts between two paired phones.

The app is a client application, not a backend service. It gets forecast and
place-name data from public web APIs and uses Firebase Authentication and
Cloud Firestore for pairing and exchanging bird alerts. Bird detection is
performed in the app through the Ultralytics YOLO Flutter plugin.

## Main capabilities

### Home dashboard

The home tab brings together the latest drying advice, timer state, bird
monitoring/pairing status, today's bird count, and up to six recent activity
items. It links directly to the relevant feature tabs and warns when rice is
being dried while the weather advice is caution or avoid.

Recent activity is held in memory (up to 30 entries); it is not persisted.
Bird count is also in memory and is shown as today's count based on the time
of the most recent detection.

### Weather and drying guidance

The Weather tab:

- Requests low-accuracy device location. If unavailable, it tries the last
  known position, then uses a fixed approximate location in Biliran
  (11.56, 124.40).
- Reverse-geocodes coordinates to a municipality/place name where available.
- Displays current temperature, humidity, precipitation, wind and cloud
  cover; a 12-hour hourly strip; rain outlook; and time remaining until sunset.
- Provides a pull-to-refresh action and retains previously loaded data if a
  refresh fails.
- Publishes the current advice to the Home tab.

The advice is a simple heuristic, not a guarantee or a substitute for checking
local conditions:

| Advice | Current implementation |
|---|---|
| Avoid drying | Current precipitation is above zero, or the maximum rain probability in the next three hours is at least 60%. |
| Caution | Otherwise, rain probability in the next three hours is at least 30%, or relative humidity is at least 85%. |
| Good to dry | None of the preceding conditions apply. |

Cloud cover contributes to the explanatory text, but does not independently
change the advice category.

### Bird monitor and scare sounds

The Monitor tab can open a camera screen on the phone without pairing. The
screen uses `YOLOView` with model path `yolo26n` and looks for results whose
class name is exactly `bird`. The app asks for three consecutive bird-positive
frames before treating a detection as an event. It plays the selected bundled
sound in a loop while the bird is present, and stops after ten seconds without
a detection. A new event increments the detection count and Home activity.

Users can choose Default, Siren, Pulse, Warble, or Rotate (random sound) and
preview sounds from Menu. The chosen option is stored locally. The app expects
internet access the first time the model is downloaded.

If paired as a monitor, the app sends the best bird confidence from a frame to
the other phone, with a two-second minimum interval between sends. The
monitor screen reports sent, queued, not paired, or failed status.

### Phone pairing and bird alerts

Pairing uses two roles:

1. The monitor phone signs in anonymously to Firebase and creates a random
   six-digit pairing code. The code is considered valid for ten minutes.
2. The receiver phone enters the code; a Firestore transaction associates its
   anonymous user ID with the pairing record.
3. While the receiver app is running and listening, newly added alert records
   cause a local notification. The receiver screen also displays the five
   most recent alerts.

The receiver listener intentionally skips existing alert history when it
starts. The UI instructs users to keep the receiver app open or running in the
background. This is a Firestore listener plus local notifications; the code
does not implement Firebase Cloud Messaging or a separate push-notification
backend.

Unpairing deletes the shared Firestore pairing document when possible and
clears local pairing state. “Start over” clears only the local state.

### Rice-turn timer and notifications

The Timer tab and Home timer card control the same app-wide countdown. The
interval is adjustable from 5 to 120 minutes in five-minute steps while the
timer is idle. The timer can be started, paused, resumed, or stopped; each
completed interval increments a turn count, records activity, and displays a
dialog asking the user to turn the rice.

When started or resumed, the app also schedules an exact-while-idle local
notification alarm. Pausing/stopping cancels scheduled notifications. The
countdown uses an end timestamp so it can recalculate remaining time after a
pause in UI updates. Timer state and progress are not saved across app
restarts.

### Settings, support and language

- Theme: light, dark, or follow system.
- Language: English or Bisaya/Cebuano. Strings are kept in `lib/strings.dart`
  and missing translations fall back to English. Some feature screens still
  contain hard-coded English text, so localization is not yet complete.
- Scare sound: saved sound choice and preview playback.
- Support page: displays contact information and in-app FAQ entries.
- About page: displays the app name/version, developer and school details.
- Licenses page: opens Flutter's bundled dependency-license view and lists
  data/software credits.

The Support FAQ covers scare-sound playback, notification delivery, weather
location/forecast refresh, and phone pairing.

Theme, language and sound settings, as well as local pairing role/code, are
stored using `shared_preferences`.

The About information currently identifies the developer as Andoy, Eugene
Mark P. and Biliran Province State University (BiPSU). Contact and attribution
values are maintained in `lib/app_info.dart`.

## User interface and architecture

The root is `BinuwadApp` in `lib/main.dart`. It initializes Firebase,
notifications, and saved settings, then creates a Material 3 app with a
five-destination bottom navigation shell. An `IndexedStack` preserves tab
state. The main tab destinations are Home, Monitor, Weather, Timer and Menu.

The code is organized as a small Flutter app with singleton services and
`ChangeNotifier` state rather than a separate domain/backend package:

| Path | Responsibility |
|---|---|
| `lib/main.dart` | Startup, Firebase initialization, theme, navigation shell and timer-finished dialog. |
| `lib/app_state.dart` | Shared in-memory weather, bird, pairing and recent-activity state. |
| `lib/app_settings.dart` | Persistent theme/language/sound settings and sound selection. |
| `lib/pairing_service.dart` | Anonymous sign-in, pairing lifecycle, Firestore records and alert listener/sending. |
| `lib/notification_service.dart` | Scheduled rice-turn alarm notifications. |
| `lib/bird_alert_notifier.dart` | Local notifications shown for received bird alerts. |
| `lib/timer_controller.dart` | Shared countdown state and timer lifecycle. |
| `lib/strings.dart` | English and Bisaya/Cebuano string map and translation lookup. |
| `lib/app_info.dart` | App version and About/Support contact and attribution details. |
| `lib/firebase_options.dart` | FlutterFire-generated Firebase client configuration by platform. |
| `lib/screens/home_screen.dart` | Dashboard and activity summary. |
| `lib/screens/monitor_hub_screen.dart` | Monitor/receiver selection, pairing UI and recent alerts. |
| `lib/screens/bird_screen.dart` | Camera, YOLO results, scare sound and outgoing alert UI. |
| `lib/screens/weather_screen.dart` | Location, weather API, advice calculations and forecast UI. |
| `lib/screens/timer_screen.dart` | Timer interval and countdown UI. |
| `lib/screens/menu_screen.dart`, `lib/screens/menu_pages.dart` | Settings, sound picker, Support, About and license pages. |
| `assets/sounds/` | Bundled audio played by the bird monitor. |
| `test/widget_test.dart` | Existing Flutter widget test file (currently still the starter counter test; see project notes). |

## External APIs, services and data model

### Weather service - Open-Meteo

`lib/screens/weather_screen.dart` makes an unauthenticated HTTPS GET request to
`https://api.open-meteo.com/v1/forecast`. It requests:

- Current temperature at 2 m, relative humidity at 2 m, precipitation, cloud
  cover and wind speed at 10 m.
- Hourly precipitation probability, temperature and cloud cover.
- Daily sunset, with a two-day forecast and automatic timezone.

The app does not include an Open-Meteo API key. Network calls time out after
ten seconds.

### Reverse geocoding - OpenStreetMap Nominatim

The app calls `https://nominatim.openstreetmap.org/reverse` with latitude,
longitude, JSON format, zoom level 10, address details and English language.
It sends an identifying User-Agent. The municipality/city/town is preferred;
the province or other available administrative area is used as a fallback.
This request times out after eight seconds. Place-name lookup failure does not
prevent the weather forecast from being displayed.

### Firebase - anonymous auth and Cloud Firestore

The configured Firebase project is identified in app configuration as
`binuwad-ac209`. The app uses anonymous Firebase Authentication and Firestore;
it has no custom HTTP API server or Cloud Functions in this repository.

Firestore records used by the app:

```text
pairings/{sixDigitCode}
  monitorUid: string
  receiverUid: string | null
  paired: boolean
  createdAt: server timestamp
  expiresAt: timestamp
  pairedAt: server timestamp (after joining)

pairings/{sixDigitCode}/alerts/{alertId}
  label: string
  confidence: number
  createdAt: server timestamp
```

The receiver watches the newest 20 alert documents for new arrivals and reads
the newest five for the visible alert history. Pairing code expiration is
checked when a receiver joins; the app does not itself configure automatic
server-side deletion of expired records.

Firebase platform configuration is kept in `lib/firebase_options.dart` and
Android's `android/app/google-services.json`. The report intentionally does
not reproduce client configuration values. Firebase client configuration is
not a substitute for secure Firestore rules. No Firestore rules or indexes
file is present in the repository inventory; provision and review backend
rules in Firebase before deploying this app.

### Location and device APIs

`geolocator` obtains location after checking/requesting permission and
attempting to use the device's location services. Android declares internet,
camera, notification, exact-alarm, vibration and coarse/fine location
permissions in `android/app/src/main/AndroidManifest.xml`.

### Data flow and privacy notes

- When GPS is available, the device coordinates are sent to Open-Meteo and
  Nominatim to obtain forecast and place-name data. If GPS is unavailable, the
  fixed Biliran fallback coordinates are used instead.
- Firebase stores an anonymous user ID with the pairing record, the pairing
  code and state, and alert labels/confidence/timestamps. The client does not
  explicitly upload camera frames; its pairing alert payload contains a
  generic `bird` label and confidence value.
- Theme, language, scare-sound selection and local pairing credentials are
  stored on-device with `shared_preferences`. Recent activity and timer
  progress are held in process memory.
- No privacy-policy document or data-retention configuration is present in
  the repository. Confirm data handling and retention with the backend and
  external services before release.

## Technologies and dependencies

The package is a Flutter/Dart app. `pubspec.yaml` declares Dart SDK
compatibility `^3.13.7`, app version `1.0.0+1`, and these direct dependencies:

| Dependency | Constraint | Use |
|---|---:|---|
| `flutter` | SDK | UI framework and platform runtime. |
| `cupertino_icons` | `^1.0.8` | Cupertino icon assets. |
| `flutter_local_notifications` | `^22.3.3` | Scheduled timer alarm and received-alert notifications. |
| `timezone` | `^0.11.2` | Timezone database and zoned notification scheduling. |
| `http` | `^1.6.0` | Open-Meteo and Nominatim HTTPS requests. |
| `ultralytics_yolo` | `^0.7.1` | YOLO camera inference and results. |
| `audioplayers` | `^6.8.1` | Sound previews and looping bird deterrent audio. |
| `geolocator` | `^14.0.1` | Device location and permission handling. |
| `firebase_core` | `^5.1.0` | Firebase initialization. |
| `firebase_auth` | `^7.0.1` | Anonymous Firebase sign-in. |
| `cloud_firestore` | `^7.1.0` | Pairing and alert records/realtime updates. |
| `shared_preferences` | `^2.5.6` | Local preferences and pairing state. |

Development dependencies are `flutter_test` (SDK) and `flutter_lints`
(`^6.0.0`). The `pubspec.lock` file records resolved package versions.
Flutter's Material 3 widgets and Material icons are used for the interface.

## Bundled assets

The Flutter asset declaration includes all files under `assets/sounds/`:

| File | Configured use |
|---|---|
| `SO-sound.m4a` | Default deterrent sound. |
| `scare.wav` | Siren option. |
| `pulse.wav` | Pulse beeps option. |
| `warble.wav` | Warble option. |

In the current checkout, `assets/sounds/scare.wav` is zero bytes, so the Siren
sound option is not a usable audio asset until a valid file is supplied.

## Platforms and build configuration

The repository contains Flutter platform projects for Android, iOS, macOS,
Windows, Linux and web. Android includes Google Services Gradle configuration
and local-notification receivers. iOS/macOS contain standard Flutter runner
projects, and web contains the standard Flutter bootstrap and web manifest.

Platform scaffolding does not mean every feature is configured or verified on
every platform. `DefaultFirebaseOptions` explicitly throws for Linux because
no Linux Firebase configuration is present. Android is the most fully
configured target in this checkout. Notifications and camera/model plugin
behavior on other targets should be checked before promising support.

The Android application ID and iOS bundle identifier still use
`com.example...` values. Android's release build currently signs with the
debug signing configuration. These template settings must be replaced for a
production release. The checked-in Android build configuration uses Java 17,
Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin 2.4.0 and Google Services
Gradle plugin 4.4.4; SDK/NDK versions are delegated to the Flutter SDK
configuration.

## Licensing and attribution

There is no repository-level `LICENSE`, `COPYING` or `NOTICE` file in the
current checkout, so the license for BinuWatch's own source code is not
declared here. Do not infer that the app is open source or freely
redistributable until its owner chooses and adds a project license.

The in-app Credits list (`lib/screens/menu_pages.dart`) currently names:

| Item | Credit/license shown in app |
|---|---|
| Weather data | Open-Meteo.com - CC BY 4.0 |
| Place names | OpenStreetMap contributors - ODbL |
| Bird detection | Ultralytics YOLO - AGPL-3.0 |
| Notifications and pairing | Google Firebase |
| Framework | Flutter |

The app also exposes Flutter's generated third-party package license page via
`showLicensePage`. Review the applicable licenses and service terms for the
exact packages, model, and distribution method before release. In particular,
verify the obligations associated with the selected Ultralytics model/runtime
and confirm the rights to distribute the bundled audio files.

## Local development

Prerequisites: a Flutter SDK with a Dart SDK satisfying the constraint in
`pubspec.yaml`, plus platform toolchains for the platform being run.

Typical commands:

```powershell
flutter pub get
flutter analyze
flutter run
```

For Android, ensure the Firebase Android app configuration matches the
application ID, enable Anonymous Authentication in Firebase, create/provision
Cloud Firestore, and deploy restrictive rules that permit only intended
participants to access pairing and alert data. For camera monitoring, grant
camera access and allow the YOLO model's first download to complete. For
weather, allow location access (or expect the Biliran fallback) and internet
access.

## Known gaps and onboarding notes

- `README.md`, `pubspec.yaml`, `web/manifest.json` and `web/index.html` still
  contain Flutter starter-project descriptions rather than product-specific
  documentation.
- `test/widget_test.dart` is the original counter smoke test and imports
  `MyApp`, which is not defined in the current app; the current app root is
  `BinuwadApp`. The starter test therefore needs updating before it can serve
  as meaningful coverage.
- `assets/sounds/scare.wav` is empty, as noted above.
- The project has no top-level source license and no Firestore security-rules
  file checked in. Both should be addressed before external distribution.
- Firebase options have no Linux entry, timer/pairing state is not fully
  persisted across app restarts, and receiving live bird alerts depends on the
  receiver's Firestore listener being active.
- Product information and English/Bisaya strings live directly in Dart source.
  Update `lib/app_info.dart` and the translations when changing contact,
  developer, school, version, or user-facing copy.

This document describes the source and configuration present in this
repository checkout; it does not claim that every target platform or external
Firebase deployment has been tested.
