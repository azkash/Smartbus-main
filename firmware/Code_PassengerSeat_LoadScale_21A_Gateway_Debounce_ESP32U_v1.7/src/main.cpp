#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>
#include <esp_mac.h>
#include <Preferences.h>        // NVS storage for the seat id
// #include "soc/rtc.h"          // replaced: low-level RTC API gone in core 3.x
#include "FastLED.h"
#include "seat_pressure_logic.h"

// ID Kursi (Seat ID) — identifies this seat in the JSON sent to the master.
// An unprovisioned node reports "RandomID" plus a MAC-derived UID. The first
// call opens the assignment popup on the head unit; the selected ID is saved
// to this node's NVS. Serial `setid=B15` remains available as a fallback.
char seatId[32] = {0};
char nodeUid[13] = {0};
bool seatIdAssigned = false;

static void saveSeatId(const char *id);

#define LOAD_SENSOR_PIN 34  // GPIO34 / ADC1_CH6; input-only, external FSR divider required
#define BUTTON_PIN 27       // button to GND; GPIO27 supports INPUT_PULLUP
#define LED_PIN    25       // WS2812B data; common GND and a level shifter are recommended
#define NUM_LEDS   10

CRGB leds[NUM_LEDS];

Preferences prefs;   // NVS storage for the seat id

// Router-centric transport. All seats associate with the real router; one UDP
// socket on the master receives the entire fleet without persistent TCP slots.
static const char* ROUTER_SSID = "iot_bus";
static const char* ROUTER_PASS = "iot_BUS@5758";
static constexpr uint16_t MASTER_UDP_PORT = 5758;
static constexpr uint16_t SEAT_UDP_PORT = 5759;
static constexpr unsigned long DISCOVERY_INTERVAL_MS = 2000;
static constexpr unsigned long MASTER_ACK_TIMEOUT_MS = 12000;
static constexpr unsigned long CALL_RETRY_FAST_MS = 400;
static constexpr unsigned long CALL_RETRY_SLOW_MS = 2000;
static WiFiUDP smartbusUdp;
static IPAddress masterIp;
static uint32_t udpSession = 0;
static uint32_t udpSequence = 0;
static unsigned long lastMasterAckMs = 0;
static unsigned long lastDiscoveryMs = 0;
static bool pendingCall = false;
static uint32_t pendingCallSeq = 0;
static bool pendingCallOccupied = false;
static uint16_t pendingCallRetries = 0;
static unsigned long pendingCallSentMs = 0;

const unsigned long SAMPLING_INTERVAL_MS = 200;
const unsigned long HEARTBEAT_MS         = 2000;  // lightweight UDP heartbeat for offline detection

volatile bool masterConnected = false;  // true while UDP ACKs prove master is alive
volatile uint16_t pressureReading = 0;
volatile bool seatOccupied     = false;
volatile bool occupancyChanged = false;  // set by sensorTask when occupancy flips
SemaphoreHandle_t dataMutex;

// Debounce state machine. A press must remain LOW for this long and, after it
// fires, the input must return HIGH stably before another call is accepted.
// This prevents both contact bounce and a noisy/held input from spamming calls.
constexpr unsigned long BUTTON_DEBOUNCE_MS = 100;
constexpr unsigned long BUTTON_LOCKOUT_MS = 10000;
bool buttonRawState = HIGH;
bool buttonStableState = HIGH;
bool buttonArmed = true;
unsigned long buttonRawChangedMs = 0;
unsigned long lastButtonCallMs = 0;
bool buttonLockoutActive = false;

void sensorTask(void *pvParameters) {
  bool lastOccupied = false;
  for (;;) {
    // Average several ADC samples to reduce vibration and electrical noise.
    uint32_t total = 0;
    constexpr uint8_t sampleCount = 8;
    for (uint8_t i = 0; i < sampleCount; i++) {
      total += analogRead(LOAD_SENSOR_PIN);
      delay(2);
    }
    uint16_t pressure = total / sampleCount;
    bool occupied = updateSeatOccupied(lastOccupied, pressure);

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    pressureReading = pressure;
    seatOccupied = occupied;
    if (occupied != lastOccupied) { occupancyChanged = true; lastOccupied = occupied; }
    xSemaphoreGive(dataMutex);

    // Report the LOGICAL button state, not the raw pin. With INPUT_PULLUP an
    // idle button floats HIGH, so printing the pin directly showed "Button: 1"
    // when nothing was pressed. This matches the sensorState we send to the
    // master: 0 = released (default), 1 = pressed.
    Serial.printf("ID: %s  Pressure ADC: %u  Occupied: %s  Button: %d\n",
                  seatId, (unsigned)pressure, occupied ? "YES" : "NO",
                  digitalRead(BUTTON_PIN) == LOW ? 1 : 0);

    vTaskDelay(pdMS_TO_TICKS(SAMPLING_INTERVAL_MS));
  }
}

