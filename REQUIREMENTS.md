# BinuWatch Requirements

This document lists the hardware, software, operating-system, development, server, database, network, and deployment requirements for BinuWatch.

Requirements marked **Minimum** allow the app to be built or run. Requirements marked **Recommended** improve reliability, especially for YOLO camera inference and rice-drying use.

## 1. Target Device Requirements

### Minimum Android device requirements

| Area | Minimum | Notes |
|---|---|---|
| OS | Android device supported by the Flutter and plugin versions used | The project does not explicitly pin `minSdk`; it is resolved from `flutter.minSdkVersion`. |
| Architecture | ARM64 (`arm64-v8a`) or target ABI supported by the Ultralytics YOLO plugin | ARM64 is recommended for practical inference. |
| RAM | 3 GB | 4 GB or more is recommended because the camera and inference plugin run together. |
| Storage | 500 MB free | Allows app files, cached model data, system assets, and updates. |
| Camera | Rear or integrated camera | Required for real bird monitoring. |
| GPS | GPS or an alternate location provider | The app can fall back to last-known or approximate coordinates. |
| Internet | Required for initial setup and most remote features | Required for Firebase, Open-Meteo, Nominatim, and initial YOLO model download. |
| Display | 320 dp-wide or larger | The UI should use responsive Flutter layouts. |

### Recommended Android device requirements

| Area | Recommended |
|---|---|
| OS | Android 10 or newer |
| Architecture | 64-bit ARM |
| RAM | 4–6 GB or more |
| Storage | 1 GB free |
| Camera | Rear camera with adequate outdoor resolution and low-latency autofocus |
| Network | Stable 4G/Wi-Fi or reliable mobile data |
| Location | Device GPS enabled |
| Notifications | Exact-alarm permission available where required by the OS |

### iOS and other platforms

The repository contains iOS, macOS, Linux, Windows, and web scaffolding, but BinuWatch is primarily configured and tested as an Android application.

- iOS can require the equivalent Firebase, camera, location, and notification configuration.
- iOS camera and location usage descriptions are not currently confirmed in the repository.
- Local notifications use Android-specific channel and exact-alarm settings.
- Linux initialization is explicitly unsupported in `lib/firebase_options.dart`.
- Windows and web use Firebase client configurations, but camera, notification, location, and YOLO behavior is not confirmed by a platform build matrix.

Supported end-user production targets should therefore be declared before the app is released outside Android.

## 2. Software Requirements for End Users

### Android runtime

- Android operating system
- Google Play Services for the Firebase configuration on devices that require it
- Internet connectivity or the ability to restore connectivity
- Camera permission
- Location permission for GPS weather; approximate fallback also works without GPS in some circumstances
- Notification permission for bird alerts and rice-turn alarms
- Firebase Anonymous Authentication support
- The Ultralytics YOLO model/runtime and downloaded model resources

The app declares the following Android permissions:

- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `VIBRATE`
- `INTERNET`
- `CAMERA`
- `USE_EXACT_ALARM`
- `SCHEDULE_EXACT_ALARM`
- `USE_FULL_SCREEN_INTENT`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`

### Required external services

| Service | Use |
|---|---|
| Firebase Authentication | Anonymous pair identities |
| Cloud Firestore | Pairing records and bird alerts |
| Open-Meteo | Weather and forecast data |
| OpenStreetMap Nominatim | Reverse geocoding |
| Internet/DNS access | Service and API communication |

The app may continue to display last successful weather data after a failed refresh. It does not implement a local database or weather server.

## 3. Development Computer Requirements

### Minimum Windows development environment

The current development environment used for this repository is:

| Component | Current/Reference Version |
|---|---|
| Operating system | Windows 11, 64-bit |
| Flutter | 3.47.8 stable |
| Dart | 3.13.7 |
| DevTools | 2.60.0 |
| Android SDK | Platform 37, build-tools 36.0.0 |
| Android SDK Manager | Installed under the local Android SDK directory |
| Java | JDK 17 minimum for the project; JDK 25 observed in the current environment |
| Android Studio | Recommended for Android SDK, emulator, device debugging, and JDK management |
| Gradle | 9.3.1 through the project wrapper |
| Android Gradle Plugin | 9.1.0 |
| Kotlin Android Plugin | 2.4.0 |
| Google Services Plugin | 4.4.4 |

The project also declares:

- Dart SDK constraint: `>=3.13.7 <4.0.0`
- Flutter constraint observed in `pubspec.lock`: Flutter `>=3.44.0`

### Minimum development computer

| Component | Minimum |
|---|---|
| CPU | 64-bit quad-core processor |
| RAM | 16 GB |
| Free storage | 20 GB for Flutter, Android SDK, caches, build output, and emulator |
| Operating system | 64-bit Windows 10/11, macOS, or Linux |
| Internet | Broadband for dependency, SDK, plugin, and Firebase downloads |
| USB port | One available port for physical Android debugging |

### Recommended development computer

| Component | Recommended |
|---|---|
| CPU | 8 cores or more |
| RAM | 32 GB |
| Free storage | 30–50 GB SSD storage |
| GPU | Hardware acceleration for Android emulator and YOLO testing |
| Screen | 1920×1080 or larger |

Android builds require an internet connection for initial dependency resolution and Gradle downloads.

## 4. Development Software

Required tools:

- Flutter SDK
- Dart SDK included with Flutter
- Android Studio or Android command-line tools
- Android SDK Platform 36/37
- Android build-tools 36
- Android SDK Platform Tools
- Java JDK compatible with Android Gradle Plugin 9.1.0
- Git
- Firebase CLI for configuration, emulator, rules deployment, and project administration
- FlutterFire CLI for regenerating `firebase_options.dart` and platform configuration

Recommended tools:

- Android physical device for camera, GPS, notification, and wake-lock testing
- Android emulator for basic widget and platform testing
- Firebase Emulator Suite for Authentication and Firestore tests
- Chrome for web testing if web support is enabled
- VS Code or Android Studio for editing and debugging

## 5. Android Build Requirements

The Android build configuration uses:

- Java source and target compatibility: Java 17
- Kotlin JVM target: JVM 17
- Core Library Desugaring enabled
- Flutter’s resolved `compileSdk`
- Flutter’s resolved `targetSdk`
- Flutter’s resolved `minSdk`
- `com.example.binuwad_v1` namespace and application ID
- Debug signing in the release build type
- Gradle wrapper 9.3.1

Before external release, change the application ID to a unique production identifier and configure a release keystore. The current release configuration uses debug signing and is not appropriate for production distribution.

Android Studio or Gradle should have:

- Android SDK Platform 36 or the same platform resolved by the installed Flutter SDK
- Android SDK Build-Tools 36.0.0
- Android NDK when plugin/native dependencies require it
- Android SDK licenses accepted
- Internet access to Maven, Google, Pub, and Gradle repositories

The Android manifest currently declares a malformed text entry for `showWhenLocked` and `turnScreenOn` inside the activity element. Move these attributes to the activity opening tag before relying on lock-screen behavior.

## 6. Server Requirements

This project does not contain an application backend server or custom API server.

There is no required local server for the app itself because Firebase and the weather services are hosted managed services. However, a server or managed deployment is required for a production implementation if the project needs to provide:

- Verified push notifications
- Server-side alert routing
- Pairing abuse prevention
- Pairing code cleanup
- Alert retention cleanup
- Centralized Firebase security enforcement
- Scheduled jobs or Cloud Functions

The current implementation uses only the following communication model:

```text
Flutter client
  -> Firebase Authentication
  -> Cloud Firestore
  -> Open-Meteo HTTPS API
  -> OpenStreetMap Nominatim HTTPS API
```

### Firebase requirements

Use or provision a Firebase project with:

- Authentication enabled
- Anonymous sign-in enabled
- Cloud Firestore enabled
- A Firestore database location selected for the intended users
- Firebase app registrations matching Android application IDs
- `android/app/google-services.json` for the Android client
- `lib/firebase_options.dart` regenerated for all supported platforms
- Production Firestore security rules
- IAM access limited to authorized developers and deployment accounts

The Firebase project in the current configuration is `binuwad-ac209`. Firebase client configuration is present in:

- `firebase.json`
- `android/app/google-services.json`
- `lib/firebase_options.dart`

## 7. Database Requirements

The database is Cloud Firestore.

### Required collections and subcollections

```text
pairings/{sixDigitCode}
  monitorUid: string
  receiverUid: string | null
  paired: boolean
  createdAt: server timestamp
  expiresAt: server timestamp
  pairedAt: server timestamp | null

  alerts/{alertId}
    label: string
    confidence: number
    createdAt: server timestamp
