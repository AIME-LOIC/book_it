/*
 * BookIt RFID bus boarding prototype
 * Board: NodeMCU ESP8266
 * Reader: MFRC522 (SPI, 3.3V)
 *
 * WIRING:
 * MFRC522 SDA/SS -> D2 (GPIO4)
 * MFRC522 SCK    -> D5 (GPIO14)
 * MFRC522 MOSI   -> D7 (GPIO13)
 * MFRC522 MISO   -> D6 (GPIO12)
 * MFRC522 RST    -> D1 (GPIO5)
 * MFRC522 3.3V   -> 3V3
 * MFRC522 GND    -> GND
 * MFRC522 IRQ    -> not connected
 *
 * Install Arduino libraries:
 * - MFRC522 by GithubCommunity
 * - ArduinoJson (7.x)
 *
 * Configure WIFI_SSID, WIFI_PASSWORD, DEVICE_ID, DEVICE_TOKEN and API_URL.
 *
 * IMPORTANT:
 * - This is a prototype client. The API endpoint must be implemented on the
 *   BookIt server before scans can be approved.
 * - Never treat an RFID UID as proof of payment. The server must validate
 *   device authorization, card assignment, active ticket and trip.
 * - TLS certificate verification is intentionally marked as prototype-only
 *   below. Install the BookIt server CA certificate before deployment.
 * - If the API is unreachable, this firmware FAILS CLOSED (no approval).
 */

#include <ESP8266WiFi.h>
#include <WiFiClientSecureBearSSL.h>
#include <ESP8266HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

static const uint8_t RFID_SS_PIN = D2;
static const uint8_t RFID_RST_PIN = D1;

static const char WIFI_SSID[] = "YOUR_WIFI_NAME";
static const char WIFI_PASSWORD[] = "YOUR_WIFI_PASSWORD";
static const char DEVICE_ID[] = "bookit-bus-reader-001";
static const char DEVICE_TOKEN[] = "REPLACE_WITH_DEVICE_TOKEN";
static const char API_URL[] =
    "https://bookit.1percent.rw/rw/v1/bk/hardware/rfid/scan";

static const unsigned long WIFI_RETRY_INTERVAL_MS = 10000;
static const unsigned long SAME_CARD_COOLDOWN_MS = 2500;

MFRC522 reader(RFID_SS_PIN, RFID_RST_PIN);
unsigned long lastWifiAttempt = 0;
unsigned long lastScanAt = 0;
String lastUid;

String uidToHex(const MFRC522::Uid &uid) {
  String value;
  value.reserve(uid.size * 2);
  for (byte i = 0; i < uid.size; i++) {
    if (uid.uidByte[i] < 0x10) value += '0';
    value += String(uid.uidByte[i], HEX);
  }
  value.toUpperCase();
  return value;
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  const unsigned long now = millis();
  if (now - lastWifiAttempt < WIFI_RETRY_INTERVAL_MS) return;
  lastWifiAttempt = now;

  Serial.printf("\n[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  const unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - started < 12000) {
    delay(300);
    Serial.print('.');
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected. IP: %s\n",
                  WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n[WiFi] Not connected; scans will not be approved.");
  }
}

bool submitScan(const String &uid) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[API] Offline. Scan NOT approved.");
    return false;
  }

  // Prototype-only TLS setting. Replace with CA certificate validation
  // (BearSSL::X509List + client.setTrustAnchors(...)) before deployment.
  BearSSL::WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.setTimeout(8000);
  if (!http.begin(client, API_URL)) {
    Serial.println("[API] Could not initialize HTTPS request.");
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Id", DEVICE_ID);
  http.addHeader("X-Device-Token", DEVICE_TOKEN);

  JsonDocument request;
  request["deviceId"] = DEVICE_ID;
  request["uid"] = uid;
  request["source"] = "rfid";
  String body;
  serializeJson(request, body);

  Serial.printf("[API] Sending card UID %s\n", uid.c_str());
  const int status = http.POST(body);
  const String response = status > 0 ? http.getString() : "";
  http.end();

  if (status < 200 || status >= 300) {
    Serial.printf("[API] HTTP %d. Scan NOT approved. %s\n",
                  status, response.c_str());
    return false;
  }

  JsonDocument result;
  const DeserializationError error = deserializeJson(result, response);
  if (error) {
    Serial.println("[API] Invalid JSON response. Scan NOT approved.");
    return false;
  }

  const bool approved = result["approved"] | false;
  const char *message = result["message"] | "No server message";
  Serial.printf("[%s] %s\n", approved ? "APPROVED" : "REJECTED", message);
  return approved;
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\nBookIt RFID reader starting...");

  SPI.begin(); // ESP8266 hardware SPI: D5=SCK, D6=MISO, D7=MOSI
  reader.PCD_Init();
  delay(50);
  reader.PCD_DumpVersionToSerial();

  connectWiFi();
  Serial.println("[RFID] Ready. Present a card.");
}

void loop() {
  connectWiFi();

  if (!reader.PICC_IsNewCardPresent()) {
    delay(30);
    return;
  }
  if (!reader.PICC_ReadCardSerial()) {
    delay(30);
    return;
  }

  const String uid = uidToHex(reader.uid);
  const unsigned long now = millis();

  if (uid == lastUid && now - lastScanAt < SAME_CARD_COOLDOWN_MS) {
    Serial.printf("[RFID] Duplicate tap ignored: %s\n", uid.c_str());
  } else {
    lastUid = uid;
    lastScanAt = now;
    Serial.printf("[RFID] Card detected: %s\n", uid.c_str());
    submitScan(uid);
  }

  reader.PICC_HaltA();
  reader.PCD_StopCrypto1();
  delay(250);
}