static bool sendUdpJson(const IPAddress& target, uint16_t port, const char* json) {
  if (target == IPAddress() || WiFi.status() != WL_CONNECTED) return false;
  if (!smartbusUdp.beginPacket(target, port)) return false;
  smartbusUdp.write(reinterpret_cast<const uint8_t*>(json), strlen(json));
  return smartbusUdp.endPacket() == 1;
}

static uint32_t nextUdpSequence() {
  ++udpSequence;
  if (udpSequence == 0) ++udpSequence;
  return udpSequence;
}

static bool sendSeatPacket(uint32_t seq, int sensorState, bool occupied) {
  if (masterIp == IPAddress()) return false;
  char buf[320];
  snprintf(buf, sizeof(buf),
           "{\"type\":\"seat\",\"id\":\"%s\",\"uid\":\"%s\","
           "\"unassigned\":%s,\"session\":%lu,\"seq\":%lu,"
           "\"sensorState\":%d,\"seatOccupied\":%s,\"uptime\":%lu,\"rssi\":%d}",
           seatId, nodeUid, seatIdAssigned ? "false" : "true",
           (unsigned long)udpSession, (unsigned long)seq,
           sensorState, occupied ? "true" : "false",
           millis() / 1000UL, (int)WiFi.RSSI());
  const bool sent = sendUdpJson(masterIp, MASTER_UDP_PORT, buf);
  if (sensorState || !sent) {
    Serial.printf("[UDP] %s seq=%lu to %s%s\n",
                  sensorState ? "CALL" : "send",
                  (unsigned long)seq, masterIp.toString().c_str(),
                  sent ? "" : " FAILED");
  }
  return sent;
}

// A call is retained and retransmitted with the SAME sequence until ACK. The
// master deduplicates it, so a lost ACK cannot replay the audio announcement.
static void sendSeatEvent(int sensorState, bool occupied) {
  // Do not let a newer heartbeat sequence overtake an unacknowledged CALL.
  // Otherwise the master could correctly reject the later CALL retry as old.
  if (!sensorState && pendingCall) return;
  const uint32_t seq = nextUdpSequence();
  if (sensorState) {
    pendingCall = true;
    pendingCallSeq = seq;
    pendingCallOccupied = occupied;
    pendingCallRetries = 0;
    pendingCallSentMs = millis();
  }
  sendSeatPacket(seq, sensorState, occupied);
}

// Health report → master. Lets a seat that drops out in the field be diagnosed
// from the master's log alone, with no USB cable and no physical access:
//   reset  — why it last booted (11 = BROWNOUT means the 5V supply sagged)
//   heap   — free bytes; a steady decline over hours indicates a leak
//   rssi   — link margin; below about -75 dBm drops become likely
//   uptime — seconds since boot, so silent reboot loops are obvious
static void sendDiag() {
  if (masterIp == IPAddress()) return;
  char buf[288];
  // "ap" records the router actually joined for remote diagnostics.
  snprintf(buf, sizeof(buf),
           "{\"type\":\"diag\",\"id\":\"%s\",\"uid\":\"%s\","
           "\"unassigned\":%s,\"uptime\":%lu,\"heap\":%u,\"rssi\":%d,"
           "\"reset\":%d,\"ap\":\"%s\",\"pressure\":%u}",
           seatId, nodeUid, seatIdAssigned ? "false" : "true",
           millis() / 1000, (unsigned)ESP.getFreeHeap(),
           (int)WiFi.RSSI(), (int)esp_reset_reason(),
           WiFi.SSID().c_str(), (unsigned)pressureReading);
  sendUdpJson(masterIp, MASTER_UDP_PORT, buf);
  Serial.printf("[Diag] %s\n", buf);
}

// ─── Seat ID persistence (NVS) ────────────────────────────────────────
static void saveSeatId(const char *id) {
  prefs.begin("seat", false);
  prefs.putString("id", id);
  prefs.end();
}

static void clearSeatId() {
  prefs.begin("seat", false);
  prefs.remove("id");
  prefs.end();
}

