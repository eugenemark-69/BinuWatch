# BinuWatch - Gap Analysis and Improvement Plan

## Scope and evidence

This report reviews the Flutter source, platform configuration and repository
files present in this checkout. It is a codebase review, not a penetration
test, a legal opinion, or verification of the deployed Firebase project.
Issues about external Firebase settings, service availability, field
conditions and licensing need confirmation with the project owner or service
providers.

The following checks were run:

| Check | Result |
|---|---|
| `flutter analyze` | Failed: one compile-time error in the existing test (`MyApp` is undefined); one non-blocking lint in `weather_screen.dart`. |
| `flutter test` | Failed while compiling the same test because it calls `MyApp`, which is not the current app root (`BinuwadApp`). No tests ran. |
| Repository inspection | No project `LICENSE` file, Firebase rules/indexes file, or privacy policy was found in the repository. |

`flutter analyze` resolved dependencies and reported newer versions available
for some packages, but this is not evidence that a package upgrade is
necessary or safe. Review compatibility and changelogs before upgrading.

## Priority summary

| Priority | Focus | Why it matters |
|---|---|---|
| P0 - before external release | Firebase access controls, release identity/signing, licensing and privacy decisions | Protects user data and determines whether the app can be safely and lawfully distributed. |
| P1 - before relying on core behavior | Repair tests; validate Android/iOS permissions and notifications; isolate notification cancellation; improve pairing and alert reliability | Core camera, alerts and reminders need to work predictably on real devices. |
| P2 - product quality | Improve weather resilience/advice, localization, persistence and UX feedback | Reduces misleading guidance and makes the app more usable outside a happy-path demo. |
| P3 - maintenance | Remove template leftovers, document setup, establish release/CI checks | Makes future development and handoff repeatable. |

## P0 - resolve before external release

### 1. Add and verify Firebase security rules

**Evidence:** The client uses anonymous Firebase Authentication and
`pairings/{code}` plus `alerts` subcollections in `lib/pairing_service.dart`.
There is no `firestore.rules`, Firebase indexes file, or backend code in this
repository. Client-side checks are not authorization boundaries.

**Risk:** If deployed Firestore rules permit broad reads or writes, users
could enumerate pairing documents, join or alter pairings, read alerts, or
write forged alerts. A six-digit code is not sufficient access control on its
own.

**Recommended changes:**

- Add version-controlled Firestore rules that require authentication and
  validate the caller's role/UID for every read, create, update and delete.
- Validate allowed fields, types, confidence range, pairing transitions and
  server timestamps in rules.
- Restrict alert reads and writes to the paired monitor/receiver, and prevent
  a receiver from creating or changing pairing ownership.
- Apply server-side abuse controls for repeated code guesses and alert
  creation; a client cooldown can be bypassed.
- Add rules tests using the Firebase Emulator Suite, including unauthenticated,
  unrelated-user and malformed-data cases.
- Confirm production Firebase settings independently; their absence from this
  repo does not prove that the deployed project has no rules.

### 2. Choose the app's own source license and verify third-party obligations

**Evidence:** There is no top-level `LICENSE`/`COPYING`/`NOTICE`. The in-app
credits name Ultralytics YOLO as AGPL-3.0 and list public data sources, but
there is no recorded provenance/license for the bundled audio files.

**Recommended changes:**

- Decide whether BinuWatch source is proprietary or open source; add the
  corresponding license and required notices. Do not rely on third-party
  package licenses as the app's own license.
- Have the project owner verify obligations for the exact Ultralytics package,
  model/runtime, use and distribution arrangement. The in-app credit alone
  does not establish compliance.
- Record the source, permission and attribution requirements for each audio
  asset. Replace assets with unknown or incompatible rights.
- Verify attribution and usage requirements for Open-Meteo and
  OpenStreetMap/Nominatim, and keep credits consistent with actual use.

### 3. Complete production identity and release configuration

