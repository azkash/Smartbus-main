#include <FastLED.h>

CRGB leds[NUM_LEDS];

#define LED_PIN     23
#define NUM_LEDS    11
#define BRIGHTNESS  100
#define LED_TYPE    WS2812
#define COLOR_ORDER GRB
#define COOLING  55
#define SPARKING 120
#define FRAMES_PER_SECOND 60

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
}


