// ─────────────────────────────────────────────────────────────────────
//  SLAVE GATEWAY — WiFi/WebSocket range extender for the bus seat system
// ─────────────────────────────────────────────────────────────────────
//  Purpose: extend the master's coverage down a long bus. Seats too far
//  from the master connect to THIS gateway instead. The gateway has no
//  audio, LEDs or sensors — it is a pure WebSocket bridge.
//
//  Topology
//    UPSTREAM   : STA + WebSocket *client* → master AP "Seat-Monitoring-Bus"
//                 at ws://192.168.4.1:81
//    DOWNSTREAM : softAP + WebSocket *server* on port 81 → far seat nodes
//                 connect here (gateway softAP IP = 192.168.5.1)
//
//  Relay rule (application layer — no NAT needed):
//    • any TEXT from a downstream seat  → forwarded verbatim UP to master
//    • any TEXT from the master (upstream) → broadcast verbatim DOWN to seats
//
//  The master keys its roster by seat "id", so every seat behind this
//  gateway is multiplexed over the single uplink without collision.
//
//  ── Seat nodes that should attach to THIS gateway need (in their code):
//        WIFI_SSID = "Seat-Gateway"
//        WS_HOST   = "192.168.5.1"
//     Seats left pointing at the master are unaffected.
// ─────────────────────────────────────────────────────────────────────

#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <WebSocketsClient.h>
#include <Preferences.h>

// ─── Upstream: the master AP ─────────────────────────────────────────
const char* MASTER_SSID = "Seat-Monitoring-Bus";
const char* MASTER_PASS = "12345678";
const char* MASTER_HOST = "192.168.4.1";   // master softAP IP
const int   MASTER_PORT = 81;
const char* MASTER_PATH = "/";

// ─── Downstream: this gateway's own AP ───────────────────────────────
// Different SSID + different subnet than the master so the two APs don't
// clash and the gateway can route to the master without a self-conflict.
//
// Each gateway broadcasts "Seat-GW-<n>", with <n> stored in NVS and set once
// over serial:   setgw=2
// One firmware serves every gateway, and seats are assigned to a number so
// load is planned rather than left to whichever AP happens to be loudest.
// All gateways keep the same AP IP (192.168.5.1): each AP is its own L2
// network, so there is no collision and seats need no per-gateway address.
#define     GW_SSID_PREFIX "Seat-GW-"
const char* GW_PASS = "12345678";
Preferences gwPrefs;
int         gwId = 1;     // from NVS, defaults to 1 if never provisioned
String      gwSsid;       // "Seat-GW-<n>", built at boot
String      upHost;       // parent's IP, learned from DHCP after associating

// Gateways CHAIN: GW1 uplinks to the master, GW2 to GW1, GW3 to GW2 …
//
// Each gateway therefore needs its OWN subnet: 192.168.<5+n>.0/24, so
// GW1 = 192.168.6.1, GW2 = 192.168.7.1, and so on. With every gateway on a
// shared 192.168.5.x the STA and the local AP would sit on the same subnet
// and the gateway would route to itself instead of its parent.
//
// The parent's address is never hard-coded: after associating we read
// WiFi.gatewayIP(), which DHCP set to the parent AP's own IP. That works
// identically whether the parent is the master or another gateway.
#define     GW_SUBNET_BASE 5
IPAddress   GW_IP;        // 192.168.<5+n>.1, computed once gwId is known
IPAddress   GW_MASK(255, 255, 255, 0);

#define LED_PIN 2   // onboard LED: solid = uplink up, blink = uplink down

WebSocketsServer wsDown = WebSocketsServer(81);  // far seats connect here
WebSocketsClient wsUp;                            // connects to the master

volatile bool upstreamConnected = false;

// ─── Downstream server: a seat sent us something → push it up ────────
void onDownEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED: {
      IPAddress ip = wsDown.remoteIP(num);
      Serial.printf("[DOWN] seat #%u connected from %s\n", num, ip.toString().c_str());
      // Mirror the master: prompt the seat to identify so it registers with
      // the master immediately instead of waiting for its next heartbeat.
      wsDown.sendTXT(num, "{\"status\":\"identify\"}");
      break;
    }
    case WStype_DISCONNECTED:
      Serial.printf("[DOWN] seat #%u disconnected\n", num);
      break;
    case WStype_TEXT:
      Serial.printf("[DOWN→UP] %s\n", (char*)payload);
      if (upstreamConnected) {
        wsUp.sendTXT(payload, length);   // forward seat event to the master
      } else {
        Serial.println("[DOWN→UP] dropped — uplink down");
      }
      break;
    default:
      break;
  }
}