**Evidence:** `android/app/build.gradle.kts` uses `com.example.binuwad_v1`
and the release build uses debug signing. iOS metadata also remains template
or generated identity. Several app/web surfaces still call the project
`binuwad_v1`.

**Recommended changes:**

- Set final unique Android application ID and iOS bundle ID, app display
  names, icons and web metadata.
- Configure and verify production signing, key backup/ownership, version
  increments and a repeatable release build process.
- Make Firebase app registrations match final platform identifiers before
  shipping; do not assume changing local IDs will continue to match existing
  Firebase configuration.
- Remove debug signing from release builds and document who controls signing
  credentials.

### 4. Publish privacy and retention information

**Evidence:** Location coordinates are sent to Open-Meteo and Nominatim;
Firebase stores anonymous identity, pairing and alert data. The repository
contains no privacy-policy document or visible retention policy.

**Recommended changes:**

- Document what data is collected, where it is sent, why it is used, how long
  it remains, and how users can unpair or request deletion.
- Specify expiry/cleanup for unused pairing documents and alert subcollections;
  the app checks a pairing code's expiry when joining but no server cleanup is
  configured in this repository.
- Explain the location fallback and when coordinates leave the device.
- Review consent, account deletion, data-retention and store disclosure
  requirements for intended distribution regions.

## P1 - reliability and core functionality

### 5. Replace the broken starter test and establish meaningful coverage

**Evidence:** `test/widget_test.dart` still pumps `const MyApp()` and tests a
counter that is not part of this app. `flutter analyze` and `flutter test`
both fail at this reference; `flutter test` did not execute a feature test.

**Recommended changes:**

- Replace the counter test with tests for the actual `BinuwadApp` startup and
  navigation, or remove the obsolete test while building real coverage.
- Extract weather advice rules into a testable unit and cover threshold
  boundaries, missing/edge forecast data, and timezone handling.
- Test timer start/pause/resume/stop/finish and notification scheduling via
  injected/fake services or a clock.
- Test pairing creation/join/expiry and alert handling against Firestore
  emulator rules.
- Add widget tests for permissions/error/loading states without requiring
  live services or a physical camera.
- Keep `flutter analyze` and `flutter test` as required CI checks.

### 6. Fix and verify platform permission and notification setup

**Evidence:** Android declares camera, location and notification permissions
in `android/app/src/main/AndroidManifest.xml`. `ios/Runner/Info.plist` does
not declare camera or location usage descriptions. `NotificationService.init`
in `lib/notification_service.dart` initializes only
`AndroidInitializationSettings`, and notification permission is requested
only through the Android plugin implementation. Platform projects exist for
more targets than these integrations demonstrate.

**Recommended changes:**

- Add appropriate iOS camera/location usage descriptions and configure the
  plugin-specific iOS permission/notification initialization. Confirm
  equivalent macOS/web settings only if those platforms are intended targets.
- Verify scheduling, permission prompts, sound, vibration, lock-screen
  presentation and reboot behavior on each supported OS and OS version.
- Treat Android exact-alarm and full-screen behavior as device/OS policy
  dependent; expose a useful explanation or fallback if permission is denied.
- In the Android manifest, move the current
  `android:showWhenLocked="true"` and `android:turnScreenOn="true"` entries
  into the `<activity>` opening tag if those attributes are intended. They
  currently appear as text inside the activity element rather than as
  attributes, so they do not configure the activity.
- Declare a support matrix and remove unsupported platform targets from
  product claims until their camera, Firebase and notification paths are
  configured and tested. Linux Firebase initialization is explicitly
  unsupported in `lib/firebase_options.dart`.

### 7. Separate timer alarm cancellation from bird-alert notifications

**Evidence:** `NotificationService.scheduleTurnReminder`,
`stopAlarm` and `cancelAll` all call `_plugin.cancelAll()`. Bird notifications
are posted by `BirdAlertNotifier` using the same local-notifications plugin.

