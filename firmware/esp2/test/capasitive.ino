void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.addLeds<LED_TYPE, DIM_PIN, COLOR_ORDER>(dimLeds, NUM_LEDS_DIM);
  // Inisialisasi terpisah
  // animController = &FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  // dimController = &FastLED.addLeds<LED_TYPE, DIM_PIN, COLOR_ORDER>(dimLeds, NUM_LEDS_DIM);
  // FastLED.setBrightness(BRIGHTNESS);
  // Set brightness awal
  // animController->setLeds(leds, NUM_LEDS);
  // FastLED.setBrightness(255); // Full brightness untuk animasi
  // FastLED.show();

  // dimController->setLeds(dimLeds, NUM_LEDS_DIM);
  // FastLED.setBrightness(100); // 40% brightness default
  // FastLED.show();
  // Wire.setClock(400000);
  // tft.init();
  // if(!ts.begin(8)) {
  //   Serial.println("Unable to start the capacitive touchscreen.");
  // }
  // tft.setRotation(3);
  // tft.fillScreen(warnaBase);

  // tft.pushImage(90, 132, 300, 55,logo);
  // delay(2000);
  // tft.fillScreen(warnaBase);




  // baground.createSprite(480, 320);
  // tft.drawCentreString("Touch screen to test!", tft.width()/2, tft.height()/2, 2);
  // tft.pushImage(275, 9, 83, 16, LEDanimasi);
  // tft.pushImage(7, 193, 54, 16, dimmer);
  // tft.pushImage(0, 0, 156, 320, garis);
  // tft.pushImage(7, 9, 82, 16, pick);
  // opsi.createSprite(83, 16, TFT_BLACK);
  // opsi.pushImage(0, 0, 83, 16, LEDanimasi);
  // opsi.pushSprite(276, 21, TFT_BLACK);
  // state.setSwapBytes(true);
  // state.createSprite(54, 16);
  // state.pushImage(0, 0, 54, 16, dimmer);
  // state.pushSprite(7, 193, TFT_BLACK);
  // state.pushToSprite(&baground, 7, 193, TFT_BLACK);
  // tft.pushImage(0, 0, 156, 320, garis);
  
  // tft.pushImage(0, 0, 480, 320, full);
  // tft.pushImage(0, 0, 480, 320, dataBase);
  // tft.pushImage(0,0,480,320,base);
  // blokAnimasi();
  blokFull();
  // Gambar UI
  drawCircularColorPicker();
  drawColorBox();

  // tft.pushImage(172,55,90,50,blokPutih);  tft.pushImage(272,55,90,50,blokPutih);  tft.pushImage(372,55,90,50,blokPutih);
  // tft.pushImage(172,123,90,50,blokPutih); tft.pushImage(272,123,90,50,blokPutih); tft.pushImage(372,123,90,50,blokPutih);
  // tft.pushImage(172,190,90,50,blokPutih); tft.pushImage(272,190,90,50,blokPutih); tft.pushImage(372,190,90,50,blokPutih);
  // tft.pushImage(172,257,90,50,blokPutih); tft.pushImage(272,257,90,50,blokPutih); tft.pushImage(372,257,90,50,blokPutih);


  // stateDimmer.createSprite(80, 80);
  // stateDimmer.setTextColor(TFT_WHITE, warnaBase);
}

void loop() {
  // put your main code here, to run repeatedly:
  // tft.drawRoundRect(115, 9, 30, 30, 5, TFT_WHITE);
  // tft.pushImage(7, 193, 54, 16, dimmer);
  // tft.pushImage(72-1, 265, 12, 12, core);
  // tft.pushImage(116, 288, 15, 15, plus);
  // tft.pushImage(22, 298-3, 15, 5, minus);
  // drawCircularColorPicker(78, 110, 60);
  // touchScreen();
  // sprite();
  // blokAnimasi();
  // logic();
  // stateGambar();
  // drawColorPicker();
  logicAnimasi();
}

void touchScreen() {
  // if(ts.touched()) {
    // TS_Point p = ts.getPoint();
    // uint16_t touchX = map(p.y, 480, 0, 0, tft.width());
    // uint16_t touchY = map(p.x, 0, 320, 0, tft.height());
    // Serial.print("X Coordinate: "); Serial.print(p.x);
    // Serial.print("  ");
    // Serial.print("Y Coordinate: "); Serial.println(p.y);
    // Serial.print("X Coordinate: "); Serial.print(touchX);
    // Serial.print("  ");
    // Serial.print("Y Coordinate: "); Serial.println(touchY);
    // tft.fillCircle(touchX, touchY, 2, TFT_WHITE);
  // }
  // delay(10);
}