// ─── Upstream client: master sent something → push it down to seats ──
void onUpEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      upstreamConnected = true;
      Serial.printf("[UP] connected to master %s:%d\n", MASTER_HOST, MASTER_PORT);
      break;
    case WStype_DISCONNECTED:
      upstreamConnected = false;
      Serial.println("[UP] disconnected from master");
      break;
    case WStype_TEXT:
      Serial.printf("[UP→DOWN] %s\n", (char*)payload);
      wsDown.broadcastTXT(payload, length);  // relay master broadcast to all seats
      break;
    default:
      break;
  }
}

// ─── Gateway number persistence (NVS) ─────────────────────────────────
static void saveGwId(int id) {
  gwPrefs.begin("gw", false);
  gwPrefs.putInt("id", id);
  gwPrefs.end();
}

static void loadGwId() {
  gwPrefs.begin("gw", true);
  gwId = gwPrefs.getInt("id", 1);
  gwPrefs.end();
  gwSsid = String(GW_SSID_PREFIX) + gwId;
  GW_IP  = IPAddress(192, 168, GW_SUBNET_BASE + gwId, 1);   // own subnet per gateway
  Serial.printf("[Gateway] number %d → SSID '%s'  AP %s  (send 'setgw=N' to change)\n",
                gwId, gwSsid.c_str(), GW_IP.toString().c_str());
}

// ─── Serial command handler (laptop ↔ gateway) ────────────────────────
// Line-based, one command per line, case-insensitive. Mirrors the master's
// and the seat's console so all three behave the same way.
static void handleSerial() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (!line.length()) return;

  String cmd = line, arg;
  int sp = line.indexOf(' ');
  if (sp > 0) { cmd = line.substring(0, sp); arg = line.substring(sp + 1); arg.trim(); }
  // also accept "setgw=2" as well as "setgw 2"
  int eq = cmd.indexOf('=');
  if (eq > 0) { arg = cmd.substring(eq + 1); cmd = cmd.substring(0, eq); arg.trim(); }
  cmd.toLowerCase();

  if (cmd == "help" || cmd == "?") {
    Serial.println(F(
      "\n--- GATEWAY commands ---\n"
      "  help             this list\n"
      "  status           number, SSID, uplink, connected seats\n"
      "  setgw <1-99>     set this gateway's number (reboots)\n"
      "  id?              short identity line\n"
      "  restart          reboot the gateway\n"));

  } else if (cmd == "status") {
    Serial.printf("gateway  : %d  (SSID %s)\n", gwId, gwSsid.c_str());
    Serial.printf("uptime   : %lu s\n", millis() / 1000);
    Serial.printf("heap     : %u bytes free\n", (unsigned)ESP.getFreeHeap());
    Serial.printf("AP       : %s  clients=%d\n",
                  WiFi.softAPIP().toString().c_str(), WiFi.softAPgetStationNum());
    if (WiFi.status() == WL_CONNECTED)
      Serial.printf("uplink   : master  IP %s  RSSI %d dBm  WS %s\n",
                    WiFi.localIP().toString().c_str(), (int)WiFi.RSSI(),
                    upstreamConnected ? "up" : "DOWN");
    else
      Serial.println("uplink   : WiFi down");

  } else if (cmd == "setgw") {
    int id = arg.toInt();
    if (id >= 1 && id <= 99) {
      saveGwId(id);
      Serial.printf("gateway number set to %d — restarting...\n", id);
      delay(200);
      ESP.restart();
    } else {
      Serial.println("usage: setgw <1-99>");
    }

  } else if (cmd == "id?" || cmd == "id") {
    Serial.printf("gateway = %d  SSID = %s\n", gwId, gwSsid.c_str());

  } else if (cmd == "restart") {
    Serial.println("restarting...");
    delay(200);
    ESP.restart();

  } else {
    Serial.printf("unknown command '%s' — type 'help'\n", cmd.c_str());
  }
}

// ─── Upstream selection (chained) ─────────────────────────────────────
// Associate with one AP and, on success, learn the parent's address from
// DHCP. WiFi.gatewayIP() is the AP's own IP, so this works unchanged whether
// the parent is the master (192.168.4.1) or another gateway (192.168.<5+n>.1).
static bool tryUp(const String &ssid, const char *pass) {
  Serial.printf("[UP] trying '%s'", ssid.c_str());
  WiFi.disconnect();
  delay(100);
  WiFi.begin(ssid.c_str(), pass);
  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 8000) {
    handleSerial();      // stay reachable during the wait
    delay(250);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    upHost = WiFi.gatewayIP().toString();
    Serial.printf("\n[UP] joined '%s' — our IP %s, parent %s\n",
                  ssid.c_str(), WiFi.localIP().toString().c_str(), upHost.c_str());
    return true;
  }
  Serial.printf("\n[UP] '%s' did not connect\n", ssid.c_str());
  WiFi.disconnect();
  return false;
}