static void loadSeatId() {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  snprintf(nodeUid, sizeof(nodeUid), "%02X%02X%02X%02X%02X%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

  prefs.begin("seat", true);
  String stored = prefs.getString("id", "");
  prefs.end();
  if (stored.length() > 0 && !stored.equalsIgnoreCase("RandomID")) {
    stored.toCharArray(seatId, sizeof(seatId));
    seatIdAssigned = true;
  } else {
    strlcpy(seatId, "RandomID", sizeof(seatId));
    seatIdAssigned = false;
  }
  Serial.printf("[Seat] ID = %s  UID = %s  assigned=%s\n",
                seatId, nodeUid, seatIdAssigned ? "yes" : "NO");
}

// Line-based, one command per line, case-insensitive. Accepts both
// "setid=1A" and "setid 1A".
static void handleSerial() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (!line.length()) return;

  String cmd = line, arg;
  int sp = line.indexOf(' ');
  if (sp > 0) { cmd = line.substring(0, sp); arg = line.substring(sp + 1); arg.trim(); }
  int eq = cmd.indexOf('=');
  if (eq > 0) { arg = cmd.substring(eq + 1); cmd = cmd.substring(0, eq); arg.trim(); }
  cmd.toLowerCase();

  if (cmd == "help" || cmd == "?") {
    Serial.println(F(
      "\n--- SEAT commands ---\n"
      "  help                  this list\n"
      "  status                id, WiFi, UDP, sensor, heap\n"
      "  setid <name>          set seat id, e.g. setid 3A (reboots)\n"
      "  clearid               return to RandomID pairing mode (reboots)\n"
      "  diag                  send a health report to the master now\n"
      "  id?                   short identity line\n"
      "  restart               reboot the seat\n"));

  } else if (cmd == "status") {
    uint16_t pressure; bool occ;
    xSemaphoreTake(dataMutex, portMAX_DELAY);
    pressure = pressureReading; occ = seatOccupied;
    xSemaphoreGive(dataMutex);
    Serial.printf("id       : %s\n", seatId);
    Serial.println("transport: router WiFi + UDP");
    Serial.printf("uptime   : %lu s   heap %u\n", millis() / 1000, (unsigned)ESP.getFreeHeap());
    if (WiFi.status() == WL_CONNECTED)
      Serial.printf("wifi     : %s  IP %s  RSSI %d dBm\n", WiFi.SSID().c_str(),
                    WiFi.localIP().toString().c_str(), (int)WiFi.RSSI());
    else
      Serial.println("wifi     : down");
    Serial.printf("udp link : %s  master %s:%u  session %lu  seq %lu\n",
                  masterConnected ? "up" : "DOWN",
                  masterIp == IPAddress() ? "undiscovered" : masterIp.toString().c_str(),
                  MASTER_UDP_PORT, (unsigned long)udpSession,
                  (unsigned long)udpSequence);
    Serial.printf("call ACK : %s  retries %u\n",
                  pendingCall ? "PENDING" : "clear", pendingCallRetries);
    Serial.printf("sensor   : GPIO%d  pressure ADC %u  occupied %s\n",
                  LOAD_SENSOR_PIN, (unsigned)pressure, occ ? "YES" : "no");
    Serial.printf("button   : %d\n", digitalRead(BUTTON_PIN) == LOW ? 1 : 0);

  } else if (cmd == "setid") {
    if (arg.equalsIgnoreCase("RandomID")) {
      clearSeatId();
      Serial.println("id cleared — restarting in RandomID pairing mode...");
      delay(200);
      ESP.restart();
    } else if (arg.length() > 0 && arg.length() < 32) {
      saveSeatId(arg.c_str());
      Serial.printf("id saved: %s — restarting...\n", arg.c_str());
      delay(200);
      ESP.restart();
    } else {
      Serial.println("usage: setid <name>   (1-31 chars)");
    }

  } else if (cmd == "clearid") {
    clearSeatId();
    Serial.println("id cleared — restarting in RandomID pairing mode...");
    delay(200);
    ESP.restart();

  } else if (cmd == "diag") {
    sendDiag();

  } else if (cmd == "id?" || cmd == "id") {
    Serial.printf("id = %s  transport = UDP  master = %s\n", seatId,
                  masterIp == IPAddress() ? "undiscovered" : masterIp.toString().c_str());

  } else if (cmd == "restart") {
    Serial.println("restarting...");
    delay(200);
    ESP.restart();

  } else {
    Serial.printf("unknown command '%s' — type 'help'\n", cmd.c_str());
  }
}