void blokAnimasi1() { 
  if(shadowX == 0 && shadowY == 0) {}
  else{//Hapus layar
    tft.fillRect(shadowX-2, shadowY-2, widthBlok+4, heightBlok+4, warnaBase);
  }
  // Fungsi opsi
  if(pilih > 0) {
    switch(pilih) {
      case 1: shadowX = 171; shadowY = 65; break;
      case 2: shadowX = 249; shadowY = 65; break;
      case 3: shadowX = 327; shadowY = 65; break;
      case 4: shadowX = 405; shadowY = 65; break;
      case 5: shadowX = 171; shadowY = 116; break;
      case 6: shadowX = 249; shadowY = 116; break;
      case 7: shadowX = 327; shadowY = 116; break;
      case 8: shadowX = 405; shadowY = 116; break;
      case 9: shadowX = 171; shadowY = 167; break;
      case 10: shadowX = 249; shadowY = 167; break;
      case 11: shadowX = 327; shadowY = 167; break;
      case 12: shadowX = 405; shadowY = 167; break;
      case 13: shadowX = 171; shadowY = 218; break;
      case 14: shadowX = 249; shadowY = 218; break;
      case 15: shadowX = 327; shadowY = 218; break;
      case 16: shadowX = 405; shadowY = 218; break;
      case 17: shadowX = 171; shadowY = 269; break;
      case 18: shadowX = 249; shadowY = 269; break;
      case 19: shadowX = 327; shadowY = 269; break;
      case 20: shadowX = 405; shadowY = 269; break;
    }
    shadowAnimasi(shadowX-2, shadowY-2, widthBlok+4, heightBlok+4, 10, tft.color565(0, 255, 0));
  }
  opsi.createSprite(widthBlok, heightBlok, TFT_BLACK);
  opsi.fillSprite(warnaBase);

  opsi.pushImage(0, 0, widthBlok, heightBlok, blok);
  opsi.pushSprite(171, 65, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok2);
  opsi.pushSprite(249, 65, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok3);
  opsi.pushSprite(327, 65, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok4);
  opsi.pushSprite(405, 65, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok5);
  opsi.pushSprite(171, 116, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok6);
  opsi.pushSprite(249, 116, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok7);
  opsi.pushSprite(327, 116, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok8);
  opsi.pushSprite(405, 116, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok9);
  opsi.pushSprite(171, 167, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok10);
  opsi.pushSprite(249, 167, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok11);
  opsi.pushSprite(327, 167, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok12);
  opsi.pushSprite(405, 167, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok13);
  opsi.pushSprite(171, 218, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok14);
  opsi.pushSprite(249, 218, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok15);
  opsi.pushSprite(327, 218, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok16);
  opsi.pushSprite(405, 218, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok17);
  opsi.pushSprite(171, 269, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok18);
  opsi.pushSprite(249, 269, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok19);
  opsi.pushSprite(327, 269, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok, heightBlok, blok20);
  opsi.pushSprite(405, 269, TFT_BLACK);

  opsi.deleteSprite();
}
void blokFullSprite() {
  opsi.createSprite(widthBlok1, heightBlok1, TFT_BLACK);
  opsi.fillSprite(warnaBase);

  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR1);
  opsi.pushSprite(172, 55, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR2);
  opsi.pushSprite(272, 55, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR3);
  opsi.pushSprite(372, 55, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR4);
  opsi.pushSprite(172, 123, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR5);
  opsi.pushSprite(272, 123, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR6);
  opsi.pushSprite(372, 123, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR7);
  opsi.pushSprite(172, 190, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR8);
  opsi.pushSprite(272, 190, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR9);
  opsi.pushSprite(372, 190, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR10);
  opsi.pushSprite(172, 257, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR11);
  opsi.pushSprite(272, 257, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR12);
  opsi.pushSprite(372, 257, TFT_BLACK);

  opsi.deleteSprite();
}
void blokFull() {
  tft.pushImage(172, 55, widthBlok1, heightBlok1, blokR1);
  tft.pushImage(272, 55, widthBlok1, heightBlok1, blokR2);
  tft.pushImage(372, 55, widthBlok1, heightBlok1, blokR3);
  tft.pushImage(172, 123, widthBlok1, heightBlok1, blokR4);
  tft.pushImage(272, 123, widthBlok1, heightBlok1, blokR5);
  tft.pushImage(372, 123, widthBlok1, heightBlok1, blokR6);
  tft.pushImage(172, 190, widthBlok1, heightBlok1, blokR7);
  tft.pushImage(272, 190, widthBlok1, heightBlok1, blokR8);
  tft.pushImage(372, 190, widthBlok1, heightBlok1, blokR9);
  tft.pushImage(172, 257, widthBlok1, heightBlok1, blokR10);
  tft.pushImage(272, 257, widthBlok1, heightBlok1, blokR11);
  tft.pushImage(372, 257, widthBlok1, heightBlok1, blokR12);
}
void last() {
  if(lastPilih != pilih) {
    opsi.createSprite(widthBlok1, heightBlok1, TFT_BLACK);
    opsi.fillSprite(warnaBase);
    switch(lastPilih) {
      case 1: 
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR1);
        opsi.pushSprite(172, 55, TFT_BLACK);
        break;
      case 2: 
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR2);
        opsi.pushSprite(272, 55, TFT_BLACK);
        break;
      case 3:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR3);
        opsi.pushSprite(372, 55, TFT_BLACK);
        break;
      case 4:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR4);
        opsi.pushSprite(172, 123, TFT_BLACK);
        break;
      case 5:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR5);
        opsi.pushSprite(272, 123, TFT_BLACK);
        break;
      case 6:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR6);
        opsi.pushSprite(372, 123, TFT_BLACK);
        break;
      case 7:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR7);
        opsi.pushSprite(172, 190, TFT_BLACK);
        break;
      case 8:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR8);
        opsi.pushSprite(272, 190, TFT_BLACK);
        break;
      case 9:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR9);
        opsi.pushSprite(372, 190, TFT_BLACK);
        break;
      case 10:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR10);
        opsi.pushSprite(172, 257, TFT_BLACK);
        break;
      case 11:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR11);
        opsi.pushSprite(272, 257, TFT_BLACK);
        break;
      case 12:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR12);
        opsi.pushSprite(372, 257, TFT_BLACK);
        break;
    }
    opsi.deleteSprite();
  }
}
void blokAnimasi() { 
  // static int lastPilih = 0;
  // static int lastShadowX = 0, lastShadowY = 0;
  if(shadowX == 0 && shadowY == 0) {}
  else{//Hapus layar
    tft.fillRect(shadowX, shadowY, widthBlok1, heightBlok1, warnaBase);
  }  
  if(lastPilih != pilih && pilih > 0) {
    opsi.createSprite(widthBlok1, heightBlok1, TFT_BLACK);
    opsi.fillSprite(warnaBase);
    switch(lastPilih) {
      case 1: 
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR1);
        opsi.pushSprite(172, 55, TFT_BLACK);
        break;
      case 2: 
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR2);
        opsi.pushSprite(272, 55, TFT_BLACK);
        break;
      case 3:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR3);
        opsi.pushSprite(372, 55, TFT_BLACK);
        break;
      case 4:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR4);
        opsi.pushSprite(172, 123, TFT_BLACK);
        break;
      case 5:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR5);
        opsi.pushSprite(272, 123, TFT_BLACK);
        break;
      case 6:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR6);
        opsi.pushSprite(372, 123, TFT_BLACK);
        break;
      case 7:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR7);
        opsi.pushSprite(172, 190, TFT_BLACK);
        break;
      case 8:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR8);
        opsi.pushSprite(272, 190, TFT_BLACK);
        break;
      case 9:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR9);
        opsi.pushSprite(372, 190, TFT_BLACK);
        break;
      case 10:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR10);
        opsi.pushSprite(172, 257, TFT_BLACK);
        break;
      case 11:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR11);
        opsi.pushSprite(272, 257, TFT_BLACK);
        break;
      case 12:
        opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR12);
        opsi.pushSprite(372, 257, TFT_BLACK);
        break;
    }
    opsi.deleteSprite();
  }
  // Fungsi opsi
  if(pilih > 0) {
    switch(pilih) {
      case 1: shadowX = 172; shadowY = 55; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 2: shadowX = 272; shadowY = 55; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 3: shadowX = 372; shadowY = 55; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 4: shadowX = 172; shadowY = 123; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 5: shadowX = 272; shadowY = 123; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 6: shadowX = 372; shadowY = 123; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 7: shadowX = 172; shadowY = 190; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 8: shadowX = 272; shadowY = 190; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 9: shadowX = 372; shadowY = 190; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 10: shadowX = 172; shadowY = 257; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 11: shadowX = 272; shadowY = 257; shadowW = widthBlok1; shadowH = heightBlok1; break;
      case 12: shadowX = 372; shadowY = 257; shadowW = widthBlok1; shadowH = heightBlok1; break;
    }
    shadowAnimasi(shadowX, shadowY, shadowW, shadowH, 10, tft.color565(0, 255, 0));
    lastPilih = pilih;
  }
  // opsi.createSprite(widthBlok1, heightBlok1, TFT_BLACK);
  // opsi.fillSprite(warnaBase);

  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR1);
  // opsi.pushSprite(172, 55, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR2);
  // opsi.pushSprite(272, 55, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR3);
  // opsi.pushSprite(372, 55, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR4);
  // opsi.pushSprite(172, 123, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR5);
  // opsi.pushSprite(272, 123, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR6);
  // opsi.pushSprite(372, 123, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR7);
  // opsi.pushSprite(172, 190, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR8);
  // opsi.pushSprite(272, 190, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR9);
  // opsi.pushSprite(372, 190, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR10);
  // opsi.pushSprite(172, 257, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR11);
  // opsi.pushSprite(272, 257, TFT_BLACK);
  // opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR12);
  // opsi.pushSprite(372, 257, TFT_BLACK);

  // opsi.deleteSprite();
}
void drawSingleBlock(int x, int y, const uint16_t* block) {
  opsi.createSprite(widthBlok1, heightBlok1, TFT_BLACK);
  opsi.fillSprite(warnaBase);

  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR1);
  opsi.pushSprite(172, 55, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR2);
  opsi.pushSprite(272, 55, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR3);
  opsi.pushSprite(372, 55, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR4);
  opsi.pushSprite(172, 123, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR5);
  opsi.pushSprite(272, 123, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR6);
  opsi.pushSprite(372, 123, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR7);
  opsi.pushSprite(172, 190, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR8);
  opsi.pushSprite(272, 190, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR9);
  opsi.pushSprite(372, 190, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR10);
  opsi.pushSprite(172, 257, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR11);
  opsi.pushSprite(272, 257, TFT_BLACK);
  opsi.pushImage(0, 0, widthBlok1, heightBlok1, blokR12);
  opsi.pushSprite(372, 257, TFT_BLACK);

  opsi.deleteSprite();
}

