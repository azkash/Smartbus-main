#include "variables.h"
// #include "mqtt_broker.h"  // -- reverted: MQTT broker replaced by HTTP server --

// Fungsi mapping XY dengan pola ular
// int XY(int x, int y) {
//   int rowStart = y * NUM_LEDS;
//   if(y % 2 == 0) return rowStart + x;
//   else            return rowStart + (NUM_LEDS - 1 - x);
// }

// Forward-declare so the broker class can call it before it's defined below
bool processCommand(const String& cmd);

// ─── MQTT seat-event flags ─── reverted: not used with HTTP server ────
// static volatile bool mqttSeatReceived = false;
// static volatile int  mqttSeatState    = 0;
// static volatile bool mqttSeatOccupied = false;
// static char          mqttSeatId[32]   = {0};

// ─── Seat-call announcement queue ─────────────────────────────────────
// Filled in onWsEvent (WS task), drained in effectTask (LED task). A FreeRTOS
// queue is used so simultaneous calls don't collide or get dropped, and so the
// blocking playTrack()/delay() runs off the WS callback. Carries the seat id
// so the announcement (and serial log) knows *which* seat called.
struct CallEvent { char id[32]; };
static QueueHandle_t callQueue;   // created in setup()

// ─── Seat roster — tracks every seat node that has reported in ────────
// Updated only from onWsEvent (loop-task context), so no mutex needed.
#define MAX_SEATS        32
#define SEAT_OFFLINE_MS  15000   // no message for 15s → seat considered offline

struct SeatInfo {
  char          id[32];
  bool          occupied;
  bool          calling;      // instantaneous: last reported sensorState (button held)
  bool          callPending;  // latched: a call was raised, not yet acknowledged
  unsigned long lastSeen;     // millis() of last message
  unsigned long callTime;     // millis() when callPending was latched
  bool          online;       // last-logged online state (for ONLINE/OFFLINE edge logging)
  bool          used;         // slot in use
};
static SeatInfo seats[MAX_SEATS];

// Find a seat slot by id, or claim a free one. Returns index, or -1 if full.
static int rosterFind(const char* id) {
  int freeIdx = -1;
  for (int i = 0; i < MAX_SEATS; i++) {
    if (seats[i].used) {
      if (strcmp(seats[i].id, id) == 0) return i;
    } else if (freeIdx < 0) {
      freeIdx = i;
    }
  }
  if (freeIdx < 0) return -1;
  strncpy(seats[freeIdx].id, id, sizeof(seats[freeIdx].id) - 1);
  seats[freeIdx].id[sizeof(seats[freeIdx].id) - 1] = '\0';
  seats[freeIdx].used = true;
  Serial.printf("[Roster] new seat: %s (slot %d)\n", id, freeIdx);
  return freeIdx;
}

// Upsert a seat from an incoming seat event.
static void rosterUpdate(const char* id, int sensorState, bool occupied) {
  if (id[0] == '\0') return;
  int i = rosterFind(id);
  if (i < 0) { Serial.println("[Roster] full — seat ignored"); return; }
  if (!seats[i].online) {
    seats[i].online = true;
    Serial.printf("[Seat] %s ONLINE\n", seats[i].id);
  }
  seats[i].occupied = occupied;
  seats[i].calling  = (sensorState != 0);
  if (sensorState) {
    seats[i].callPending = true;
    seats[i].callTime    = millis();  // record when the call was raised
  }
  seats[i].lastSeen = millis();
}

// Acknowledge/clear a seat's pending call. Returns true if the seat was found.
static bool rosterClear(const char* id) {
  for (int i = 0; i < MAX_SEATS; i++) {
    if (seats[i].used && strcmp(seats[i].id, id) == 0) {
      seats[i].callPending = false;
      Serial.printf("[Roster] call cleared for %s\n", id);
      return true;
    }
  }
  return false;
}

// Build a JSON array of all known seats with full state fields.
// e.g. [{"id":"1A","occupied":false,"calling":false,"callPending":true,"online":true}]
static String rosterJson() {
  DynamicJsonDocument doc(MAX_SEATS * 128);
  JsonArray arr = doc.to<JsonArray>();
  unsigned long now = millis();
  for (int i = 0; i < MAX_SEATS; i++) {
    if (!seats[i].used) continue;
    JsonObject obj    = arr.createNestedObject();
    obj["id"]          = seats[i].id;
    obj["occupied"]    = seats[i].occupied;
    obj["calling"]     = seats[i].calling;
    obj["callPending"] = seats[i].callPending;
    obj["online"]      = (now - seats[i].lastSeen) < SEAT_OFFLINE_MS;
  }
  String out;
  serializeJson(doc, out);
  return out;
}

// ─── MQTT Broker instance ─── reverted ────────────────────────────────
// MqttBroker mqttBroker;

// #include <WiFiManager.h>  // disabled — skipping portal, straight to AP