// Diagnostic only: expose the ESP-IDF reason code when association fails.
// This lets us distinguish a bad password/authentication failure from an AP
// timeout or radio-state problem before changing connection behavior.
static void onWiFiDisconnected(WiFiEvent_t, WiFiEventInfo_t info) {
  Serial.printf("[WiFi] disconnect reason=%u\n",
                (unsigned)info.wifi_sta_disconnected.reason);
}

static IPAddress subnetBroadcastAddress() {
  IPAddress result;
  const IPAddress local = WiFi.localIP();
  const IPAddress mask = WiFi.subnetMask();
  for (uint8_t i = 0; i < 4; ++i) result[i] = local[i] | (uint8_t)~mask[i];
  return result;
}

static void sendMasterDiscovery() {
  if (WiFi.status() != WL_CONNECTED) return;
  char request[128];
  snprintf(request, sizeof(request),
           "{\"type\":\"discover\",\"role\":\"seat\",\"uid\":\"%s\"}",
           nodeUid);
  const IPAddress broadcast = subnetBroadcastAddress();
  if (sendUdpJson(broadcast, MASTER_UDP_PORT, request)) {
    Serial.printf("[UDP] discovering master via %s:%u\n",
                  broadcast.toString().c_str(), MASTER_UDP_PORT);
  }
}

static void applySeatIdCommand(JsonDocument& doc) {
  const char* targetUid = doc["uid"] | "";
  String requestedId = doc["id"] | "";
  requestedId.trim();
  bool valid = strcmp(targetUid, nodeUid) == 0 && !seatIdAssigned &&
               requestedId.length() > 0 && requestedId.length() < sizeof(seatId) &&
               !requestedId.equalsIgnoreCase("RandomID");
  for (size_t i = 0; valid && i < requestedId.length(); ++i) {
    const char c = requestedId[i];
    valid = isAlphaNumeric(c) || c == '-' || c == '_';
  }
  if (!valid) return;

  saveSeatId(requestedId.c_str());
  requestedId.toCharArray(seatId, sizeof(seatId));
  seatIdAssigned = true;
  char confirmation[160];
  snprintf(confirmation, sizeof(confirmation),
           "{\"type\":\"seatIdSaved\",\"event\":\"seatIdSaved\","
           "\"uid\":\"%s\",\"id\":\"%s\"}", nodeUid, seatId);
  sendUdpJson(masterIp, MASTER_UDP_PORT, confirmation);
  Serial.printf("[Seat] ID saved from Head Unit via UDP: %s\n", seatId);

  bool occupied;
  xSemaphoreTake(dataMutex, portMAX_DELAY);
  occupied = seatOccupied;
  xSemaphoreGive(dataMutex);
  sendSeatEvent(0, occupied);
}

static void handleUdpTransport() {
  int packetSize;
  while ((packetSize = smartbusUdp.parsePacket()) > 0) {
    const IPAddress remote = smartbusUdp.remoteIP();
    char payload[384];
    const int length = smartbusUdp.read(
      reinterpret_cast<uint8_t*>(payload), sizeof(payload) - 1);
    if (length <= 0) continue;
    payload[length] = '\0';

    StaticJsonDocument<384> doc;
    if (deserializeJson(doc, payload)) continue;
    const char* type = doc["type"] | "";

    if (strcmp(type, "master") == 0) {
      const bool changed = masterIp != remote;
      masterIp = remote;
      lastMasterAckMs = millis();
      masterConnected = true;
      if (changed) {
        Serial.printf("[UDP] master discovered at %s:%u\n",
                      remote.toString().c_str(), MASTER_UDP_PORT);
        bool occupied;
        xSemaphoreTake(dataMutex, portMAX_DELAY);
        occupied = seatOccupied;
        xSemaphoreGive(dataMutex);
        sendSeatEvent(0, occupied);
      }
    } else if (strcmp(type, "ack") == 0) {
      const char* ackUid = doc["uid"] | "";
      const uint32_t ackSession = doc["session"] | 0U;
      const uint32_t ackSeq = doc["seq"] | 0U;
      if (strcmp(ackUid, nodeUid) == 0 && ackSession == udpSession) {
        lastMasterAckMs = millis();
        masterConnected = true;
        if (pendingCall && ackSeq == pendingCallSeq) {
          pendingCall = false;
          Serial.printf("[UDP] CALL acknowledged seq=%lu after %u attempt(s)\n",
                        (unsigned long)ackSeq, pendingCallRetries + 1);
        }
      }
    } else if (strcmp(doc["action"] | "", "setSeatId") == 0) {
      masterIp = remote;
      applySeatIdCommand(doc);
    }
  }

  const unsigned long now = millis();
  if (WiFi.status() != WL_CONNECTED) {
    masterConnected = false;
    masterIp = IPAddress();
    // WiFi.setAutoReconnect(true) owns association retries. Calling
    // WiFi.reconnect() every few seconds while the driver is already joining
    // causes "sta is connecting, return error" and can prolong recovery.
    static unsigned long lastWaitingLog = 0;
    if (now - lastWaitingLog >= 10000) {
      lastWaitingLog = now;
      Serial.println("[WiFi] waiting for automatic reconnect to iot_bus...");
    }
    return;
  }

  if (lastMasterAckMs && now - lastMasterAckMs > MASTER_ACK_TIMEOUT_MS) {
    if (masterConnected) Serial.println("[UDP] master ACK timeout - rediscovering");
    masterConnected = false;
    masterIp = IPAddress();
  }
  if (masterIp == IPAddress() && now - lastDiscoveryMs >= DISCOVERY_INTERVAL_MS) {
    lastDiscoveryMs = now;
    sendMasterDiscovery();
  }

  if (pendingCall && masterIp != IPAddress()) {
    const unsigned long interval = pendingCallRetries < 10
      ? CALL_RETRY_FAST_MS : CALL_RETRY_SLOW_MS;
    if (now - pendingCallSentMs >= interval) {
      pendingCallSentMs = now;
      ++pendingCallRetries;
      sendSeatPacket(pendingCallSeq, 1, pendingCallOccupied);
    }
  }
}

