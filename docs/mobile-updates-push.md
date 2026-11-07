# BookIt mobile updates, legal pages and push notifications

## What the mobile app does

- The app checks the latest non-draft, non-prerelease GitHub release at startup. If its version is newer than the installed app, it offers **Update now** or **Later**. A skipped version is not prompted again until a newer release is published.
- Android users are directed to the APK asset when a release contains one; Linux users are directed to the Linux archive. If the expected asset is missing, the release page is opened instead. iOS users follow the configured App Store/TestFlight distribution path; a GitHub release page is only a fallback.
- The Terms & Privacy screen displays the current BookIt policy hosted at `https://bookit.1percent.rw/policy.html`.
- Mobile push registration is tied to the authenticated BookIt account. Existing in-app notifications remain available if FCM is temporarily unavailable.

## Firebase client setup (Android and iOS)

Create or use a Firebase project and register the Android app with package ID `rw.onepercent.bookit` and the iOS app with the actual iOS bundle ID.

The Flutter client reads Firebase's public client configuration from Dart defines; do not put a service-account private key in the Flutter app. For Android, values can be read from the local `bookit/android/app/google-services.json`:

```bash
jq -r '.client[0].api_key[0].current_key' bookit/android/app/google-services.json
jq -r '.client[0].client_info.mobilesdk_app_id' bookit/android/app/google-services.json
jq -r '.project_info.project_number' bookit/android/app/google-services.json
jq -r '.project_info.project_id' bookit/android/app/google-services.json
```

Build/run Android with:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=YOUR_API_KEY \
  --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_ANDROID_APP_ID \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_PROJECT_NUMBER \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
```

For iOS, also pass `FIREBASE_IOS_APP_ID` and `FIREBASE_IOS_BUNDLE_ID`. Enable the Push Notifications capability and Background Modes / Remote notifications in the iOS target, and configure an APNs authentication key in Firebase. The Firebase project must have Cloud Messaging enabled.

## GitHub Actions release signing and Firebase client variables

To attach an installable Android update APK to each tagged GitHub Release, configure these repository **Actions secrets**:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded release keystore file
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Also configure these repository **Actions variables** for the Android release build:

- `FIREBASE_API_KEY`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID` (Firebase project number)
- `FIREBASE_PROJECT_ID`

The Android APK release step is deliberately skipped when the signing secrets are missing. A debug-signed APK must not be shipped as an update because it cannot reliably update an already installed production app. Without the signed APK asset, the in-app update button opens the GitHub release page instead.

## Firebase Admin server setup

1. In Firebase Console, create a **service account** for the server-side Firebase Admin integration. Grant only the Firebase Cloud Messaging permissions needed to send messages.
2. Store the complete service-account JSON as the server environment variable `FIREBASE_SERVICE_ACCOUNT_JSON` (for example, in Vercel Project Settings → Environment Variables). Do not commit this JSON, paste it into Flutter, or expose it to clients.
3. Run the PostgreSQL migration from the repository root in the production environment:

```bash
npm run db:migrate
```

This creates `device_push_tokens`. Local MySQL development also includes this model in `src/database/sync.js`.

## End-to-end verification

1. Deploy the backend with `FIREBASE_SERVICE_ACCOUNT_JSON` configured and the migration applied.
2. Build the Android/iOS app with the correct Firebase Dart defines.
3. Sign in on a physical device and allow notifications. The app registers its FCM token against the authenticated account.
4. Create a normal BookIt notification for that account. Confirm it appears in the app's notification list and as a system notification while the app is foreground/background.
5. Tap the system notification and confirm the app opens and refreshes the notification/ticket details.
6. Publish a newer GitHub Release with a higher version tag and platform installer asset; relaunch the app and confirm the update prompt appears.

## Important release notes

- The update check uses GitHub Releases for `AIME-LOIC/book_it`. A release without an APK or Linux archive still produces a prompt, but the button opens the release page.
- Android sideloaded APK updates must be signed with the same release key as the installed APK. Production release builds must use the configured release keystore.
- iOS updates should be distributed through the App Store/TestFlight rather than installing an IPA directly from a browser.
- Linux desktop does not support Firebase Cloud Messaging in this mobile integration; it continues to use the existing in-app notification polling.