void logic() {
  if(ts.touched()) {
    TS_Point p = ts.getPoint();
    uint16_t touchX = map(p.y, 480, 0, 0, tft.width());
    uint16_t touchY = map(p.x, 0, 320, 0, tft.height());

    bool zona1  = (touchX >= 171) && (touchX <= 171+widthBlok) && (touchY >= 65)  && (touchY <= 65+heightBlok);
    bool zona2  = (touchX >= 249) && (touchX <= 249+widthBlok) && (touchY >= 65)  && (touchY <= 65+heightBlok);
    bool zona3  = (touchX >= 327) && (touchX <= 327+widthBlok) && (touchY >= 65)  && (touchY <= 65+heightBlok);
    bool zona4  = (touchX >= 405) && (touchX <= 405+widthBlok) && (touchY >= 65)  && (touchY <= 65+heightBlok);
    bool zona5  = (touchX >= 171) && (touchX <= 171+widthBlok) && (touchY >= 116) && (touchY <= 116+heightBlok);
    bool zona6  = (touchX >= 249) && (touchX <= 249+widthBlok) && (touchY >= 116) && (touchY <= 116+heightBlok);
    bool zona7  = (touchX >= 327) && (touchX <= 327+widthBlok) && (touchY >= 116) && (touchY <= 116+heightBlok);
    bool zona8  = (touchX >= 405) && (touchX <= 405+widthBlok) && (touchY >= 116) && (touchY <= 116+heightBlok);
    bool zona9  = (touchX >= 171) && (touchX <= 171+widthBlok) && (touchY >= 167) && (touchY <= 167+heightBlok);
    bool zona10 = (touchX >= 249) && (touchX <= 249+widthBlok) && (touchY >= 167) && (touchY <= 167+heightBlok);
    bool zona11 = (touchX >= 327) && (touchX <= 327+widthBlok) && (touchY >= 167) && (touchY <= 167+heightBlok);
    bool zona12 = (touchX >= 405) && (touchX <= 405+widthBlok) && (touchY >= 167) && (touchY <= 167+heightBlok);
    bool zona13 = (touchX >= 171) && (touchX <= 171+widthBlok) && (touchY >= 218) && (touchY <= 218+heightBlok);
    bool zona14 = (touchX >= 249) && (touchX <= 249+widthBlok) && (touchY >= 218) && (touchY <= 218+heightBlok);
    bool zona15 = (touchX >= 327) && (touchX <= 327+widthBlok) && (touchY >= 218) && (touchY <= 218+heightBlok);
    bool zona16 = (touchX >= 405) && (touchX <= 405+widthBlok) && (touchY >= 218) && (touchY <= 218+heightBlok);
    bool zona17 = (touchX >= 171) && (touchX <= 171+widthBlok) && (touchY >= 269) && (touchY <= 269+heightBlok);
    bool zona18 = (touchX >= 249) && (touchX <= 249+widthBlok) && (touchY >= 269) && (touchY <= 269+heightBlok);
    bool zona19 = (touchX >= 327) && (touchX <= 327+widthBlok) && (touchY >= 269) && (touchY <= 269+heightBlok);
    bool zona20 = (touchX >= 405) && (touchX <= 405+widthBlok) && (touchY >= 269) && (touchY <= 269+heightBlok);

    bool dimmerPlus = (touchX >= 106) && (touchX <= 106+pixDimW) && (touchY >= 280) && (touchY <= 280+pixDimH);
    bool dimmerMinus = (touchX >= 0) && (touchX <= 0+pixDimW) && (touchY >= 280) && (touchY <= 280+pixDimH);

    uint16_t selectedColor = getSelectedColor(touchX, touchY);

    
    if(zona1) {
      while(1) {
        // status = true;
        // blokAnimasi(171, 65, widthBlok, heightBlok, 6, tft.color565(26, 255, 229));
        // if(ts.touched()) {
        //   TS_Point p = ts.getPoint();
        //   uint16_t touchX = map(p.y, 480, 0, 0, tft.width());
        //   uint16_t touchY = map(p.x, 0, 320, 0, tft.height());
        //   bool zona1  = (touchX >= 171) && (touchX <= 171+widthBlok) && (touchY >= 65)  && (touchY <= 65+heightBlok);
        //   bool zona2  = (touchX >= 249) && (touchX <= 249+widthBlok) && (touchY >= 65)  && (touchY <= 65+heightBlok);
        //   if(zona1 && status){
        //     // status = false;
        //     tft.fillRect(171, 65, widthBlok, heightBlok, TFT_BLACK);
        //     break;
        //   }
        // }
      }
    }
    if(zona4) {
      ESP.restart();
    }
    if(dimmerPlus) {
      changeState(1);
    }
    if(dimmerMinus) {
      changeState(-1);
    }
  }
  tft.pushImage(171, 65, widthBlok, heightBlok, blok);   //1
  delay(1);
}