static void wifiInit() {
  // AP+STA mode, but the STA link stays IDLE at boot — the master joins the
  // upstream WiFi only when the headunit requests it (see wifiConnect below).
  // This keeps seats online immediately and avoids an AP channel-hop at boot.
  WiFi.setHostname("bus-led");   // DHCP hostname when the STA joins a router
  WiFi.mode(WIFI_AP_STA);

  // softAP(ssid, pass, channel, hidden, max_connection). max_connection 8 —
  // the default 4 fills fast (headunit + gateway + seats) and evicts stations.
  WiFi.softAP(ap_ssid, ap_password, 1, 0, 8);
  Serial.printf("[AP] SSID: %s  IP: %s  channel 1  (max 8 clients)\n",
                ap_ssid, WiFi.softAPIP().toString().c_str());

  // Auto-connect to saved Wi-Fi at boot if available, otherwise default/idle
  prefs.begin("wifi", true);
  String savedSsid = prefs.getString("ssid", "");
  String savedPass = prefs.getString("pass", "");
  prefs.end();

  if (savedSsid.length() > 0) {
    Serial.printf("[STA] Boot: Auto-connecting to saved Wi-Fi '%s'...\n", savedSsid.c_str());
    staConnect(savedSsid, savedPass);
  } else if (STA_SSID[0] != '\0') {
    Serial.printf("[STA] Boot: Auto-connecting to default Wi-Fi '%s'...\n", STA_SSID);
    staConnect(String(STA_SSID), String(STA_PASS));
  } else {
    Serial.println("[STA] idle – waiting for headunit wifiConnect request");
  }

  // mDNS: the tablet can reach us as bus-led.local (on the AP subnet, and on
  // the upstream network too if wifiConnect is used later). The fixed softAP
  // IP 192.168.4.1 always works as a fallback.
  if (MDNS.begin("bus-led")) {
    MDNS.addService("ws", "tcp", 81);
    Serial.println("[mDNS] responder up: bus-led.local (WS port 81)");
  } else {
    Serial.println("[mDNS] start failed");
  }
}

