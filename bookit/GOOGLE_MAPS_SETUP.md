# Google Maps setup for BookIt

The embedded route map uses Google Maps SDK for Android/iOS and the Google Directions API through the BookIt backend. Do not put the Directions server key in the Flutter app.

## 1. Google Cloud
1. Enable billing for the Google Cloud project.
2. Enable **Maps SDK for Android**, **Maps SDK for iOS**, and **Directions API**.
3. Create a separate mobile key for the Android/iOS map SDKs and a server key for Directions.
4. Restrict each key to only the APIs and apps/IPs that need it.

## 2. Mobile map SDK key
Replace `YOUR_GOOGLE_MAPS_API_KEY` in:
- `bookit/android/app/src/main/AndroidManifest.xml`
- `bookit/ios/Runner/AppDelegate.swift`

Use a mobile-restricted key. Restrict Android by the BookIt application ID and SHA-1 certificate fingerprint; restrict iOS by the bundle identifier.

## 3. Directions server key
Set `GOOGLE_MAPS_SERVER_API_KEY` in the deployed BookIt backend environment (Render service environment variables). Use a server-restricted key and restrict it to the Directions API. Do not commit the real key to GitHub.

## 4. Build
From the `bookit` directory:

```bash
flutter pub get
flutter run -d linux
```

For Android/iOS, run on the target device after configuring its SDK key. Linux desktop does not render the native Google Maps Flutter view, so test the embedded map on Android or iOS. The route timeline remains available on other platforms.