static void connectRouter() {
  WiFi.setAutoReconnect(true);
  WiFi.persistent(false);
  Serial.printf("[WiFi] connecting to router %s", ROUTER_SSID);
  WiFi.begin(ROUTER_SSID, ROUTER_PASS);
  const unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < 20000) {
    handleSerial();
    delay(250);
    Serial.print('.');
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] router connected - IP %s, RSSI %d dBm\n",
                  WiFi.localIP().toString().c_str(), (int)WiFi.RSSI());
  } else {
    Serial.println("\n[WiFi] router unavailable - continuing with auto reconnect");
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("[Firmware] Passenger Seat v1.7 ESP32-WROOM-32U DynamicID");

  // Why did we boot? This is the single most useful clue when a seat drops
  // out in the field with no USB attached:
  //   POWERON(1)=clean start   BROWNOUT(11)=supply sagged (power problem)
  //   TASK_WDT/INT_WDT(6,7)    PANIC(4)=crash   SW(3)=our own ESP.restart()
  // It is also reported to the master (see sendDiag) so it is visible without
  // physically reaching the seat.
  Serial.printf("[Boot] reset reason: %d\n", (int)esp_reset_reason());

  // -- was low-level RTC clock API to drop CPU to 80MHz (removed in core 3.x) --
  // rtc_cpu_freq_config_t config;
  // rtc_clk_cpu_freq_get_config(&config);
  // rtc_clk_cpu_freq_to_config(RTC_CPU_FREQ_80M, &config);
  // rtc_clk_cpu_freq_set_config_fast(&config);
  setCpuFrequencyMhz(80);

  WiFi.onEvent(onWiFiDisconnected, ARDUINO_EVENT_WIFI_STA_DISCONNECTED);
  WiFi.mode(WIFI_STA);   // station mode (also needed for MAC fallback in loadSeatId)
  // Disable WiFi modem sleep. By default the radio powers down between beacons
  // (WIFI_PS_MIN_MODEM); on a marginal 5V supply that leads to missed beacons
  // and a silent drop-off after tens of minutes of otherwise healthy uptime.
  // A seat node is mains-powered and must stay associated, so trade the few mA
  // for a link that stays up.
  WiFi.setSleep(false);
  loadSeatId();          // seat id from NVS, else MAC-derived unique fallback

  pinMode(LOAD_SENSOR_PIN, INPUT);
  analogReadResolution(12);
  // GPIO34 has no internal pull-up or pull-down. The external FSR voltage
  // divider must always bias this input so it never floats.
  analogSetPinAttenuation(LOAD_SENSOR_PIN, ADC_11db);
  Serial.printf("[Pressure] analog sensor ready on GPIO%d (ON >= %u, OFF <= %u)\n",
                LOAD_SENSOR_PIN, (unsigned)PRESSURE_OCCUPIED_ON,
                (unsigned)PRESSURE_OCCUPIED_OFF);

  // -- was INPUT: floating pin caused random ISR fires from noise --
  pinMode(BUTTON_PIN, INPUT_PULLUP);   // button to GND: pressed = LOW = sensorState 1
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(50);
  // Paint "not linked" yellow before the router association starts.
  fill_solid(leds, NUM_LEDS, CRGB::Yellow);
  FastLED.show();
  buttonRawState = digitalRead(BUTTON_PIN);
  buttonStableState = buttonRawState;
  buttonArmed = (buttonStableState == HIGH);  // held at boot must be released first
  buttonRawChangedMs = millis();

  dataMutex = xSemaphoreCreateMutex();
  xTaskCreate(sensorTask, "Sensor", 8192, NULL, 1, NULL);

  // Join the router, then discover the master over UDP.
  udpSession = esp_random();
  if (udpSession == 0) udpSession = 1;
  connectRouter();
  if (!smartbusUdp.begin(SEAT_UDP_PORT)) {
    Serial.printf("[UDP] ERROR: cannot bind local port %u\n", SEAT_UDP_PORT);
  } else {
    Serial.printf("[UDP] local receiver ready on port %u, session %lu\n",
                  SEAT_UDP_PORT, (unsigned long)udpSession);
  }
}