**Impact:** Starting, pausing, stopping or dismissing the rice-turn alarm can
cancel unrelated bird-alert notifications. This makes two features interfere.

**Recommended changes:** Use stable, distinct notification IDs and cancel
only the timer notification/alarm ID when changing timer state. Keep any
“dismiss all” action explicit and scoped to the intended feature.

### 8. Make receiver alert delivery state and failures visible

**Evidence:** `PairingService.startListening` silently returns if anonymous
sign-in fails and only debug-logs listener errors. Receiver notifications are
created from an active Firestore snapshot listener; no FCM/push service is
implemented. The receiver UI says to keep the app open or running.

**Recommended changes:**

- Show receiver connection/listener state and a recoverable error/retry path
  instead of leaving a paired screen that appears healthy while disconnected.
- Decide and document whether foreground/background-only receipt is an
  acceptable product requirement. If alerts must arrive when the app is
  terminated, implement and test a server-triggered push mechanism (such as
  FCM) rather than assuming a Firestore listener is equivalent.
- Define deduplication and recovery behavior after reconnect/restart. The
  listener intentionally skips pre-existing alerts at startup; clarify how
  that interacts with offline/queued alerts.
- Handle local notification permission denial in the receiver UX.

### 9. Reduce alert spam and clarify detection semantics

**Evidence:** `BirdScreen._maybeSendAlert` can send every two seconds while
the bird remains visible. Each received alert becomes a notification. The
screen also maintains an event/episode count separately from the alert
cooldown.

**Recommended changes:**

- Decide whether alerts should be once per confirmed detection episode,
  periodically while a bird remains visible, or based on a longer
  configurable cooldown. Implement the chosen policy explicitly.
- Report the local detection event separately from remote send state, so a
  transient network failure does not read as a failed detection.
- Test false-positive filtering and thresholds with representative outdoor
  footage, camera angles, lighting and target devices. Three consecutive
  frames is a temporal filter, not evidence of field accuracy.
- Provide a user-visible explanation when the model cannot download, camera
  permission is denied, or inference fails.

### 10. Fix unusable and fragile sound options

**Evidence:** `assets/sounds/scare.wav` is zero bytes, but it is the configured
Siren sound. `BirdScreen` ignores failure of the initial `setReleaseMode` and
does not validate asset length or playback readiness.

**Recommended changes:**

- Replace the empty file with a correctly licensed valid audio asset, or
  remove the Siren option and references to it.
- Test all sound options on target hardware and report a failed preview or
  playback clearly.
- Consider audio focus/volume behavior and ensure monitoring shutdown always
  stops playback when camera/model errors or route transitions occur.

## P2 - product quality and correctness

### 11. Improve weather time handling, resilience and advice quality

**Evidence:** `fetchWeather` parses Open-Meteo's local-time strings with
`DateTime.parse`, while the API response includes a location timezone. The
timezone name is displayed but not used to convert forecast timestamps.
`getPlace` accepts any last-known location without checking its age. The
advice thresholds in `adviceFor` are explicitly described in code as starting
rules.

**Recommended changes:**

- Parse forecast-local timestamps in the forecast's declared timezone (or
  request/use UTC consistently) and test when device and forecast timezones
  differ. Ensure the displayed sunset/hourly labels and daylight calculation
  use the same zone.
- Decide a maximum acceptable age for last-known location and show when the
  forecast is based on approximate/stale coordinates.
- Validate response shapes, nulls and hourly list lengths before indexing;
  surface actionable errors and keep last-good data.
- Review the rule thresholds with local agricultural expertise and real
  Biliran weather/drying observations. Display advice as an estimate and
  avoid implying forecast certainty.
- Add API caching/backoff and honor provider usage policies, especially for
  repeated reverse-geocode requests. Do not treat timeouts or failed
  geocoding as a successful location name.

### 12. Complete localization and accessibility

**Evidence:** The translation map supports English and Bisaya/Cebuano, but
weather and camera screens contain many hard-coded English strings, as do
pairing and alert states. The code itself notes the Bisaya text needs native
review.

