#include "main.h"
// #include "esp_mac.h"  // was used by espnowInit — commented with ESP-NOW

// ─── Effect Task (Core 1) ────────────────────────────────────────────
volatile bool effectRunning = false;
static TaskHandle_t effectHandle = NULL;

void effectTask(void*) {
  int hue = 0, chase = 0, fade = 0;
  bool fadeUp = true;

  while (effectRunning) {
    // Seat-call announcement — drained from the queue filled in onWsEvent.
    // Voiced here (its own task) so the blocking playTrack()/delay() don't stall
    // webSocket.loop() in loop(). Each queued call is voiced in turn (no drops).
    CallEvent call;
    if (xQueueReceive(callQueue, &call, 0) == pdTRUE) {
      Serial.printf("[Seat] call from %s — voicing announcement\n", call.id);
      playTrack(11); delay(1500);
      playTrack(10); delay(1500);
    }

    if (!ledOn) {
      fill_solid(leds, NUM_LEDS, CRGB::Blue);
      FastLED.show();
      vTaskDelay(100 / portTICK_PERIOD_MS);
      continue;
    }

    FastLED.setBrightness(ledBrightness);

    switch (ledEffect) {
      case EFF_SOLID:
        fill_solid(leds, NUM_LEDS, CRGB(ledR, ledG, ledB));
        FastLED.show();
        vTaskDelay(50 / portTICK_PERIOD_MS);
        break;
      case EFF_RAINBOW_GLITTER:
        fill_rainbow(leds, NUM_LEDS, hue, 7);
        FastLED.show();
        hue = (hue + 3) % 256;
        vTaskDelay(20 / portTICK_PERIOD_MS);
        break;
      case EFF_CONFETTI_PARTY:
        fadeToBlackBy(leds, NUM_LEDS, 10);
        for (int i = 0; i < 3; i++) {
          int pos = random16(NUM_LEDS);
          leds[pos] += CHSV(random8(), 200, 255);
        }
        FastLED.show();
        vTaskDelay(50 / portTICK_PERIOD_MS);
        break;
      case EFF_SINELON_WAVE:
        fadeToBlackBy(leds, NUM_LEDS, 20);
        leds[beatsin16(13, 0, NUM_LEDS - 1)] += CHSV(hue++, 255, 192);
        FastLED.show();
        vTaskDelay(30 / portTICK_PERIOD_MS);
        break;
      case EFF_BPM_RHYTHM: {
        uint8_t beat = beatsin8(62, 64, 255);
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hue + (i * 2), 255, beat);
        hue++;
        FastLED.show();
        vTaskDelay(20 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_JUGGLE_BOUNCE:
        fadeToBlackBy(leds, NUM_LEDS, 20);
        for (int i = 0; i < 8; i++) leds[beatsin16(i + 7, 0, NUM_LEDS - 1)] |= CHSV(hue + i * 32, 200, 255);
        hue++;
        FastLED.show();
        vTaskDelay(20 / portTICK_PERIOD_MS);
        break;
      case EFF_FIRE_FLAME: {
        static byte heat[NUM_LEDS];
        for (int i = 0; i < NUM_LEDS; i++) heat[i] = qsub8(heat[i], random8(0, 30));
        for (int k = NUM_LEDS - 1; k >= 2; k--) heat[k] = (heat[k-1] + heat[k-2] + heat[k-2]) / 3;
        if (random8() < 40) { int y = random8(7); heat[y] = qadd8(heat[y], random8(160, 255)); }
        for (int j = 0; j < NUM_LEDS; j++) leds[j] = HeatColor(heat[j]);
        FastLED.show();
        vTaskDelay(33 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_AURORA_GLOW: {
        for (int i = 0; i < NUM_LEDS; i++) {
          uint8_t v = (beatsin8(5,0,255,0,i*10) + beatsin8(7,0,255,0,i*10+85) + beatsin8(4,0,255,0,i*10+170)) / 3;
          leds[i] = CHSV(hue + (i * 2), 200, v);
        }
        hue++;
        FastLED.show();
        vTaskDelay(30 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_BINARY_COUNTER: {
        static uint8_t counter = 0;
        for (int i = 0; i < 8; i++) {
          leds[i]    = (counter & (1 << i)) ? CRGB::Blue  : CRGB::Black;
          leds[i+8]  = (counter & (1 << i)) ? CRGB::Red   : CRGB::Black;
          if (i < 4) leds[i+16] = (counter & (1 << i)) ? CRGB::Green : CRGB::Black;
        }
        counter++;
        FastLED.show();
        vTaskDelay(500 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_PALETTE_WAVE: {
        static uint8_t startIndex = 0;
        CRGBPalette16 palette = ocean_gp;
        for (int i = 0; i < NUM_LEDS; i++) leds[i] = ColorFromPalette(palette, startIndex + i * 5, 255, LINEARBLEND);
        startIndex += 2;
        FastLED.show();
        vTaskDelay(30 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_DUAL_SCANNER: {
        static int pos1 = 0, pos2 = NUM_LEDS / 2, dir1 = 1, dir2 = -1;
        fadeToBlackBy(leds, NUM_LEDS, 30);
        leds[pos1] = CRGB::Red;
        leds[pos2] = CRGB::Blue;
        pos1 += dir1; pos2 += dir2;
        if (pos1 >= NUM_LEDS || pos1 < 0) dir1 *= -1;
        if (pos2 >= NUM_LEDS || pos2 < 0) dir2 *= -1;
        FastLED.show();
        vTaskDelay(50 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_COLOR_BOUNCE: {
        static int pos = 0, dir = 1;
        fill_solid(leds, NUM_LEDS, CRGB::Black);
        leds[pos] = CHSV(hue, 255, 255);
        for (int i = 1; i <= 3; i++) if (pos - i >= 0) leds[pos - i] = CHSV(hue, 255, 255 / (i * 2));
        pos += dir;
        if (pos >= NUM_LEDS - 1 || pos <= 0) { dir *= -1; hue += 60; }
        FastLED.show();
        vTaskDelay(50 / portTICK_PERIOD_MS);
        break;
      }
      case EFF_SNAKE: {
        static int counter = 0, colorIndex = 0;
        static unsigned long lastColorChange = millis();
        static const CRGB palette[] = {CRGB::Red, CRGB::Green, CRGB::Blue, CRGB::Purple, CRGB::Yellow, CRGB::Cyan};
        const int snakeLen = 10, gap = 1, fadeSz = 5;
        if (millis() - lastColorChange > 10000) { colorIndex = (colorIndex + 1) % 6; lastColorChange = millis(); }
        for (int i = NUM_LEDS - 1; i > 0; i--) leds[i] = leds[i - 1];
        int posInSnake = counter % (snakeLen + gap);
        if (posInSnake < snakeLen) {
          uint8_t brightness = 255;
          if (posInSnake < fadeSz) brightness = map(posInSnake, 0, fadeSz - 1, 80, 255);
          else if (posInSnake >= snakeLen - fadeSz) brightness = map(posInSnake, snakeLen - fadeSz, snakeLen - 1, 255, 80);
          leds[0] = palette[colorIndex];
          leds[0].fadeToBlackBy(255 - brightness);
        } else { leds[0] = CRGB::Black; }
        FastLED.show();
        vTaskDelay(50 / portTICK_PERIOD_MS);
        counter++;
        break;
      }
      case EFF_BLINK:
        fill_solid(leds, NUM_LEDS, CRGB(ledR, ledG, ledB));
        FastLED.show();
        vTaskDelay(500 / portTICK_PERIOD_MS);
        fill_solid(leds, NUM_LEDS, CRGB::Black);
        FastLED.show();
        vTaskDelay(500 / portTICK_PERIOD_MS);
        break;
      case EFF_CHASE:
        fill_solid(leds, NUM_LEDS, CRGB::Black);
        leds[chase % NUM_LEDS] = CRGB(ledR, ledG, ledB);
        if (chase >= 1) leds[(chase - 1) % NUM_LEDS].fadeToBlackBy(180);
        FastLED.show();
        chase = (chase + 1) % NUM_LEDS;
        vTaskDelay(40 / portTICK_PERIOD_MS);
        break;
      case EFF_FADE: {
        uint8_t bri = fadeUp ? fade : (255 - fade);
        fill_solid(leds, NUM_LEDS, CRGB(ledR, ledG, ledB));
        FastLED.setBrightness(map(bri, 0, 255, 0, ledBrightness));
        FastLED.show();
        fade += 3;
        if (fade >= 255) { fade = 0; fadeUp = !fadeUp; }
        vTaskDelay(15 / portTICK_PERIOD_MS);
        break;
      }
    }
  }
  effectHandle = NULL;
  vTaskDelete(NULL);
}

// void startEffectTask() {
//   if (effectHandle) {
//     effectRunning = false;
//     while (effectHandle) vTaskDelay(10 / portTICK_PERIOD_MS);
//   }
//   effectRunning = true;
//   xTaskCreate(effectTask, "ledEffect", 2048, NULL, 1, &effectHandle);
// }

// ─── ESP-NOW receiver (Core 0) — replaced by MQTT ────────────────────
// typedef struct {
//   char id[13];
//   int  sensorState;
//   bool seatOccupied;
// } espnow_payload_t;
//
// static volatile bool espnow_received      = false;
// static volatile bool espnow_seat_occupied = false;
// static volatile bool espnow_button_state  = false;
// static char          espnow_id[13]        = {0};
//
// static QueueHandle_t espNowQueue;
// static QueueHandle_t httpQueue;
//
// void espNowTask(void*) {
//   espnow_payload_t msg;
//   while (true) {
//     if (xQueueReceive(espNowQueue, &msg, portMAX_DELAY)) {
//       Serial.printf("[ESP-NOW] id: %s sensorState: %d  occupied: %d\n", msg.id, msg.sensorState, msg.seatOccupied);
//       digitalWrite(LED_BUILTIN, msg.sensorState ? HIGH : LOW);
//       xQueueSend(httpQueue, &msg, 0);
//     }
//   }
// }
//
// void httpTask(void*) {
//   espnow_payload_t msg;
//   while (true) {
//     if (xQueueReceive(httpQueue, &msg, portMAX_DELAY) && msg.sensorState != 0) {
//       sendToHeadunit(msg.sensorState, 0, msg.seatOccupied);
//     }
//   }
// }
//
// static void onDataRecv(const esp_now_recv_info* recv_info, const uint8_t* data, int len) {
//   if (len == sizeof(espnow_payload_t)) {
//     const espnow_payload_t* p = (const espnow_payload_t*)data;
//     espnow_seat_occupied = p->seatOccupied;
//     espnow_button_state = p->sensorState;
//     memcpy((void*)espnow_id, p->id, sizeof(espnow_id));
//     espnow_received = true;
//   }
// }
//
// static void espnowInit() {
//   if (esp_now_init() != ESP_OK) { Serial.println("ESP-NOW init failed"); return; }
//   esp_now_register_recv_cb(onDataRecv);
//   Serial.println("ESP-NOW receiver ready");
//   uint8_t mac[6];
//   esp_read_mac(mac, ESP_MAC_WIFI_STA);
//   Serial.printf("MAC: %02X:%02X:%02X:%02X:%02X:%02X\n", mac[0],mac[1],mac[2],mac[3],mac[4],mac[5]);
// }

static void actInit() {
  pinMode(BUSY_PIN, INPUT);
  playbackVolume(29);

  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.addLeds<LED_TYPE, DIM_PIN, COLOR_ORDER>(dimLeds, NUM_DIMS);
  FastLED.setBrightness(ledBrightness);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
  if (effectHandle) {
    effectRunning = false;
    while (effectHandle) vTaskDelay(10 / portTICK_PERIOD_MS);
  }
  effectRunning = true;
  xTaskCreate(
    effectTask,
    "ledEffect",
    4096,
    NULL,
    1,
    &effectHandle
  );
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, RXD2, TXD2);
  pinMode(LED_BUILTIN, OUTPUT);
  Serial.println("Master Board Firmware: " __DATE__ " " __TIME__);

  callQueue = xQueueCreate(16, sizeof(CallEvent));  // seat-call announcements
  loadSettings();       // restore LED on/brightness/effect/rgb from NVS (before actInit)

  wifiInit();           // WiFiManager STA + our AP + NAT
  // mqttBrokerInit();  // -- reverted: was local MQTT broker on port 1883 --
  // espnowInit();      // replaced by MQTT
  
  actInit();

  // espNowQueue = xQueueCreate(30, sizeof(espnow_payload_t));
  // xTaskCreatePinnedToCore(espNowTask, "espNowTask", 4096, NULL, 2, NULL, 1);
  // xTaskCreatePinnedToCore(httpTask,   "httpTask",   8192, NULL, 1, NULL, 0);

  // ─── HTTP server ─── replaced by WebSocket server ────────────────────
  // server.on("/command", HTTP_GET,  handleCommand);
  // server.on("/data",    HTTP_POST, handleData);
  // server.onNotFound([]() {
  //   server.send(404, "application/json", "{\"status\":\"error\",\"msg\":\"not found\"}");
  // });
  // server.begin();

  // ─── WebSocket server — ESP32 is the server; Android app is the client ─
  webSocket.begin();
  webSocket.onEvent(onWsEvent);
  // Ping every client every 3s; drop it after 2 missed pongs (~10s). This frees
  // the WS slot of a seat that vanished (out of range / powered off) so it
  // doesn't hold one of the limited client slots, and lets its OFFLINE fire.
  webSocket.enableHeartbeat(3000, 2000, 2);
  Serial.printf("[WS] WebSocket server ready on %s:81\n", WiFi.softAPIP().toString().c_str());

  // ─── Inverter relay — poll bus-inverter.local on its own task ────────
  inverterMutex = xSemaphoreCreateMutex();
  xTaskCreate(inverterPollTask, "InvPoll", 4096, NULL, 1, NULL);
}

// ─── Loop (Core 1) ───────────────────────────────────────────────────
void loop() {
  webSocket.loop();  // serve all connected WebSocket clients

  static unsigned long lastBroadcast = 0;
  unsigned long now = millis();

  for (int i = 0; i < MAX_SEATS; i++) {
    if (!seats[i].used) continue;

    // Log OFFLINE when a seat stops reporting for SEAT_OFFLINE_MS.
    if (seats[i].online && (now - seats[i].lastSeen) >= SEAT_OFFLINE_MS) {
      seats[i].online = false;
      Serial.printf("[Seat] %s OFFLINE\n", seats[i].id);
    }

    // Auto-expire callPending after 30 s if headunit never sends clear_<id>.
    if (seats[i].callPending && !seats[i].calling && now - seats[i].callTime > 30000) {
      seats[i].callPending = false;
      Serial.printf("[Roster] call auto-expired for %s\n", seats[i].id);
    }
  }

  // Report upstream-WiFi state changes to the headunit (connect completes
  // asynchronously after a wifiConnect request; a drop can happen any time).
  static bool staWasUp = false;
  bool staUp = (WiFi.status() == WL_CONNECTED);
  if (staUp != staWasUp) {
    staWasUp = staUp;
    Serial.printf("[STA] %s\n", staUp
      ? ("connected — IP " + WiFi.localIP().toString()).c_str()
      : "disconnected");
    if (headunitNum >= 0) {
      String st = wifiStatusJson();
      webSocket.sendTXT((uint8_t)headunitNum, st);
    }
  }

  // Broadcast current roster every 1 s.
  if (now - lastBroadcast >= 1000) {
    lastBroadcast = now;
    String roster = rosterJson();
    webSocket.broadcastTXT(roster);

    // Inverter telemetry is headunit-only (seats don't need it) — push it to
    // the registered headunit on the same cadence as the roster.
    if (headunitNum >= 0) {
      String inv = inverterStatusJson();
      webSocket.sendTXT((uint8_t)headunitNum, inv);
    }
  }
}
