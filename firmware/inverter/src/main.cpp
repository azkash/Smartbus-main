#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Wire.h>
#include <PZEM004Tv30.h>
#include <Adafruit_INA219.h>

const char *ssid = "Inverter IOT (19)";
const char *password = "12345678";

const byte DNS_PORT = 53;
DNSServer dnsServer;
WebServer server(80);

#define PZEM_RX_PIN 16
#define PZEM_TX_PIN 17
PZEM004Tv30 pzem(Serial2, PZEM_RX_PIN, PZEM_TX_PIN);

Adafruit_INA219 ina; 
bool ina_connected = false; // Variabel penanda status INA219

float v_ac = 0.0, c_ac = 0.0, p_ac = 0.0, e_ac = 0.0, pf_ac = 0.0, freq_ac = 0.0;
float v_dc = 0.0;

unsigned long previousMillis = 0;
const long interval = 2000; 

void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">";
  html += "<title>Smart Energy Monitor</title>";
  html += "<style>";
  html += "html, body { height: 100vh; margin: 0; padding: 0; overflow: hidden; font-family: 'Segoe UI', Arial, sans-serif; background-color: #f0f2f5; }";
  html += ".container { display: flex; flex-direction: column; height: 100vh; box-sizing: border-box; padding: 10px; }";
  html += "h1 { text-align: center; color: #1a252f; font-size: 18px; margin: 5px 0; font-weight: 700; text-transform: uppercase; }";
  html += ".section-header { font-size: 12px; font-weight: 600; padding: 5px 10px; margin: 5px 0; border-radius: 4px; color: white; text-transform: uppercase; }";
  html += ".bg-ac { background-color: #2980b9; }";
  html += ".bg-dc { background-color: #d35400; }";
  html += ".grid-ac { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; flex: 3; }";
  html += ".grid-dc { display: grid; grid-template-columns: 1fr; flex: 1; min-height: 12%; }";
  html += ".card { background: white; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.05); border-left: 4px solid #2980b9; display: flex; flex-direction: column; justify-content: center; align-items: center; padding: 5px; box-sizing: border-box; }";
  html += ".card.dc-card { border-left-color: #d35400; }";
  html += ".card h3 { margin: 0 0 2px 0; color: #7f8c8d; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }";
  html += ".card .value { font-size: 24px; font-weight: 700; color: #2c3e50; line-height: 1.1; }";
  html += ".card .unit { font-size: 11px; color: #95a5a6; font-weight: 500; }";
  html += ".footer { text-align: center; margin-top: 5px; color: #95a5a6; font-size: 10px; }";
  html += "</style>";
  
  html += "<script>";
  html += "function updateData() {";
  html += "  fetch('/data').then(response => response.json()).then(data => {";
  html += "    document.getElementById('vac').innerText = data.vac;";
  html += "    document.getElementById('cac').innerText = data.cac;";
  html += "    document.getElementById('pac').innerText = data.pac;";
  html += "    document.getElementById('eac').innerText = data.eac;";
  html += "    document.getElementById('pfac').innerText = data.pfac;";
  html += "    document.getElementById('freqac').innerText = data.freqac;";
  html += "    document.getElementById('vdc').innerText = data.vdc;";
  html += "  }).catch(err => console.log(err));";
  html += "}";
  html += "setInterval(updateData, 2000);";
  html += "</script>";
  
  html += "</head><body>";
  html += "<div class=\"container\">";
  html += "<h1>Smart System Monitoring Inverter</h1>";
  html += "<div class=\"section-header bg-ac\">&#9889; AC Output</div>";
  html += "<div class=\"grid-ac\">";
  html += "  <div class=\"card\"><h3>Tegangan AC</h3><div class=\"value\" id=\"vac\">0.0</div><div class=\"unit\">Volt (V)</div></div>";
  html += "  <div class=\"card\"><h3>Arus AC</h3><div class=\"value\" id=\"cac\">0.000</div><div class=\"unit\">Ampere (A)</div></div>";
  html += "  <div class=\"card\"><h3>Daya AC</h3><div class=\"value\" id=\"pac\">0.0</div><div class=\"unit\">Watt (W)</div></div>";
  html += "  <div class=\"card\"><h3>Energy AC</h3><div class=\"value\" id=\"eac\">0.00</div><div class=\"unit\">kWh</div></div>";
  html += "  <div class=\"card\"><h3>Power Factor</h3><div class=\"value\" id=\"pfac\">0.00</div><div class=\"unit\">Cos &phi;</div></div>";
  html += "  <div class=\"card\"><h3>Frekuensi AC</h3><div class=\"value\" id=\"freqac\">0.0</div><div class=\"unit\">Hz</div></div>";
  html += "</div>";
  html += "<div class=\"section-header bg-dc\">&#128267; DC Input</div>";
  html += "<div class=\"grid-dc\">";
  html += "  <div class=\"card dc-card\"><h3>Tegangan DC</h3><div class=\"value\" id=\"vdc\">0.00</div><div class=\"unit\">Volt (V)</div></div>";
  html += "</div>";
  html += "<div class=\"footer\">&copy; 2026 ESP32 Local Server</div>";
  html += "</div></body></html>";
  
  server.send(200, "text/html", html);
}