// ─── STA control (triggered by headunit request) ─────────────────────
// Kicks off a non-blocking join to the upstream WiFi. Empty ssid falls back to
// the configured STA_SSID/STA_PASS. WiFi.begin() returns immediately; the
// connection result is reported from loop() when the state actually changes.
static void staConnect(const String& ssid, const String& pass) {
  String s = ssid;
  String p = pass;

  if (s.length() == 0) {
    // Cari dari Preferences terlebih dahulu
    prefs.begin("wifi", true);
    s = prefs.getString("ssid", "");
    p = prefs.getString("pass", "");
    prefs.end();

    // Jika tidak ada di Preferences, gunakan default compile-time
    if (s.length() == 0) {
      s = String(STA_SSID);
      p = String(STA_PASS);
    }
  } else {
    // Simpan Wi-Fi baru ke Preferences jika dikirim manual dari Headunit
    prefs.begin("wifi", false);
    prefs.putString("ssid", ssid);
    prefs.putString("pass", pass);
    prefs.end();
    Serial.println("[STA] Kredensial Wi-Fi baru disimpan ke NVS/Preferences");
  }

  if (s.length() == 0 || s == "") {
    Serial.println("[STA] connect requested but no SSID configured/provided");
    return;
  }

  Serial.printf("[STA] connect requested - joining '%s' (AP may hop channel)
", s.c_str());
  WiFi.begin(s.c_str(), p.c_str());
}

static void staDisconnect() {
  Serial.println("[STA] disconnect requested");
  WiFi.disconnect();   // drops STA only; softAP stays up
}

// Build a status line the headunit can parse, e.g.
// {"status":"wifi","connected":true,"ssid":"Thankyou","ip":"192.168.1.42"}
static String wifiStatusJson() {
  DynamicJsonDocument doc(192);
  bool up = (WiFi.status() == WL_CONNECTED);
  doc["status"]    = "wifi";
  doc["connected"] = up;
  doc["ssid"]      = up ? WiFi.SSID()               : String("");
  doc["ip"]        = up ? WiFi.localIP().toString() : String("");
  String out; serializeJson(doc, out); return out;
}

// ─── Inverter relay ────────────────────────────────────────────────────
// The Inverter module (separate ESP32, plain HTTP :80, GET /data) is a
// station on our own AP. We poll it on its own task and hand the headunit
// the readings over the WebSocket link it already has — one connection for
// both seats and power telemetry, instead of the tablet juggling two.
struct InverterData {
  float vac = 0, cac = 0, pac = 0, eac = 0, pfac = 0, freqac = 0, vdc = 0;
  bool  online = false;
};
static InverterData    inverterData;
static SemaphoreHandle_t inverterMutex;
static IPAddress       inverterIP;
static bool            inverterIPKnown = false;

// Resolve bus-inverter.local via mDNS, falling back to INVERTER_FALLBACK_IP
// if that's set and mDNS comes up empty (some routers/hardware are flaky
// with mDNS between two stations on the same softAP).
static bool resolveInverterIP() {
  IPAddress ip = MDNS.queryHost(INVERTER_HOSTNAME, 3000);
  if (ip != IPAddress(0, 0, 0, 0)) {
    inverterIP = ip;
    inverterIPKnown = true;
    Serial.printf("[Inverter] resolved %s.local → %s\n", INVERTER_HOSTNAME, ip.toString().c_str());
    return true;
  }
  if (INVERTER_FALLBACK_IP[0] != '\0' && inverterIP.fromString(INVERTER_FALLBACK_IP)) {
    inverterIPKnown = true;
    Serial.printf("[Inverter] mDNS failed — using fallback IP %s\n", INVERTER_FALLBACK_IP);
    return true;
  }
  Serial.println("[Inverter] could not resolve bus-inverter.local");
  return false;
}

// Runs on its own task so a slow/unreachable Inverter never stalls the
// WebSocket loop() or seat processing.
void inverterPollTask(void*) {
  for (;;) {
    if (!inverterIPKnown && !resolveInverterIP()) {
      vTaskDelay(pdMS_TO_TICKS(3000));   // back off, then retry resolution
      continue;
    }

    HTTPClient http;
    http.begin("http://" + inverterIP.toString() + "/data");
    http.setTimeout(1500);
    int code = http.GET();

    if (code == 200) {
      DynamicJsonDocument doc(256);
      if (!deserializeJson(doc, http.getString())) {
        xSemaphoreTake(inverterMutex, portMAX_DELAY);
        inverterData.vac    = doc["vac"]    | 0.0f;
        inverterData.cac    = doc["cac"]    | 0.0f;
        inverterData.pac    = doc["pac"]    | 0.0f;
        inverterData.eac    = doc["eac"]    | 0.0f;
        inverterData.pfac   = doc["pfac"]   | 0.0f;
        inverterData.freqac = doc["freqac"] | 0.0f;
        inverterData.vdc    = doc["vdc"]    | 0.0f;
        inverterData.online = true;
        xSemaphoreGive(inverterMutex);
      }
    } else {
      xSemaphoreTake(inverterMutex, portMAX_DELAY);
      inverterData.online = false;
      xSemaphoreGive(inverterMutex);
      inverterIPKnown = false;   // DHCP lease may have changed — re-resolve next round
      Serial.printf("[Inverter] poll failed (code %d) — will re-resolve\n", code);
    }
    http.end();

    vTaskDelay(pdMS_TO_TICKS(2000));   // matches the Inverter's own sensor refresh rate
  }
}

// e.g. {"status":"inverter","online":true,"vac":220.1,"cac":1.234,"pac":271.5,
//       "eac":12.34,"pfac":0.98,"freqac":50.0,"vdc":12.65}
static String inverterStatusJson() {
  DynamicJsonDocument doc(256);
  xSemaphoreTake(inverterMutex, portMAX_DELAY);
  doc["status"]  = "inverter";
  doc["online"]  = inverterData.online;
  doc["vac"]     = inverterData.vac;
  doc["cac"]     = inverterData.cac;
  doc["pac"]     = inverterData.pac;
  doc["eac"]     = inverterData.eac;
  doc["pfac"]    = inverterData.pfac;
  doc["freqac"]  = inverterData.freqac;
  doc["vdc"]     = inverterData.vdc;
  xSemaphoreGive(inverterMutex);
  String out; serializeJson(doc, out); return out;
}

/* -- reverted: MQTT broker init/publish replaced by HTTP server (handleCommand/handleData) --
static void mqttBrokerInit() {
  mqttBroker.onMessage = [](const String& topic, const String& payload) {
    Serial.printf("[MQTT Broker] %s → %s\n", topic.c_str(), payload.c_str());

    if (topic == MQTT_TOPIC_CMD) {
      String ack = processCommand(payload)
        ? "{\"status\":\"ok\",\"cmd\":\"" + payload + "\"}"
        : "{\"status\":\"error\",\"msg\":\"unknown cmd\"}";
      mqttBroker.publish(MQTT_TOPIC_STATUS, ack);

    } else if (topic == MQTT_TOPIC_SEAT_EVENT) {
      int stIdx = payload.indexOf("\"sensorState\":");
      mqttSeatState    = (stIdx >= 0) ? payload.substring(stIdx + 14).toInt() : 0;
      mqttSeatOccupied = payload.indexOf("\"seatOccupied\":true") >= 0;
      int idIdx = payload.indexOf("\"id\":\"");
      if (idIdx >= 0) {
        int idEnd = payload.indexOf("\"", idIdx + 6);
        payload.substring(idIdx + 6, idEnd).toCharArray(mqttSeatId, sizeof(mqttSeatId));
      }
      mqttSeatReceived = true;
      mqttBroker.publish(MQTT_TOPIC_SENSOR, payload);  // forward to subscribers
    }
  };

  mqttBroker.begin();
  Serial.printf("[MQTT Broker] Running on %s:1883\n",
                WiFi.softAPIP().toString().c_str());
}

void mqttPublishSensor(const char* id, int state, bool occupied) {
  char buf[128];
  snprintf(buf, sizeof(buf),
    "{\"id\":\"%s\",\"sensorState\":%d,\"seatOccupied\":%s}",
    id, state, occupied ? "true" : "false");
  mqttBroker.publish(MQTT_TOPIC_SENSOR, String(buf));
  Serial.printf("[MQTT Broker] Published: %s\n", buf);
}
-- end reverted MQTT broker block -- */

// ─── LED settings persistence (NVS / Preferences) ────────────────────
static void saveSettings() {
  prefs.begin("led", false);  // read-write
  prefs.putBool ("on",  ledOn);
  prefs.putUChar("bri", ledBrightness);
  prefs.putUChar("eff", (uint8_t)ledEffect);
  prefs.putUChar("r",   ledR);
  prefs.putUChar("g",   ledG);
  prefs.putUChar("b",   ledB);
  prefs.end();
}

static void loadSettings() {
  prefs.begin("led", true);   // read-only (returns defaults if unset)
  ledOn         = prefs.getBool ("on",  ledOn);
  ledBrightness = prefs.getUChar("bri", ledBrightness);
  ledEffect     = (LedEffect)prefs.getUChar("eff", (uint8_t)ledEffect);
  ledR          = prefs.getUChar("r",   ledR);
  ledG          = prefs.getUChar("g",   ledG);
  ledB          = prefs.getUChar("b",   ledB);
  prefs.end();
  Serial.printf("[NVS] loaded: on=%d bri=%d eff=%d rgb=%d,%d,%d\n",
                ledOn, ledBrightness, ledEffect, ledR, ledG, ledB);
}

// ─── Shared Command Processor ─────────────────────────────────────────
bool processCommand(const String& cmd) {
  if (cmd == "on" || cmd == "ws_on") {
    ledOn = true;
    Serial.println("WS2811 ON");
  }
  else if (cmd == "off" || cmd == "ws_off") {
    ledOn = false;
    Serial.println("WS2811 OFF");
  }
  else if (cmd.startsWith("dimmer_")) {
    int val = cmd.substring(7).toInt();
    ledBrightness = map(constrain(val, 0, 100), 0, 100, 0, 255);
    Serial.printf("Dimmer→brightness: %d%% = %d\n", val, ledBrightness);
  }
  else if (cmd.startsWith("rgb_")) {
    int first  = cmd.indexOf('_');
    int second = cmd.indexOf('_', first + 1);
    int third  = cmd.lastIndexOf('_');
    ledOn = false;
    ledR = cmd.substring(first + 1, second).toInt();
    ledG = cmd.substring(second + 1, third).toInt();
    ledB = cmd.substring(third + 1).toInt();
    ledEffect = EFF_SOLID;
    ledOn = true;
    Serial.printf("RGB→WS2811 color: R:%d G:%d B:%d\n", ledR, ledG, ledB);
  }
  else if (cmd.startsWith("ws_color_")) {
    String vals = cmd.substring(9);
    int first  = vals.indexOf('_');
    int second = vals.lastIndexOf('_');
    ledR = vals.substring(0, first).toInt();
    ledG = vals.substring(first + 1, second).toInt();
    ledB = vals.substring(second + 1).toInt();
    Serial.printf("WS2811 color: R:%d G:%d B:%d\n", ledR, ledG, ledB);
  }
  else if (cmd.startsWith("ws_brightness_")) {
    ledBrightness = constrain(cmd.substring(14).toInt(), 0, 255);
    Serial.printf("WS2811 brightness: %d\n", ledBrightness);
  }
  else if (cmd.startsWith("bright_")) {
    ledBrightness = constrain(cmd.substring(7).toInt(), 0, 255);
    Serial.printf("WS2811 brightness: %d\n", ledBrightness);
  }
  else if (cmd.startsWith("mode_")) {
    String eff = cmd.substring(5);
    if      (eff == "1")     ledEffect = EFF_RAINBOW_GLITTER;
    else if (eff == "2")     ledEffect = EFF_CONFETTI_PARTY;
    else if (eff == "3")     ledEffect = EFF_SINELON_WAVE;
    else if (eff == "4")     ledEffect = EFF_BPM_RHYTHM;
    else if (eff == "5")     ledEffect = EFF_JUGGLE_BOUNCE;
    else if (eff == "6")     ledEffect = EFF_FIRE_FLAME;
    else if (eff == "7")     ledEffect = EFF_AURORA_GLOW;
    else if (eff == "8")     ledEffect = EFF_BINARY_COUNTER;
    else if (eff == "9")     ledEffect = EFF_PALETTE_WAVE;
    else if (eff == "10")    ledEffect = EFF_DUAL_SCANNER;
    else if (eff == "11")    ledEffect = EFF_COLOR_BOUNCE;
    else if (eff == "12")    ledEffect = EFF_SNAKE;
    else return false;
    Serial.printf("WS2811 effect: %s\n", eff.c_str());
  }
  // else if (cmd == "wifi_reset") { }  // WiFiManager removed
  else {
    return false;
  }
  saveSettings();  // persist the change so it survives reboot
  return true;
}

// ─── HTTP Client: POST sensorState to headunit ───────────────────────
// -- reverted: this made the ESP32 an HTTP *client* pushing to the headunit.
//    We want the ESP32 to be the *server* instead (Android hits handleData),
//    so this client function is disabled. --
/*
void sendToHeadunit(int sensorState, long reading, bool seatOccupied = false) {
  WiFiClient client;
  HTTPClient http;
  http.begin(client, "http://" + headunitIP + ":8080/data");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Connection", "close");

  char body[80];
  snprintf(body, sizeof(body), "{\"sensorState\":%d,\"reading\":%ld,\"seatOccupied\":%s}",
           sensorState, reading, seatOccupied ? "true" : "false");
  int code = http.POST(String(body));

  if (code > 0) {
    Serial.printf("[Headunit] POST %d → %s\n", code, body);
  } else {
    Serial.printf("[Headunit] POST failed: %s\n", http.errorToString(code).c_str());
  }
  http.end();
}
*/

// ─── WebSocket event handler — Android app connects as a ws:// client ─
// Client sends a command string as a TEXT frame (same vocabulary as the old
// HTTP GET /command?cmd=...); we run processCommand and reply with a JSON ack.
void onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED: {
      IPAddress ip = webSocket.remoteIP(num);
      Serial.printf("[WS] #%u connected from %s\n", num, ip.toString().c_str());
      // Ask the client to identify its role; seat nodes connecting before the
      // headunit registers will be held until it does.
      webSocket.sendTXT(num, "{\"status\":\"identify\"}");
      break;
    }
    case WStype_DISCONNECTED:
      Serial.printf("[WS] #%u disconnected\n", num);
      if (num == (uint8_t)headunitNum) {
        headunitNum = -1;
        Serial.println("[WS] Headunit gone — seat data paused until it reconnects");
      }
      break;
    case WStype_TEXT: {
      String msg = String((char*)payload);
      Serial.println("[WS] rx: " + msg);

      // ── Headunit registration ─────────────────────────────────────
      // Headunit must send {"role":"headunit"} right after connecting.
      if (msg.indexOf("\"role\":\"headunit\"") >= 0) {
        headunitNum = (int)num;
        Serial.printf("[WS] Headunit registered as client #%u\n", num);
        String roster = rosterJson();
        webSocket.sendTXT(num, roster);   // push current state immediately
        break;
      }

      // ── Seat node events — only processed once headunit is online ─
      int stIdx = msg.indexOf("\"sensorState\":");
      if (stIdx >= 0) {
        if (headunitNum < 0) {
          Serial.printf("[WS] Seat data from #%u ignored — headunit not registered\n", num);
          break;
        }
        int  state    = msg.substring(stIdx + 14).toInt();
        bool occupied = msg.indexOf("\"seatOccupied\":true") >= 0;

        char id[32] = {0};
        int idIdx = msg.indexOf("\"id\":\"");
        if (idIdx >= 0) {
          int idEnd = msg.indexOf("\"", idIdx + 6);
          msg.substring(idIdx + 6, idEnd).toCharArray(id, sizeof(id));
        }

        rosterUpdate(id, state, occupied);

        digitalWrite(LED_BUILTIN, state ? HIGH : LOW);
        if (state) {
          CallEvent ev;
          strncpy(ev.id, id, sizeof(ev.id) - 1);
          ev.id[sizeof(ev.id) - 1] = '\0';
          xQueueSend(callQueue, &ev, 0);
        }

      // ── Headunit commands ─────────────────────────────────────────
      } else if (msg == "roster") {
        String roster = rosterJson();
        webSocket.sendTXT(num, roster);
      } else if (msg.indexOf("\"action\":\"clearCall\"") >= 0) {
        char id[32] = {0};
        int idIdx = msg.indexOf("\"id\":\"");
        if (idIdx >= 0) {
          int idEnd = msg.indexOf("\"", idIdx + 6);
          msg.substring(idIdx + 6, idEnd).toCharArray(id, sizeof(id));
        }
        if (id[0] != '\0') {
          rosterClear(id);
        } else {
          for (int i = 0; i < MAX_SEATS; i++) seats[i].callPending = false;
          Serial.println("[Roster] all calls cleared");
        }
      } else if (msg.startsWith("clear_")) {
        String id = msg.substring(6);
        if (id == "all") {
          for (int i = 0; i < MAX_SEATS; i++) seats[i].callPending = false;
          Serial.println("[Roster] all calls cleared");
        } else {
          rosterClear(id.c_str());
        }

      // ── Headunit-requested upstream WiFi control ──────────────────
      // Connect: {"action":"wifiConnect"}  (uses configured STA_SSID), or
      //          {"action":"wifiConnect","ssid":"X","pass":"Y"}  (override)
      } else if (msg.indexOf("\"action\":\"wifiConnect\"") >= 0) {
        String ssid, pass;
        int sIdx = msg.indexOf("\"ssid\":\"");
        if (sIdx >= 0) ssid = msg.substring(sIdx + 8, msg.indexOf("\"", sIdx + 8));
        int pIdx = msg.indexOf("\"pass\":\"");
        if (pIdx >= 0) pass = msg.substring(pIdx + 8, msg.indexOf("\"", pIdx + 8));
        staConnect(ssid, pass);
        webSocket.sendTXT(num, "{\"status\":\"wifi\",\"state\":\"connecting\"}");
      } else if (msg.indexOf("\"action\":\"wifiDisconnect\"") >= 0) {
        staDisconnect();
        String st = wifiStatusJson();
        webSocket.sendTXT(num, st);
      } else if (msg.indexOf("\"action\":\"wifiStatus\"") >= 0) {
        String st = wifiStatusJson();
        webSocket.sendTXT(num, st);   // headunit polls current state
      } else if (msg == "inverter") {
        String inv = inverterStatusJson();
        webSocket.sendTXT(num, inv);   // headunit polls current inverter reading

      } else {
        String ack = processCommand(msg)
          ? "{\"status\":\"ok\",\"cmd\":\"" + msg + "\"}"
          : "{\"status\":\"error\",\"msg\":\"unknown cmd\"}";
        webSocket.sendTXT(num, ack);
      }
      break;
    }
    default:
      break;
  }
}