```

### Database configuration

- Firestore native mode is required
- Anonymous Authentication must be enabled
- Composite indexes are not currently defined in the repository
- Security rules are not currently present
- Server-side expiry cleanup is not currently configured
- Alert retention/TTL policy is not currently configured

The app needs at least these Firestore operations:

- Read and transactionally update pairing documents
- Create pairing documents
- Delete pairing documents
- Create alert documents
- Listen to ordered alert snapshots
- Query the latest five alerts for the receiver UI

### Minimum database/retention policy

For a production deployment:

- Add rules restricting each user to authorized pairing documents
- Restrict alert reads and writes to paired monitor/receiver users
- Validate field types and confidence range
- Add pairing-code expiration enforcement and cleanup
- Limit alert creation rate
- Define a retention period for old alerts
- Add index/rules test coverage
- Add Firebase Emulator tests for authorization and malformed data

## 8. Network and Connectivity Requirements

| Operation | Minimum connection |
|---|---|
| Firebase pairing | HTTPS/TCP internet access |
| Alert delivery | Internet while sending; Firestore SDK can cache and queue writes |
| Weather retrieval | Internet access with 10-second timeout |
| Reverse geocoding | Internet access with 8-second timeout |
| Initial YOLO model download | Internet access |
| Receiver alerts | App must remain running and listener active with foreground/background restrictions considered |

Expected outbound destinations:

- Firebase/Google domains
- `api.open-meteo.com`
- `nominatim.openstreetmap.org`
- Gradle and package repositories during development

The app should not be considered reliably network-independent. The camera and shared rice timer can operate locally, but pairing, Firebase alerts, weather, geocoding, and initial model download require network access.

## 9. Storage Requirements

### Device storage

- Flutter app and native libraries
- Audio assets:
  - `assets/sounds/SO-sound.m4a`
  - `assets/sounds/scare.wav`
  - `assets/sounds/pulse.wav`
  - `assets/sounds/warble.wav`
- YOLO model resources/cache
- Firebase SDK cache
- Shared preferences
- Notification and application caches

The app does not currently persist:

- Rice timer end time
- Timer turn count
- Bird counts across restart
- Recent activity list
- Last successful weather data

The app does persist theme, language, scare-sound choice, pairing role, and pairing code using `shared_preferences`.

### Development storage

Recommended disk layout:

- Flutter SDK: at least 2 GB
- Android SDK and build-tools: at least 8 GB
- Android emulator images: 5–10 GB per system image
- Gradle cache and build output: at least 10 GB
- Physical-device test recordings/test media: at least 5 GB

## 10. Package and SDK Requirements

Declared application dependencies include:

- `cupertino_icons`
- `flutter_local_notifications`
- `timezone`
- `http`
- `ultralytics_yolo`
- `audioplayers`
- `geolocator`
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `shared_preferences`

Development dependency:

- `flutter_test`
- `flutter_lints`

Application package metadata:

- Package name: `binuwad_v1`
- App version: `1.0.0+1`
- Dart SDK constraint: `^3.13.7`

## 11. Build and Run Commands

Install dependencies:

```powershell
flutter pub get
```

Analyze source:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

Run on a connected Android device:

```powershell
flutter run
```

Build a debug APK:

```powershell
flutter build apk --debug
```

Build a release APK:

```powershell
flutter build apk --release
```

Before release, configure the production application ID, signing key, Firebase project registration, camera/location permissions, notification policy, and platform permissions.

## 12. Minimum Verification Matrix

Before approving a deployment, verify:

| Feature | Required test |
|---|---|
| Android startup | Firebase initializes and notifications initialize |
| Camera | Camera permission and YOLO model loading |
| Bird detection | Consecutive-frame behavior and scare sound |
| Pairing | Firebase anonymous auth and code transaction |
| Receiver alerts | Foreground listener and notification permission |
| Timer | Start, pause, resume, stop, and finish behavior |
| Weather | GPS, last-known position, and fallback coordinates |
| Network failure | Timeout and last-data behavior |
| Theme/language/sound | Shared-preference persistence |
| Android release | Valid signing, permissions, and exact alarms |

## 13. Deployment-Readiness Gaps

The following requirements are not fully configured and should be completed before external production use:

- Pin or document the exact Android minimum SDK and verify it with device testing
- Replace debug signing with a release keystore
- Replace the template Android application ID
- Add iOS camera/location permission declarations if iOS is supported
- Add Firestore security rules
- Enable and test Firebase Anonymous Authentication
- Configure pairing and alert retention cleanup
- Verify exact-alarm and full-screen notification behavior
- Replace or remove the zero-byte `assets/sounds/scare.wav`
- Add Firebase/Firestore emulator tests