void printState() {
  stateDimmer.fillSprite(warnaBase);
  stateDimmer.drawString(String(stateDim), 0, 0, 6);
}

void changeState(int stateLevel) {
  clearArea();
  currentState0 += stateLevel;
  if(currentState0 > 4) {
    currentState0 = stateFull;
  }
  if(currentState0 < 0) {
    currentState0 = -1;
  }
  // Update state dengan boundary check
  currentState = constrain(currentState + stateLevel, stateMin, stateMax);
  
  // Set target brightness berdasarkan state
  if(currentState == stateMin) {
    targetBrightness = 0; // OFF
  } else {
    targetBrightness = map(currentState, 0, stateMax, 51, 255); // 20-100%
  }
  // showGambar();
  stateGambar();
  Serial.println("Data = " + String(currentState));
  // Pertahankan warna biru saat brightness berubah
  if(currentState != stateMin) {
    // for(int i=0; i<NUM_LEDS; i++){ 
    //   dimLeds[i] = CRGB::Blue;
    //   FastLED.show();
    //   // delay(100);
    // }
    // dimController->setLeds(dimLeds, NUM_LEDS_DIM);
    // fill_solid(dimLeds, NUM_LEDS, CRGB::White); // Warna biru solid
    FastLED.show();
  }
  // if(currentState0 == -1) {
  //   fill_solid(dimLeds, NUM_LEDS, CRGB::Black);
  //   FastLED.show();
  // }
  
  // delay(100);
}
void updateBrightness() {
  // Smooth transition ke target brightness
  if(millis() - lastBrightnessUpdate >= brightnessUpdateInterval) {
    if(currentBrightness != targetBrightness) {
      currentBrightness += (currentBrightness < targetBrightness) ? 1 : -1;
      // dimController->setLeds(dimLeds, NUM_LEDS_DIM);
      for (int i = 0; i < NUM_LEDS; i++) {
        dimLeds[i] = CRGB::White;  // Set color to white
        dimLeds[i].fadeToBlackBy(255 - currentBrightness); 
      }
      // FastLED.setBrightness(currentBrightness);
      FastLED.show();
    }
    lastBrightnessUpdate = millis();
  }
}

