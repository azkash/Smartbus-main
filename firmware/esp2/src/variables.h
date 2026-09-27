#include <Arduino.h>
// #include "image.h"
// #include "logo.h"
// #include "blokOpsi.h"
#include <WiFi.h>
// #include <WebServer.h>   // -- replaced by WebSocket server --
#include <WebSocketsServer.h>
#include <HTTPClient.h>
#include <FastLED.h>
#include <Preferences.h>   // NVS persistence for LED settings
#include <ArduinoJson.h>   // JSON serialization — Library oleh Benoit Blanchon
#include <ESPmDNS.h>       // mDNS — reachable as bus-led.local (bundled with core)
// #include <esp_now.h>  // replaced by MQTT
// #include "lwip/lwip_napt.h"  // NAT removed — ip_napt_enable not in current framework build

Preferences prefs;

// ─── Audio Configuration ────────────────────────────────────────────────
#define RXD2 16
#define TXD2 17
#define BUSY_PIN 15

// WebServer server(80);            // -- replaced by WebSocket server --
WebSocketsServer webSocket(81);     // WebSocket server — Android connects to ws://<AP-IP>:81

// ─── AP Configuration (seats connect here) ───────────────────────────
const char* ap_ssid     = "Seat-Monitoring-Bus";
const char* ap_password = "iot_BUS@5758";

// ─── Upstream internet WiFi (STA — gives the MASTER internet) ─────────
// Fill in your router / 4G-hotspot credentials. The master joins this for its
// own internet (NTP, cloud upload, etc.) while still running the AP above.
// NOTE: AP clients (seats) do NOT get internet through the master — that needs
// NAT, which isn't in this framework build. This is master-only internet.
// Leave STA_SSID empty ("") to skip upstream entirely (pure AP mode).
const char* STA_SSID    = "iot_bus";   // e.g. "iot_bus"
const char* STA_PASS    = "iot_BUS@5758";   // e.g. "iot_BUS@5758"

// ─── Inverter module (separate ESP32, HTTP :80, /data JSON) ──────────
// The master polls this over the shared AP and relays it to the headunit
// over the single WebSocket connection, so the tablet doesn't need a second
// network client. Resolved by mDNS; if that's ever unreliable on your
// hardware, set INVERTER_FALLBACK_IP once you know its DHCP-assigned address.
const char* INVERTER_HOSTNAME    = "bus-inverter";
const char* INVERTER_FALLBACK_IP = "";   // e.g. "192.168.4.3" — leave "" to rely on mDNS only

// ─── MQTT Topics ─── reverted: HTTP server instead of MQTT broker ─────
// #define MQTT_TOPIC_CMD        "bus/led/command"   // clients publish → LED control
// #define MQTT_TOPIC_SEAT_EVENT "bus/seat/event"   // sensor nodes publish → triggers audio/LED
// #define MQTT_TOPIC_SENSOR     "bus/sensor/data"  // broker forwards seat events to all subscribers
// #define MQTT_TOPIC_STATUS     "bus/status"       // broker publishes ack / status

// ─── Headunit IP ─────────────────────────────────────────────────────
static String headunitIP = "192.168.4.2";

// ─── WS2811 Configuration ────────────────────────────────────────────
#define LED_PIN     5
#define DIM_PIN     18
#define NUM_LEDS    66
#define NUM_DIMS    160
#define LED_TYPE    WS2811
#define COLOR_ORDER RBG
// #define COOLING  55
// #define SPARKING 120
// #define FRAMES_PER_SECOND 60
// #define GROUP_SIZE 5
// #define CAR_LENGTH 10
// #define FADE_RATE 1

// // Car Effect Parameters
// CRGB carColor;
// uint8_t carPosition = 0;

// // Snake Effect Parameters
// const int snakeLength = 10;
// const int gapBetweenSnakes = 1;
// const int moveDelay = 50;
// const int colorChangeInterval = 10000;
// const int fadeSize = 5;

