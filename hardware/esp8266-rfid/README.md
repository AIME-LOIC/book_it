# BookIt RFID reader — NodeMCU ESP8266 + RC522

## Wiring

| RC522 | NodeMCU ESP8266 |
|---|---|
| SDA / SS | D2 (GPIO4) |
| SCK | D5 (GPIO14) |
| MOSI | D7 (GPIO13) |
| MISO | D6 (GPIO12) |
| RST | D1 (GPIO5) |
| 3.3V | 3V3 |
| GND | GND |
| IRQ | Not connected |

Power the RC522 from 3.3V only. Never connect it to 5V.

## Firmware setup

1. Install Arduino ESP8266 board support.
2. Install MFRC522 by GithubCommunity and ArduinoJson 7.x.
3. Copy secrets.example.h to secrets.h in this folder.
4. Set Wi-Fi SSID/password and the same reader ID/token configured on the server.
5. Select NodeMCU 1.0 (ESP-12E Module), upload bookit_rfid.ino, and open Serial Monitor at 115200 baud.

The real secrets.h is ignored by Git. Never commit it.

## Server environment variables

Set these in the deployed BookIt server environment:

- RFID_DEVICE_ID=bookit-bus-reader-001
- RFID_DEVICE_TOKEN=<new random secret>
- Optional: RFID_DEFAULT_DEVICE_ID=bookit-bus-reader-001

Use the same ID and token in local secrets.h. Rotate any token exposed in chat, screenshots, source control, or logs. Generate a new token locally with: openssl rand -hex 32

## Passenger and admin flow

Passenger: Profile → Settings → RFID cards → Add my card. The API opens a two-minute session. Tap the card on the reader; the app polls for completion.

Admin: open RFID cards, search the passenger, and use the card icon beside their account. The server checks the signed-in account's admin role.

## API

- GET /rw/v1/bk/rfid-cards — list the current user's cards.
- POST /rw/v1/bk/rfid-cards/registration-sessions — start own registration.
- GET /rw/v1/bk/rfid-cards/registration-sessions/:id — poll a session.
- DELETE /rw/v1/bk/rfid-cards/:id — unlink own card.
- GET /rw/v1/bk/rfid-cards/admin/users?search= — admin passenger search.
- POST /rw/v1/bk/rfid-cards/admin/registration-sessions — admin starts a session for { userId }.
- POST /rw/v1/bk/hardware/rfid/scan — device-authenticated reader scan.

## Important limitation

This implementation links a UID to an account. It does NOT approve boarding or validate payment, ticket status, route, or trip. Without a pending registration session, the reader rejects the scan. Never treat an RFID UID as proof of payment. Boarding validation is a separate backend feature still required.

Firmware TLS currently uses prototype mode (setInsecure()). Configure BearSSL certificate trust for the BookIt API host before production hardware deployment.