void clearArea() {
  tft.fillRect(levelPosisi[currentState][0], levelPosisi[currentState][1], levelPosisi[currentState][2], levelPosisi[currentState][3], TFT_BLACK);
  // state.fillSprite(TFT_BLACK);
  // state.createSprite(
  // levelPosisi[currentState][2],
  // levelPosisi[currentState][3]
  // );
  // state.pushSprite(
  // levelPosisi[currentState][0],
  // levelPosisi[currentState][1],
  // TFT_BLACK
  // );
}

void showGambar() {
  state.createSprite(
    levelPosisi[currentState][2],
    levelPosisi[currentState][3]
  );
  state.pushImage(
    0,
    0,
    levelPosisi[currentState][2],
    levelPosisi[currentState][3],
    dimmerPersen[currentState]
  );
  state.pushSprite(
    levelPosisi[currentState][0],
    levelPosisi[currentState][1], 
    TFT_BLACK
  );
}

void stateGambar() {
  tft.pushImage(levelPosisi[currentState][0], levelPosisi[currentState][1], levelPosisi[currentState][2], levelPosisi[currentState][3], dimmerPersen[currentState]);
}

// const int pixel = 100;
// int x = 24, y = 56;
void drawColorPicker() {
  // Gambar gradien RGB
  for (int y = 56; y < 156; y++) {
    for (int x = 24; x < 124; x++) {
      int r = map(x, 0, 123, 0, 255);
      int g = map(y, 0, 155, 0, 255);
      int b = 120; // Nilai biru tetap (bisa diubah)
      // tft.drawPixel(x, y, tft.color565(r, g, b));
      tft.fillCircle(x, y, 50, tft.color565(r, g, b));
    }
  }
}