// ─── HTTP Handlers ─── replaced by WebSocket (onWsEvent above) ────────
/*
// Flutter: GET /command?cmd=xxx
void handleCommand() {
  if (!server.hasArg("cmd")) {
    server.send(400, "application/json", "{\"status\":\"error\",\"msg\":\"missing cmd\"}");
    return;
  }
  String cmd = server.arg("cmd");
  Serial.println("Perintah masuk: " + cmd);

  if (processCommand(cmd)) {
    server.send(200, "application/json", "{\"status\":\"ok\",\"cmd\":\"" + cmd + "\"}");
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"msg\":\"unknown cmd\"}");
  }
}

// Headunit: POST /data  body: {"sensorState":1}
// Also auto-updates headunit IP from the request source
void handleData() {
  String remoteIP = server.client().remoteIP().toString();
  if (headunitIP != remoteIP) {
    headunitIP = remoteIP;
    Serial.println("[Headunit] IP updated to " + headunitIP);
  }

  String body = server.arg("plain");
  Serial.println("[Headunit] POST: " + body);

  int idx = body.indexOf("\"sensorState\":");
  if (idx < 0) {
    server.send(400, "application/json", "{\"status\":\"error\",\"msg\":\"missing sensorState\"}");
    return;
  }
  int state = body.substring(idx + 14).toInt();
  ledOn = (state == 1);
  Serial.printf("[Headunit] sensorState %d → LED %s\n", state, ledOn ? "ON" : "OFF");

  server.send(200, "application/json", "{\"status\":\"ok\"}");
}
*/