void handleData() {
  String json = "{";
  json += "\"vac\":" + String(v_ac, 1) + ",";
  json += "\"cac\":" + String(c_ac, 3) + ",";
  json += "\"pac\":" + String(p_ac, 1) + ",";
  json += "\"eac\":" + String(e_ac, 2) + ",";
  json += "\"pfac\":" + String(pf_ac, 2) + ",";
  json += "\"freqac\":" + String(freq_ac, 1) + ",";
  json += "\"vdc\":" + String(v_dc, 2);
  json += "}";
  server.send(200, "application/json", json);
}

void handleCaptivePortal() {
  server.sendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  server.sendHeader("Pragma", "no-cache");
  server.sendHeader("Expires", "-1");
  server.sendHeader("Location", "http://192.168.4.1/", true);
  server.send(302, "text/plain", ""); 
}

void setup() {
  Serial.begin(9600);
  delay(1000); 
  
  Serial.println("\n[SISTEM] Memulai inisialisasi...");
  Wire.begin();
  
  // Perubahan: Jangan mengunci program jika INA219 tidak ada
  if (!ina.begin()) {
    Serial.println("[PERINGATAN] INA219 tidak terdeteksi! Sistem tetap berjalan.");
    ina_connected = false;
  } else {
    Serial.println("[OK] INA219 Berhasil Terhubung.");
    ina.setCalibration_32V_2A();
    ina_connected = true;
  }

  WiFi.disconnect();
  WiFi.mode(WIFI_AP);
  
  IPAddress apIP(192, 168, 4, 1);
  IPAddress netMsk(255, 255, 255, 0);
  
  WiFi.softAPConfig(apIP, apIP, netMsk); 
  WiFi.softAP(ssid, password);
  delay(500); 

  dnsServer.setErrorReplyCode(DNSReplyCode::NoError);
  dnsServer.start(DNS_PORT, "*", apIP);

  server.on("/", handleRoot);
  server.on("/data", handleData);
  
  server.on("/generate_204", handleCaptivePortal);
  server.on("/gen_204", handleCaptivePortal);
  server.on("/connecttest.txt", handleCaptivePortal);
  server.on("/ncsi.txt", handleCaptivePortal);
  server.on("/hotspot-detect.html", handleCaptivePortal);
  server.on("/captive-portal", handleCaptivePortal);
  server.on("/success.html", handleCaptivePortal);
  server.on("/generate204", handleCaptivePortal);
  server.on("/library/test/success.html", handleCaptivePortal);
  server.on("/fwlink", handleCaptivePortal);
  server.onNotFound(handleCaptivePortal);

  server.begin();
  Serial.println("[OK] Server Captive Portal Instan Siap di 192.168.4.1");
}

void loop() {
  dnsServer.processNextRequest();
  server.handleClient();

  unsigned long currentMillis = millis();
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    // 1. Baca AC dari PZEM (Aman dari stuck karena library PZEM menggunakan timeout)
    float read_v_ac = pzem.voltage();
    if (!isnan(read_v_ac)) {
      v_ac    = read_v_ac;
      c_ac    = pzem.current();
      p_ac    = pzem.power();
      e_ac    = pzem.energy();
      pf_ac   = pzem.pf();
      freq_ac = pzem.frequency();
    } else {
      Serial.println("[PERINGATAN] Gagal membaca data dari PZEM-004T!");
      // Opsional: set ke 0 jika ingin data langsung hilang saat sensor dicopot
      v_ac = c_ac = p_ac = pf_ac = freq_ac = 0.0; 
    }

    // 2. Baca DC dari INA219 hanya jika sensor terdeteksi saat booting
    if (ina_connected) {
      v_dc = ina.getBusVoltage_V();
    } else {
      v_dc = 0.0; // Set ke 0 jika sensor tidak ada
    }
  }
}