**Recommended changes:**

- Move all user-facing strings, including errors, units/labels, pairing,
  camera and weather content, into the translation system.
- Have a fluent/native Bisaya/Cebuano reviewer validate translations and
  terminology used by local farmers.
- Check long translations, text scaling, screen readers, contrast and small
  screen layouts; add semantics to important camera/alert status changes.

### 13. Define what state should survive app restarts

**Evidence:** Only theme, language, sound selection and pairing role/code use
`shared_preferences`. Timer progress, activity history, bird counts and last
weather results are in-memory. A process restart resets them.

**Recommended changes:** Decide explicitly which state is expected to persist.
At minimum, consider persisting the timer's end time and interval so an alarm
and countdown remain consistent across process death, and state clearly if
activity counts reset. Avoid persisting information that has no user value.
Test device reboot, app force-stop, permission revocation and timezone changes.

### 14. Improve pairing lifecycle, retry and feedback

**Evidence:** Pairing uses a six-digit code, checks expiry when joining, and
does not show an explicit countdown. `unpair` catches any Firestore delete
error, then clears local state, so the remote pairing may remain active.
`createPairing` checks code uniqueness before a separate write rather than
creating atomically.

**Recommended changes:**

- Use an atomic create-if-absent mechanism or a transaction for code
  reservation, and add server-side throttling/expiration.
- Display the code expiry and offer a safe way to regenerate it.
- Report when remote unpair failed, and distinguish “forget on this phone”
  from “end for both phones” rather than implying both succeeded.
- Add explicit retry/connection state for operations and avoid silent state
  changes on network failures.
- Review whether six digits and the current no-rate-limit client flow meet the
  intended abuse resistance; enforce protections on trusted backend rules or
  services.

## P3 - maintenance, cleanup and project handoff

### 15. Remove template leftovers and clarify metadata

**Evidence:** The README, package description, web manifest and web page
description still say this is a new Flutter project. The Android label and
some bundle identifiers use template names. `app_info.dart` contains TODOs
for contact/developer details, though values are currently populated.

**Recommended changes:**

- Replace the starter README with concise setup, Firebase provisioning,
  supported platform, run/test/build and troubleshooting instructions.
- Update package/app/web metadata to a consistent BinuWatch identity.
- Resolve or remove stale TODO comments and verify the displayed contact and
  attribution information.
- Remove only confirmed obsolete generated or starter files; preserve Flutter
  platform scaffolding needed by supported builds.

### 16. Add a repeatable build and release checklist

**Recommended changes:**

- Add CI for formatting checks, analyzer, unit/widget tests, and at least the
  primary Android build.
- Add a release checklist for Firebase rules, permissions, model download,
  notification behavior, signing, attribution, privacy disclosures and
  backups.
- Record the exact Flutter/Dart/toolchain versions used for known-good builds
  and test on physical devices with poor/no network.
- Keep generated Firebase configuration out of onboarding examples and rotate
  any true credentials if they are ever accidentally committed. Firebase
  client identifiers are not server secrets, but must be protected by rules.

## Suggested order of work

1. Establish actual release targets and Firebase deployment ownership; add
   and test Firestore rules before exposing the app to real users.
2. Decide source/media licensing and privacy/retention requirements; replace
   the empty sound and make release IDs/signing production-ready.
3. Replace the broken test, fix platform permissions/notification setup, and
   eliminate the shared `cancelAll` behavior.
4. Test pairing, alerts, model inference, timer behavior and weather on
   representative physical devices; implement only the support guarantees
   the team can validate.
5. Improve weather/time correctness, localization and persistence based on
   field feedback.
6. Replace starter documentation and add CI/release checks.

This order separates release blockers from enhancements. The app already has
useful feature breadth, but the current repository evidence is not sufficient
to call its production security, cross-platform behavior, field accuracy or
distribution readiness verified.