// Walk DOWN the chain: GW5 prefers GW4, then GW3 … then the master.
//
// Only ever uplinking to a LOWER-numbered gateway is what makes the topology
// loop-free by construction — GW3 can never select GW4, so no cycle can form
// and every gateway has a path to the master. It also degrades gracefully: if
// GW4 is dead, GW5 simply attaches further up the chain instead of stranding.
static bool connectUpstream() {
  for (int attempt = 1; attempt <= 2; attempt++) {
    for (int parent = gwId - 1; parent >= 1; parent--) {
      if (tryUp(String(GW_SSID_PREFIX) + parent, GW_PASS)) return true;
    }
    if (tryUp(MASTER_SSID, MASTER_PASS)) return true;   // GW1's normal parent
    Serial.printf("[UP] attempt %d/2 failed\n", attempt);
  }
  return false;
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);

  loadGwId();   // decides our SSID, so must run before softAP() below

  // ── Bring up STA first so the radio locks to the parent's channel ──
  // In AP+STA mode the softAP must share the STA channel; connecting the
  // station first lets the softAP inherit it automatically.
  WiFi.mode(WIFI_AP_STA);
  if (!connectUpstream()) {
    // Keep the console alive before rebooting, so a gateway that cannot reach
    // any parent can still be renumbered (setgw) instead of looping unreachable.
    Serial.println("\n[UP] no parent found — restarting in 5s ('setgw N' to renumber)");
    unsigned long t1 = millis();
    while (millis() - t1 < 5000) { handleSerial(); delay(10); }
    ESP.restart();
  }
  int chan = WiFi.channel();
  Serial.printf("[UP] STA IP %s, parent %s, channel %d\n",
                WiFi.localIP().toString().c_str(), upHost.c_str(), chan);

  // ── Bring up our downstream AP on the same channel as the uplink ──
  // GW_IP doubles as the gateway address handed to our clients, so a seat can
  // discover us with WiFi.gatewayIP() rather than a hard-coded address.
  WiFi.softAPConfig(GW_IP, GW_IP, GW_MASK);
  // max_connection 8 (default 4 evicts stations once a headful of seats joins)
  bool apStarted = WiFi.softAP(gwSsid.c_str(), GW_PASS, chan, 0, 8, false,
                               WIFI_AUTH_WPA2_PSK,
                               WIFI_CIPHER_TYPE_TKIP_CCMP);
  Serial.printf("[DOWN] WPA2 TKIP+CCMP start: %s\n",
                apStarted ? "OK" : "FAILED");
  Serial.printf("[DOWN] AP '%s' up at %s (channel %d, max 8 clients)\n",
                gwSsid.c_str(), WiFi.softAPIP().toString().c_str(), chan);

  // ── Start the two WebSocket endpoints ──
  wsDown.begin();
  wsDown.onEvent(onDownEvent);
  wsDown.enableHeartbeat(3000, 2000, 2);   // drop dead seats, free their slots

  // Relay upstream to whichever parent we joined — master or another gateway.
  wsUp.begin(upHost.c_str(), MASTER_PORT, MASTER_PATH);
  wsUp.onEvent(onUpEvent);
  wsUp.setReconnectInterval(3000);         // auto-retry the uplink every 3s
  wsUp.enableHeartbeat(3000, 2000, 2);     // detect a dead uplink and reconnect

  Serial.println("[Gateway] relay ready");
}

void loop() {
  wsDown.loop();
  wsUp.loop();

  handleSerial();   // laptop console — type 'help' for the command list

  // If the uplink WiFi drops entirely, the master (and its channel) may have
  // moved — restart to re-lock cleanly rather than run a dead relay.
  static unsigned long wifiLostMs = 0;
  if (WiFi.status() != WL_CONNECTED) {
    if (wifiLostMs == 0) wifiLostMs = millis();
    if (millis() - wifiLostMs > 15000) {
      Serial.println("[UP] WiFi lost 15s — restarting");
      delay(300);
      ESP.restart();
    }
  } else {
    wifiLostMs = 0;
  }

  // LED: solid when the uplink WS is live, blink while it's down
  if (upstreamConnected) {
    digitalWrite(LED_PIN, HIGH);
  } else {
    digitalWrite(LED_PIN, (millis() / 250) % 2);
  }
}
