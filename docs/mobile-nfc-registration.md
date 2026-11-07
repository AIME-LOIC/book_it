# BookIt phone NFC card registration

BookIt can register a supported contactless card with an Android phone that has NFC hardware. This is an alternative to the external NodeMCU + RC522 reader; it does not remove or disable the bus-reader flow.

## Passenger flow

1. Sign in to BookIt.
2. Open Profile → Settings → RFID cards.
3. Tap **Scan with this phone**.
4. If Android reports NFC is disabled, enable NFC in system Settings and return to BookIt.
5. Hold the card against the NFC antenna area on the back of the phone.
6. BookIt reads the tag identifier and sends it to the authenticated phone-registration API.
7. The API links the UID to the signed-in account, or rejects it if another passenger already owns it.

The existing **Use a BookIt reader instead** option still starts the two-minute registration session for the external ESP8266/RC522 reader. Admin passenger registration continues to use that reader flow.

## Device and card compatibility

- The phone must be an Android device with NFC hardware and NFC enabled.
- The implementation polls ISO 14443 tags. It is intended for common 13.56 MHz NFC-A / MIFARE cards and key fobs.
- A phone without NFC, an NFC-disabled phone, or a card using an unsupported technology cannot complete this flow.
- Some phones and card types expose different identifier lengths. The API accepts normalized UIDs from 4 to 20 bytes.
- This flow reads the tag identifier only. It does not read protected card sectors, write data to the card, or clone the card.
- iOS and desktop builds do not offer this phone-registration action in the current implementation.

## API contract

\`POST /rw/v1/bk/rfid-cards/phone-registration\`

Requires the normal BookIt bearer token.

Request:

\`\`\`json
{
  "cardUid": "04A10BFF"
}
\`\`\`

The API normalizes hexadecimal UID text, validates its length, and links the card to the authenticated account. A UID already linked to a different account returns HTTP 409. An already-linked card for the same account is an idempotent success.

## Build an Android APK locally

From the repository root:

\`\`\`bash
cd bookit
flutter pub get
flutter test test/services/nfc_card_reader_test.dart
flutter build apk --debug
\`\`\`

The debug APK is created at:

\`build/app/outputs/flutter-apk/app-debug.apk\`

Install it on an NFC-equipped Android phone, sign in, and test with a known compatible card.

## CI artifact

The GitHub Actions workflow \`.github/workflows/android-apk.yml\` resolves dependencies, runs the NFC UID tests, builds the debug APK, and uploads \`bookit-android-debug-apk\` as a 14-day workflow artifact.

## Security and boarding limitations

A card UID is an identifier, not a cryptographic proof. Some RFID/NFC cards can be cloned or emulated. The registration endpoint requires an authenticated BookIt account and prevents a UID from being linked to two active accounts, but this alone does not make the UID suitable as a secure payment credential.

This feature only links a card to an account. It does **not** approve boarding or validate payment, ticket status, route, or trip. Keep boarding authorization in a separate server-side validation flow. Never approve a passenger based only on a UID reported by a phone or reader.