byte commandLength;
byte command[6];
int16_t checkSum;

//sends the command
void sendCommand() {
  int q;
  for (q = 0; q < commandLength; q++) {
    Serial2.write(command[q]);
    Serial.print(" ");
    Serial.print(command[q], HEX);
  }
  Serial.println(" End");
}

//May need to be selected after putting into random mode
void play() {
  command[0] = 0xAA;  //first byte says it's a command
  command[1] = 0x02;
  command[2] = 0x00;
  command[3] = 0xAC;
  commandLength = 4;
  sendCommand();
}

//Play Next
void playNext() {
  command[0] = 0xAA;  //first byte says it's a command
  command[1] = 0x06;
  command[2] = 0x00;
  command[3] = 0xB0;
  commandLength = 4;
  sendCommand();
}

//sets the device volume...0 - 30
void playbackVolume(int vol) {
  if (vol > 30) {  //check within limits
    vol = 30;
  }
  command[0] = 0xAA;  //first byte says it's a command
  command[1] = 0x13;
  command[2] = 0x01;
  command[3] = vol;  //volume
  checkSum = 0;
  for (int q = 0; q < 4; q++) {
    checkSum += command[q];
  }
  command[4] = (checkSum & 0xFF);  //SM check bit... low bit of the sum of all previous values
  commandLength = 5;
  sendCommand();
}