// --->>> Fungi pick color <<<---
// Konversi HSV ke RGB565
uint16_t hsvToRgb(uint16_t h, uint8_t s, uint8_t v) {
    float r, g, b;
    float hue = h / 60.0f;
    float sat = s / 255.0f;
    float val = v / 255.0f;
    
    int i = floor(hue);
    float f = hue - i;
    float p = val * (1 - sat);
    float q = val * (1 - sat * f);
    float t = val * (1 - sat * (1 - f));
    
    switch (i) {
        case 0: r = val; g = t; b = p; break;
        case 1: r = q; g = val; b = p; break;
        case 2: r = p; g = val; b = t; break;
        case 3: r = p; g = q; b = val; break;
        case 4: r = t; g = p; b = val; break;
        default: r = val; g = p; b = q; break;
    }
    
    return tft.color565(r * 255, g * 255, b * 255);
}
// Gambar color picker
void drawCircularColorPicker() {
    tft.startWrite(); // Optimasi untuk ILI9488
    
    for (int y = -PICKER_RADIUS; y <= PICKER_RADIUS; y++) {
        for (int x = -PICKER_RADIUS; x <= PICKER_RADIUS; x++) {
            float distance = sqrt(x*x + y*y);
            if (distance <= PICKER_RADIUS) {
                float angle = atan2(y, x) * 180.0f / PI;
                if (angle < 0) angle += 360;
                
                uint8_t saturation = map(distance, 0, PICKER_RADIUS, 0, 255);
                uint16_t color = hsvToRgb(angle, saturation, 255);
                
                tft.drawPixel(PICKER_CENTER_X + x, PICKER_CENTER_Y + y, color);
            }
        }
    }
    
    tft.endWrite();
}
// Gambar kotak warna terpilih
void drawColorBox() {
    tft.drawRoundRect(COLOR_BOX_X, COLOR_BOX_Y, COLOR_BOX_W, COLOR_BOX_H, 5, TFT_WHITE);
    tft.fillRoundRect(COLOR_BOX_X+2, COLOR_BOX_Y+2, COLOR_BOX_W-4, COLOR_BOX_H-4, 3, selectedColor);
}
// Dapatkan warna di posisi tertentu
uint16_t getColorAtPosition(int x, int y) {
    int relX = x - PICKER_CENTER_X;
    int relY = y - PICKER_CENTER_Y;
    float distance = sqrt(relX*relX + relY*relY);
    
    if (distance > PICKER_RADIUS) return 0xFFFF; // Return putih jika di luar
    
    float angle = atan2(relY, relX) * 180.0f / PI;
    if (angle < 0) angle += 360;
    
    uint8_t saturation = map(distance, 0, PICKER_RADIUS, 0, 255);
    return hsvToRgb(angle, saturation, 255);
}
// --------------------------------------------------------------
uint16_t getSelectedColor(int touchX, int touchY) {
    int relX = touchX - CENTER_X;
    int relY = touchY - CENTER_Y;
    float distance = sqrt(relX*relX + relY*relY);
    
    if (distance > COLOR_PICKER_RADIUS) return 0xFFFF; // Putih jika di luar
    
    float angle = atan2(relY, relX) * 180.0f / PI;
    if (angle < 0) angle += 360;
    
    uint8_t saturation = map(distance, 0, COLOR_PICKER_RADIUS, 0, 255);
    return hsvToRgb(angle, saturation, 255);
}
void showSelectedColor(uint16_t color) {
  // Tampilkan warna yang dipilih
  tft.fillRect(10, 10, 50, 50, color);
  
  // Tampilkan nilai RGB
  uint8_t r = (color >> 11) << 3;
  uint8_t g = ((color >> 5) & 0x3F) << 2;
  uint8_t b = (color & 0x1F) << 3;
  
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setCursor(70, 20);
  tft.printf("R:%d G:%d B:%d", r, g, b);
}