void loop() {
  // Update LEDs from the main loop to keep FastLED and WiFi servicing serialized.
  //   yellow → not linked to the master (occupancy is not being reported, so
  //            showing red/white here would be a lie)
  //   red    → seat occupied
  //   white  → seat free
  {
    bool occupied;
    xSemaphoreTake(dataMutex, portMAX_DELAY);
    occupied = seatOccupied;
    xSemaphoreGive(dataMutex);
    CRGB colour = !masterConnected ? CRGB::Yellow
                : occupied     ? CRGB::Red
                :                CRGB::White;
    fill_solid(leds, NUM_LEDS, colour);
    FastLED.show();
  }

  handleUdpTransport();

  // UDP health, rediscovery, and WiFi auto-reconnect run without rebooting.

  // Button → seat call. Accept exactly one event for each stable press, then
  // keep it disarmed until a stable release is observed.
  const bool rawButton = digitalRead(BUTTON_PIN);
  if (rawButton != buttonRawState) {
    buttonRawState = rawButton;
    buttonRawChangedMs = millis();
  }
  if (buttonStableState != buttonRawState &&
      millis() - buttonRawChangedMs >= BUTTON_DEBOUNCE_MS) {
    buttonStableState = buttonRawState;
    if (buttonStableState == HIGH) {
      buttonArmed = true;
      Serial.println("[Button] released — armed");
    } else if (buttonArmed) {
      buttonArmed = false;
      if (!buttonLockoutActive || millis() - lastButtonCallMs >= BUTTON_LOCKOUT_MS) {
        lastButtonCallMs = millis();
        buttonLockoutActive = true;
        bool occupied;
        xSemaphoreTake(dataMutex, portMAX_DELAY);
        occupied = seatOccupied;
        xSemaphoreGive(dataMutex);
        Serial.println("[Button] stable press — sending one call, lockout 10s");
        sendSeatEvent(1, occupied);
      } else {
        Serial.println("[Button] press ignored — 10s lockout active");
      }
    }
  }

  // Occupancy change → telemetry only (sensorState=0, no announcement)
  if (occupancyChanged) {
    bool occupied;
    xSemaphoreTake(dataMutex, portMAX_DELAY);
    occupied = seatOccupied;
    occupancyChanged = false;
    xSemaphoreGive(dataMutex);
    sendSeatEvent(0, occupied);
  }

  // Heartbeat → refresh the master's lastSeen so a still/occupied seat isn't
  // marked offline. sensorState=0, so it never triggers an announcement.
  static unsigned long lastHeartbeat = 0;
  if (millis() - lastHeartbeat >= HEARTBEAT_MS) {
    lastHeartbeat = millis();
    bool occupied;
    xSemaphoreTake(dataMutex, portMAX_DELAY);
    occupied = seatOccupied;
    xSemaphoreGive(dataMutex);
    sendSeatEvent(0, occupied);
  }

  // Health report every 60 s — cheap, and the only visibility into a seat
  // once its USB cable is removed.
  static unsigned long lastDiag = 0;
  if (millis() - lastDiag >= 60000) {
    lastDiag = millis();
    sendDiag();
  }

  handleSerial();   // laptop console — type 'help' for the command list

  delay(10);
}


