# BookIt (Rwanda bus booking — mobile app)

BookIt is the Flutter mobile client for the BookIt Rwanda bus-booking platform: passengers can browse routes, search buses, book seats, generate QR/paper tickets, track buses on a live map, and manage their trips. Drivers get a dedicated sign-in and dashboard for managing their assigned buses and departures.

The same Flutter project builds for Android and iOS.

## Requirements

- Flutter SDK (stable channel)
- For Android builds: Android SDK / Android Studio
- For iOS builds: Xcode (macOS only)

## Run the app

```bash
flutter pub get

# Point the app at the BookIt API by passing the base URL explicitly:
flutter run --dart-define=API_BASE_URL=https://bookit.1percent.rw/rw/v1/bk

# Or keep the API base URL in a git-ignored env file:
cp config/bookit_keys.example.env config/bookit_keys.env
flutter run --dart-define-from-file=config/bookit_keys.env
```

`API_BASE_URL` is the only variable the app reads (see `lib/config/api_config.dart`); without it the app falls back to the deployed BookIt API default.

## Release builds

Android release signing reads `bookit/android/key.properties` (git-ignored, never commit it). Create the file manually on the machine that signs releases:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

If `key.properties` is missing or incomplete, release builds automatically fall back to debug signing so `flutter run --release` keeps working locally — do not ship such a build to production.

```bash
cd bookit

# Android
flutter build apk --release
flutter build appbundle --release

# iOS (requires an Xcode signing identity for rw.onepercent.bookit)
flutter build ios --release
```

## Maps, geocoding, and routing

The app does **not** require any Google Maps API key. See [MAP_SETUP.md](MAP_SETUP.md) for details:

- Map tiles: OpenStreetMap via `flutter_map` (attribution must stay visible)
- Place lookup: Nominatim public search endpoint
- Driving route: OSRM public demo endpoint

These are shared community services with fair-use policies — do not bulk-prefetch tiles, and move to a production-grade provider before scaling to many passengers.

## Tests

```bash
flutter pub get
flutter analyze   # static analysis
flutter test      # widget tests (splash, login form, validation)
```