void shadowAnimasi(int x, int y, int w, int h, int r, uint16_t color) {
  // Gambar bagian tengah utama
  tft.fillRect(x, y + r, w, h - 2 * r, color);
  
  // Gambar sisi kiri dan kanan
  tft.fillRect(x, y + r, r, h - 2 * r, color);
  tft.fillRect(x + w - r, y + r, r, h - 2 * r, color);
  
  // Gambar bagian atas (tanpa sudut kiri atas)
  tft.fillRect(x, y, w - r, r, color);
  
  // Gambar bagian bawah (tanpa sudut kanan bawah)
  tft.fillRect(x + r, y + h - r, w - r, r, color);
  
  // Gambar sudut kanan atas (90 derajat)
  tft.fillCircle(x+w-r-1, y+r, r, color);
  
  // Gambar sudut kiri bawah (90 derajat)
  tft.fillCircle(x+r, y+h-r-1, r, color);
}

void logicAnimasi() {
  static int pilihBaru = 0;
  static int stateLed = 0;
  static int kecerahan = 0;
  if(ts.touched()) {
    TS_Point p = ts.getPoint();
    uint16_t touchX = map(p.y, 480, 0, 0, tft.width());
    uint16_t touchY = map(p.x, 0, 320, 0, tft.height());

    bool zona1  = (touchX >= 172) && (touchX <= 172+widthBlok1) && (touchY >= 55)  && (touchY <= 55+heightBlok1);
    bool zona2  = (touchX >= 272) && (touchX <= 272+widthBlok1) && (touchY >= 55)  && (touchY <= 55+heightBlok1);
    bool zona3  = (touchX >= 372) && (touchX <= 327+widthBlok1) && (touchY >= 55)  && (touchY <= 55+heightBlok1);
    bool zona4  = (touchX >= 172) && (touchX <= 172+widthBlok1) && (touchY >= 123)  && (touchY <= 123+heightBlok1);
    bool zona5  = (touchX >= 272) && (touchX <= 272+widthBlok1) && (touchY >= 123) && (touchY <= 123+heightBlok1);
    bool zona6  = (touchX >= 372) && (touchX <= 372+widthBlok1) && (touchY >= 123) && (touchY <= 123+heightBlok1);
    bool zona7  = (touchX >= 172) && (touchX <= 172+widthBlok1) && (touchY >= 190) && (touchY <= 190+heightBlok1);
    bool zona8  = (touchX >= 272) && (touchX <= 272+widthBlok1) && (touchY >= 190) && (touchY <= 190+heightBlok1);
    bool zona9  = (touchX >= 372) && (touchX <= 372+widthBlok1) && (touchY >= 190) && (touchY <= 190+heightBlok1);
    bool zona10 = (touchX >= 172) && (touchX <= 172+widthBlok1) && (touchY >= 257) && (touchY <= 257+heightBlok1);
    bool zona11 = (touchX >= 272) && (touchX <= 272+widthBlok1) && (touchY >= 257) && (touchY <= 257+heightBlok1);
    bool zona12 = (touchX >= 372) && (touchX <= 372+widthBlok1) && (touchY >= 257) && (touchY <= 257+heightBlok1);
    bool dimmerPlus = (touchX >= 106) && (touchX <= 106+pixDimW) && (touchY >= 280) && (touchY <= 280+pixDimH);
    bool dimmerMinus = (touchX >= 0) && (touchX <= 0+pixDimW) && (touchY >= 280) && (touchY <= 280+pixDimH);
    bool picker = (touchX >= 115) && (touchX <= 115+30) && (touchY >= 9) && (touchY <= 9+30);

    bool off = (touchX >= 258) && (touchX <= 258+117) && (touchY >= 0) && (touchY <= 0+40);
    // Dapatkan warna di posisi touch
    uint16_t color = getColorAtPosition(touchX, touchY);
    if (color != 0xFFFF) { // Jika menyentuh dalam lingkaran
        selectedColor = color;
        drawColorBox(); // Update kotak warna
        
        // Tampilkan nilai RGB
        uint8_t r = (selectedColor >> 11) << 3;
        uint8_t g = ((selectedColor >> 5) & 0x3F) << 2;
        uint8_t b = (selectedColor & 0x1F) << 3;
        R = r; G = g; B = b;
        
        // tft.fillRect(10, 50, 200, 20, TFT_BLACK);
        // tft.setCursor(10, 50);
        // tft.printf("RGB: %d, %d, %d", r, g, b);
        
        // Serial.printf("Warna dipilih - R: %d, G: %d, B: %d\n", r, g, b);
        delay(100);
    }
    if(picker) {
      pilihBaru = 0;
      blokFull();
      selectedColor = color;
      // drawColorBox(); // Update kotak warna
      
      // Tampilkan nilai RGB
      // uint8_t r = (selectedColor >> 11) << 3;
      // uint8_t g = ((selectedColor >> 5) & 0x3F) << 2;
      // uint8_t b = (selectedColor & 0x1F) << 3;
      // tft.fillRect(10, 50, 200, 20, TFT_BLACK);
      // tft.setCursor(10, 50);
      // tft.printf("RGB: %d, %d, %d", R, G, B);
      stateLed = 13;
    }

    if(zona1) {
      pilihBaru = 1;
      stateLed = 1;
    }                                                                                                            
    if(zona2) {
      pilihBaru = 2;
      stateLed = 2;
    }
    if(zona3) {
      pilihBaru = 3;
      stateLed = 3;
    }
    if(zona4) {
      pilihBaru = 4;
      stateLed = 4;
    }
    if(zona5) {
      pilihBaru = 5;
      stateLed = 5;
    }
    if(zona6) {
      pilihBaru = 6;
      stateLed = 6;
    }
    if(zona7) {
      pilihBaru = 7;
      stateLed = 7;
    }
    if(zona8) {
      pilihBaru = 8;
      stateLed = 8;
    }
    if(zona9) {
      pilihBaru = 9;
      stateLed = 9;
    }
    if(zona10) {
      pilihBaru = 10;
      stateLed  = 10;
    }
    if(zona11) {
      pilihBaru = 11;
      stateLed = 11;
    }
    if(zona12) {
      pilihBaru = 12;
      stateLed = 12;
    }
    if(dimmerPlus) {
      changeState(1);
      delay(100);
    }
    if(dimmerMinus) {
      changeState(-1);
      delay(100);
    }
    if(off) {
      stateLed = 14;
      pilihBaru = 0;
      blokFull();
    }

    
    if(pilihBaru > 0) {
      pilih = pilihBaru;
      blokAnimasi();
    }
  }
  updateBrightness(); // Update brightness secara real-time
  switch(stateLed) {
    case 1:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      trisakti();
    break;
    case 2:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      rainbow();
    break;
    case 3:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      car();
    break;
    case 4:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      ular();
    break;
    case 5:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      gradasi();
    break;
    case 6:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      rainbowWithGlitter();
    break;
    case 7:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      auroraEffect();
    break;
    case 8:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      binaryCounter();
    break;
    case 9:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      paletteWave();
    break;
    case 10:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      dualScanner();
    break;
    case 11:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      colorBounce();
    break;
    case 12:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      colorSymphony();
    break;
    case 13:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      controlLed(R, G, B);
    break;
    case 14:
      // animController->setLeds(leds, NUM_LEDS);
      // FastLED.setBrightness(255); // Lock 100% brightness
      fill_solid(leds, NUM_LEDS, CRGB::Black);
      FastLED.show();
    break;
  }
}