void playTrack(int soundTrack) {
  //select track
  Serial.print("soundTrack: ");
  Serial.println(soundTrack);
  command[0] = 0xAA;//first byte says it's a command
  command[1] = 0x07;
  command[2] = 0x02;
  command[3] = (soundTrack>>8) & 0xFF;//snh...track HIGH bit
  command[4] = soundTrack & 0xFF;//SNL... track low bit
  checkSum = 0;
  for (int q = 0; q < 5; q++) {
    checkSum +=  command[q];
  }
  command[5] = (checkSum & 0xFF);//SM check bit... low bit of the sum of all previous values
  commandLength = 6;
  sendCommand();
}

// ─── Unused effect library ────────────────────────────────────────────
// void rainbow() {
//   static uint8_t hue = 0;
//   fill_rainbow(leds, NUM_LEDS, hue++, 7);
//   FastLED.show(); FastLED.delay(30);
// }
// void rainbowWithGlitter() {
//   static uint8_t hue = 0;
//   fill_rainbow(leds, NUM_LEDS, hue++, 7);
//   if(random8() < 80) leds[random16(NUM_LEDS)] += CRGB::White;
//   FastLED.show(); FastLED.delay(30);
// }
// void confetti() {
//   fadeToBlackBy(leds, NUM_LEDS, 10);
//   int pos = random16(NUM_LEDS);
//   leds[pos] += CHSV(random8(), 200, 255);
//   FastLED.show(); FastLED.delay(50);
// }
// void sinelon() {
//   static uint8_t hue = 0;
//   fadeToBlackBy(leds, NUM_LEDS, 20);
//   int pos = beatsin16(13, 0, NUM_LEDS-1);
//   leds[pos] += CHSV(hue++, 255, 192);
//   FastLED.show(); FastLED.delay(30);
// }
// void bpm() {
//   static uint8_t hue = 0;
//   uint8_t beat = beatsin8(62, 64, 255);
//   for(int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hue + (i*2), 255, beat);
//   hue++; FastLED.show(); FastLED.delay(20);
// }
// void juggle() {
//   static uint8_t hue = 0;
//   fadeToBlackBy(leds, NUM_LEDS, 20);
//   for(int i = 0; i < 8; i++) leds[beatsin16(i+7, 0, NUM_LEDS-1)] |= CHSV(hue + i*32, 200, 255);
//   hue++; FastLED.show(); FastLED.delay(20);
// }
// void fire() {
//   static byte heat[NUM_LEDS];
//   for(int i = 0; i < NUM_LEDS; i++) heat[i] = qsub8(heat[i], random8(0, 30));
//   for(int k = NUM_LEDS-1; k >= 2; k--) heat[k] = (heat[k-1] + heat[k-2] + heat[k-2]) / 3;
//   if(random8() < 40) { int y = random8(7); heat[y] = qadd8(heat[y], random8(160,255)); }
//   for(int j = 0; j < NUM_LEDS; j++) leds[j] = HeatColor(heat[j]);
//   FastLED.show(); FastLED.delay(33);
// }
// void meteor() {
//   static int meteorSize = 10, meteorTrailDecay = 64, pos = 0;
//   for(int i = 0; i < NUM_LEDS; i++) if(random8() > 35) leds[i].fadeToBlackBy(meteorTrailDecay);
//   for(int j = 0; j < meteorSize; j++) if((pos-j < NUM_LEDS) && (pos-j >= 0)) leds[pos-j] = CRGB::White;
//   pos++; if(pos > NUM_LEDS + meteorSize) pos = 0;
//   FastLED.show(); FastLED.delay(30);
// }
// void waveRider() {
//   static uint8_t hue = 0; static int pos = 0;
//   fadeToBlackBy(leds, NUM_LEDS, 30);
//   leds[pos] = CHSV(hue, 255, 255);
//   leds[(pos + NUM_LEDS/2) % NUM_LEDS] = CHSV(hue + 128, 255, 255);
//   if(pos > 1) {
//     leds[pos-1] = CHSV(hue, 255, 150);
//     leds[(pos + NUM_LEDS/2 - 1) % NUM_LEDS] = CHSV(hue + 128, 255, 150);
//   }
//   pos = (pos + 1) % NUM_LEDS; hue += 3;
//   FastLED.show(); FastLED.delay(50);
// }
// void pixelDance() {
//   static uint8_t hue = 0;
//   uint8_t numPixels = random8(3, 6);
//   fill_solid(leds, NUM_LEDS, CRGB::Black);
//   for(int i = 0; i < numPixels; i++) leds[random8(NUM_LEDS)] = CHSV(hue + (i * 30), 255, 255);
//   hue += 10; FastLED.show(); FastLED.delay(200);
// }
// void colorSymphony() {
//   static uint8_t hue = 0;
//   for(int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hue + (i * 5), 255, 255);
//   hue += 2; FastLED.show(); FastLED.delay(50);
// }
// void binaryCounter() {
//   static uint8_t counter = 0;
//   for(int i = 0; i < 8; i++) {
//     leds[i]   = (counter & (1<<i)) ? CRGB::Blue  : CRGB::Black;
//     leds[i+8] = (counter & (1<<i)) ? CRGB::Red   : CRGB::Black;
//     if(i < 4) leds[i+16] = (counter & (1<<i)) ? CRGB::Green : CRGB::Black;
//   }
//   counter++; FastLED.show(); FastLED.delay(500);
// }
// void auroraEffect() {
//   static uint8_t hue = 0;
//   for(int i = 0; i < NUM_LEDS; i++) {
//     uint8_t v = (beatsin8(5,0,255,0,i*10) + beatsin8(7,0,255,0,i*10+85) + beatsin8(4,0,255,0,i*10+170)) / 3;
//     leds[i] = CHSV(hue + (i * 2), 200, v);
//   }
//   hue++; FastLED.show(); FastLED.delay(30);
// }
// void matrixRain() {
//   for(int i = NUM_LEDS-1; i > 0; i--) { leds[i] = leds[i-1]; leds[i].fadeToBlackBy(50); }
//   leds[0] = (random8() < 30) ? CRGB::Green : CRGB::Black;
//   FastLED.show(); FastLED.delay(100);
// }
// void colorBounce() {
//   static int pos = 0, dir = 1; static uint8_t hue = 0;
//   fill_solid(leds, NUM_LEDS, CRGB::Black);
//   leds[pos] = CHSV(hue, 255, 255);
//   for(int i = 1; i <= 3; i++) if(pos-i >= 0) leds[pos-i] = CHSV(hue, 255, 255/(i*2));
//   pos += dir;
//   if(pos >= NUM_LEDS-1 || pos <= 0) { dir *= -1; hue += 60; }
//   FastLED.show(); FastLED.delay(50);
// }
// DEFINE_GRADIENT_PALETTE( ocean_gp ) {
//   0,0,0,143, 48,0,0,255, 96,0,255,255,
//   144,42,255,45, 192,255,255,0, 240,255,0,0, 255,143,0,0
// };
// void paletteWave() {
//   static uint8_t startIndex = 0;
//   CRGBPalette16 palette = ocean_gp;
//   for(int i = 0; i < NUM_LEDS; i++) leds[i] = ColorFromPalette(palette, startIndex + i*5, 255, LINEARBLEND);
//   startIndex += 2; FastLED.show(); FastLED.delay(30);
// }
// void dualScanner() {
//   static int pos1=0, pos2=NUM_LEDS/2, dir1=1, dir2=-1;
//   fadeToBlackBy(leds, NUM_LEDS, 30);
//   leds[pos1] = CRGB::Red; leds[pos2] = CRGB::Blue;
//   pos1 += dir1; pos2 += dir2;
//   if(pos1 >= NUM_LEDS || pos1 < 0) dir1 *= -1;
//   if(pos2 >= NUM_LEDS || pos2 < 0) dir2 *= -1;
//   FastLED.show(); FastLED.delay(50);
// }
// void fireworks() {
//   static uint8_t fadeRate = 100;
//   if(random8() < 10) {
//     uint8_t pos = random8(NUM_LEDS/4, NUM_LEDS*3/4), hue = random8(), size = random8(3,6);
//     leds[pos] = CHSV(hue, 255, 255);
//     for(int i=1; i<=size; i++) {
//       if(pos+i < NUM_LEDS) leds[pos+i] = CHSV(hue+random8(30), 255, 255);
//       if(pos-i >= 0)       leds[pos-i] = CHSV(hue+random8(30), 255, 255);
//     }
//   }
//   for(int i = 0; i < NUM_LEDS; i++) leds[i].fadeToBlackBy(fadeRate);
//   FastLED.show(); FastLED.delay(33);
// }
// void trisakti() {
//   static int cycle = 0; static unsigned long counter = 0;
//   counter++;
//   if (cycle == 0) {
//     fill_solid(leds, NUM_LEDS, CRGB::Black); FastLED.show();
//     if (counter >= 50) { cycle = 1; counter = 0; }
//   } else if (cycle == 1) {
//     uint8_t val = (counter<600) ? map(counter,0,599,0,255) : (counter<700) ? 255 : (counter<800) ? map(counter,700,799,255,0) : 0;
//     fill_solid(leds, NUM_LEDS, CRGB(val,0,0)); FastLED.show();
//     if(counter >= 900) { cycle = 2; counter = 0; }
//   } else if (cycle == 2) {
//     uint8_t val = (counter<600) ? map(counter,0,599,0,255) : (counter<700) ? 255 : (counter<800) ? map(counter,700,799,255,0) : 0;
//     fill_solid(leds, NUM_LEDS, CRGB(0,val,0)); FastLED.show();
//     if(counter >= 900) { cycle = 3; counter = 0; }
//   } else if (cycle == 3) {
//     uint8_t val = (counter<600) ? map(counter,0,599,0,255) : (counter<700) ? 255 : (counter<800) ? map(counter,700,799,255,0) : 0;
//     fill_solid(leds, NUM_LEDS, CRGB(val,val/5,0)); FastLED.show();
//     if(counter >= 900) { cycle = 4; counter = 0; }
//   } else if (cycle == 4) {
//     uint8_t val = (counter<600) ? map(counter,0,599,0,150) : (counter<700) ? 150 : (counter<800) ? map(counter,700,799,150,0) : 0;
//     uint8_t red = (val > 130) ? 130 : val;
//     fill_solid(leds, NUM_LEDS, CRGB(red,0,val)); FastLED.show();
//     if(counter >= 900) { cycle = 1; counter = 0; }
//   }
//   delay(1);
// }
// void pickNewColor() { carColor = CHSV(random8(), 255, 255); }
// void car() {
//   fadeToBlackBy(leds, NUM_LEDS, FADE_RATE);
//   for(int i = 0; i < CAR_LENGTH; i++) {
//     int pos = carPosition - i;
//     if(pos < 0) pos += NUM_LEDS;
//     leds[pos] = carColor;
//     leds[pos].fadeToBlackBy(i * (255/CAR_LENGTH));
//   }
//   FastLED.show();
//   carPosition = (carPosition + 1) % NUM_LEDS;
//   if(carPosition == 0) pickNewColor();
//   delay(50);
// }
// void ular() {
//   static int counter = 0, colorIndex = 0;
//   static unsigned long lastColorChange = millis();
//   if(millis() - lastColorChange > colorChangeInterval) { colorIndex = (colorIndex+1) % paletteCount; lastColorChange = millis(); }
//   for(int i = NUM_LEDS-1; i > 0; i--) leds[i] = leds[i-1];
//   if(counter % (snakeLength + gapBetweenSnakes) < snakeLength) {
//     int posInSnake = counter % (snakeLength + gapBetweenSnakes);
//     uint8_t brightness = 255;
//     if(posInSnake < fadeSize) brightness = map(posInSnake, 0, fadeSize-1, 80, 255);
//     else if(posInSnake >= snakeLength-fadeSize) brightness = map(posInSnake, snakeLength-fadeSize, snakeLength-1, 255, 80);
//     leds[0] = colorPalette[colorIndex];
//     leds[0].fadeToBlackBy(255 - brightness);
//   } else { leds[0] = CRGB::Black; }
//   FastLED.show(); delay(moveDelay); counter++;
// }
// void gradasi() {
//   static uint8_t hue = 10;
//   for(int i = 0; i < NUM_LEDS; i++) leds[i] += CHSV(hue + (i*2), 255, 50);
//   fadeToBlackBy(leds, NUM_LEDS, 10);
//   FastLED.show(); delay(50); hue++;
// }
// void controlLed(int r, int g, int b) {
//   fill_solid(leds, NUM_LEDS, CRGB(r, g, b));
//   FastLED.show();
// }

// mode 1: rainbow
// mode 2: confeti
// mode 3: sinefon
// mode 4: bpm
// mode 5: juggle
// mode 6: fire
// mode 7: aurora
// mode 8: binary 
// mode 9: palette
// mode 10: dual scanner
// mode 11: color bounce
// mode 12: snake