// // Color List
// const CRGB colorPalette[] = {
//   CRGB::Red, CRGB::Green, CRGB::Blue,
//   CRGB::Purple, CRGB::Yellow, CRGB::Cyan
// };
// const int paletteCount = sizeof(colorPalette)/sizeof(colorPalette[0]);

// // Brightness Configuration
// const int stateMin = -1;
// const int stateMax = 4;
// int currentState = stateMin;
// int targetBrightness = 255;
// int currentBrightness = 255;
// unsigned long lastBrightnessUpdate = 0;
// const int brightnessUpdateInterval = 20;

CRGB leds[NUM_LEDS];
CRGB dimLeds[NUM_DIMS];

// // Controller
// CLEDController *animController;
// CLEDController *dimController;

// // TFT UI defines
// #define COLOR_PICKER_RADIUS 100
// #define CENTER_X (tft.width()/2)
// #define CENTER_Y (tft.height()/2)
// #define spasi 78
// #define PICKER_CENTER_X 78
// #define PICKER_CENTER_Y 110
// #define PICKER_RADIUS 60
// #define COLOR_BOX_X 115
// #define COLOR_BOX_Y 9
// #define COLOR_BOX_W 30
// #define COLOR_BOX_H 30

// // UI layout constants
// const int widthBlok1 = 90;
// const int heightBlok1 = 50;
// const int widthBlok = 65;
// const int heightBlok = 35;
// const int widthPlus = 15;
// const int heightPlus = 15;
// const int widthMinus = 15;
// const int heightMinus = 5;
// const int pixDimW = 50;
// const int pixDimH = 40;

// // const uint16_t* dimmerPersen[5] { level1, level2, level3, level4, level5 };
// // const int levelPosisi[5][4] {
// //   {67,255,20,9},{63,247,28,17},{59,239,36,25},{55,231,43,33},{52,223,50,41}
// // };

// // UI state
// int indexGambar, indexPlus, indexMinus, widthPersen, heightPersen;
// int currentState0 = -1;
// const int stateFull = 4;
// const int xDimmer = 5;
// const int yDimmer = 8;
// int stateDim = 0;
// const int fullDim = 100;
// bool status = false;
// int pilih = 0, lastPilih;
// int shadowX = 0, shadowY = 0, shadowW = 0, shadowH = 0;
// uint8_t R, G, B;

// ─── LED Effect ──────────────────────────────────────────────────────
enum LedEffect : uint8_t {
    EFF_RAINBOW_GLITTER,
    EFF_CONFETTI_PARTY,
    EFF_SINELON_WAVE,
    EFF_BPM_RHYTHM,
    EFF_JUGGLE_BOUNCE,
    EFF_FIRE_FLAME,
    EFF_AURORA_GLOW,
    EFF_BINARY_COUNTER,
    EFF_PALETTE_WAVE,
    EFF_DUAL_SCANNER,
    EFF_COLOR_BOUNCE,
    EFF_SNAKE,
    EFF_SOLID,
    EFF_BLINK,
    EFF_CHASE,
    EFF_FADE
};

DEFINE_GRADIENT_PALETTE( ocean_gp ) {
  0,   0,   0, 143,
  48,  0,   0, 255,
  96,  0, 255, 255,
  144, 42, 255,  45,
  192,255, 255,   0,
  240,255,   0,   0,
  255,143,   0,   0
};

// ─── Headunit tracking ───────────────────────────────────────────────
// Slot number of the registered headunit client (-1 = none connected).
// Seat node data is only processed once the headunit has identified itself.
static int headunitNum = -1;

// ─── WS2811 State ────────────────────────────────────────────────────
uint8_t   ledR = 0, ledG = 0, ledB = 0;
uint8_t   ledBrightness = 128;
LedEffect ledEffect = EFF_SOLID;
volatile bool ledOn = true;