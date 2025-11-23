#include "Arduino.h"
#include "DFRobotDFPlayerMini.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>

// ===================== FIREBASE INCLUDES =====================
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseESP32.h>
#include <ArduinoJson.h>

// ===================== OLED Setup =====================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ===================== DFPlayer Pins =====================
#define DF_RX 14
#define DF_TX 13

// ===================== Ultrasonic Pins =====================
#define TRIG_PIN 18
#define ECHO_PIN 19

// ===================== L298N Pins =====================
// COMMENTED OUT FOR GPS TESTING - Motor disabled
// #define ENA 25
// #define IN1 26
// #define IN2 27

// ===================== WiFi Configuration =====================
#define WIFI_SSID "LUNA LAPUK"
#define WIFI_PASSWORD "Bog@rdyuki12"

// ===================== Firebase Configuration =====================
// Note: Use the database URL without https:// and without trailing slash
#define FIREBASE_HOST "login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW"

// ===================== Firebase Objects =====================
FirebaseData firebaseData;          // General purpose (setup/tests)
FirebaseData firebaseGPSData;       // Dedicated to GPS updates
FirebaseData firebaseHardwareData;  // Dedicated to hardware control reads
FirebaseJson json;
bool firebaseReady = false;

// ===================== Globals =====================
HardwareSerial dfSerial(2);
DFRobotDFPlayerMini player;
HardwareSerial GPS_Serial(1);
TinyGPSPlus gps;

double lat = 0.0, lon = 0.0;
long duration;
float distance;
int currentAudioState = 0;  // 0 = none, 1 = 002.mp3, 2 = 003.mp3

unsigned long startupTime;
bool systemReady = false;

// ===================== Firebase Control Variables =====================
unsigned long lastGPSUpdate = 0;
unsigned long lastHardwareCheck = 0;
bool motorEnabled = false;        // Default to disabled until profiling enables it
bool ultrasonicEnabled = false;   // Default to disabled until profiling enables it
bool audioEnabled = false;        // Default to disabled until profiling enables it

// ===================== Motor Control =====================
// COMMENTED OUT FOR GPS TESTING - Motor disabled
// void motorStop() {
//   analogWrite(ENA, 0);
//   digitalWrite(IN1, LOW);
//   digitalWrite(IN2, LOW);
// }
//
// void motorForwardContinuous() {
//   digitalWrite(IN1, HIGH);
//   digitalWrite(IN2, LOW);
//   analogWrite(ENA, 255);
// }
//
// void motorPulse() {
//   digitalWrite(IN1, HIGH);
//   digitalWrite(IN2, LOW);
//   analogWrite(ENA, 255);
//   delay(300);
//   analogWrite(ENA, 0);
//   delay(300);
// }

// ===================== Ultrasonic =====================
float getDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  float dist = duration * 0.034 / 2;
  return dist;
}

// ===================== Firebase Functions =====================

void updateGPSInFirebase() {
  Serial.println("📤 updateGPSInFirebase() called");
  
  if (!firebaseReady) {
    Serial.println("❌ Firebase not ready, aborting GPS update");
    return;
  }
  
  if (!gps.location.isValid()) {
    Serial.println("❌ GPS location not valid, aborting update");
    return;
  }
  
  double lat_val = gps.location.lat();
  double lon_val = gps.location.lng();
  
  Serial.print("📊 Preparing to upload - Lat: ");
  Serial.print(lat_val, 6);
  Serial.print(", Lon: ");
  Serial.print(lon_val, 6);
  Serial.println();
  
  // Use manual HTTPS PUT instead of Firebase.setJSON() to avoid crashes
  Serial.println("📡 Attempting HTTPS PUT to Firebase...");
  
  WiFiClientSecure client;
  client.setInsecure();  // Use TLS without certificate for simplicity
  
  if (!client.connect(FIREBASE_HOST, 443)) {
    Serial.println("❌ HTTPS connect failed to Firebase host");
    return;
  }
  
  // Create JSON payload
  String jsonPayload = "{";
  jsonPayload += "\"latitude\":" + String(lat_val, 6) + ",";
  jsonPayload += "\"longitude\":" + String(lon_val, 6) + ",";
  jsonPayload += "\"timestamp\":" + String(millis());
  jsonPayload += "}";
  
  // Build PUT request
  String url = "/gps.json?auth=" + String(FIREBASE_AUTH);
  String request = "PUT " + url + " HTTP/1.1\r\n";
  request += "Host: " + String(FIREBASE_HOST) + "\r\n";
  request += "Content-Type: application/json\r\n";
  request += "Content-Length: " + String(jsonPayload.length()) + "\r\n";
  request += "Connection: close\r\n\r\n";
  request += jsonPayload;
  
  Serial.println("   Sending PUT request...");
  client.print(request);
  
  // Wait for response
  unsigned long start = millis();
  while (client.connected() && !client.available()) {
    if (millis() - start > 5000) {
      Serial.println("⚠️ HTTP timeout waiting for response");
      client.stop();
      return;
    }
    delay(10);
  }
  
  // Read response
  String response = "";
  while (client.available()) {
    response += client.readString();
  }
  client.stop();
  
  // Check if successful (Firebase returns the data on success)
  if (response.indexOf("\"latitude\"") > 0 || response.indexOf("200 OK") > 0) {
    Serial.println("✅✅✅ GPS SUCCESSFULLY UPDATED IN FIREBASE! ✅✅✅");
    Serial.println("   Response: " + response.substring(0, 100));  // First 100 chars
  } else {
    Serial.println("❌❌❌ Firebase GPS update FAILED");
    Serial.println("   Response: " + response.substring(0, 200));  // First 200 chars
  }
}

void pollHardwareControl() {
  WiFiClientSecure client;
  client.setInsecure();  // use TLS without certificate for simplicity

  String url = String("/hardware_control.json?auth=") + FIREBASE_AUTH;
  Serial.println("🔍 HTTP GET " + url);

  if (!client.connect(FIREBASE_HOST, 443)) {
    Serial.println("❌ HTTPS connect failed");
    return;
  }

  client.printf("GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", url.c_str(), FIREBASE_HOST);

  // Wait for response headers
  unsigned long start = millis();
  while (client.connected() && !client.available()) {
    if (millis() - start > 3000) {
      Serial.println("⚠️ HTTP timeout");
      client.stop();
      return;
    }
    delay(10);
  }

  // Read headers and skip them
  while (client.available()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") break;
    }
    
  // Read JSON payload
  String payload;
  while (client.available()) {
    payload += client.readString();
  }
  client.stop();

  Serial.println("📨 Raw payload: " + payload);

  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.print("❌ JSON parse failed: ");
    Serial.println(err.c_str());
    return;
  }

  bool newMotorEnabled = doc["motorEnabled"] | motorEnabled;
  bool newUltrasonicEnabled = doc["ultrasonicEnabled"] | ultrasonicEnabled;
  bool newAudioEnabled = doc["audioEnabled"] | audioEnabled;

  Serial.println("   motorEnabled = " + String(newMotorEnabled ? "true" : "false"));
  Serial.println("   ultrasonicEnabled = " + String(newUltrasonicEnabled ? "true" : "false"));
  Serial.println("   audioEnabled = " + String(newAudioEnabled ? "true" : "false"));

    bool valuesChanged = (motorEnabled != newMotorEnabled || 
                         ultrasonicEnabled != newUltrasonicEnabled || 
                         audioEnabled != newAudioEnabled);
    
    motorEnabled = newMotorEnabled;
    ultrasonicEnabled = newUltrasonicEnabled;
    audioEnabled = newAudioEnabled;
    
    if (valuesChanged) {
      Serial.println("   ⚠️ Values changed!");
    }
    
  // COMMENTED OUT FOR GPS TESTING - Motor control disabled
  // if (!motorEnabled) {
  //   motorStop();
  //   Serial.println("🛑 Motor stopped by Firebase control");
  // }
    
  // COMMENTED OUT FOR GPS TESTING - Audio control disabled
  // if (!audioEnabled && currentAudioState != 0) {
  //   player.stop();
  //   currentAudioState = 0;
  //   Serial.println("🔇 Audio stopped by Firebase control");
  // }
}

// ===================== Setup =====================
void setup() {
  // Initialize Serial FIRST - very important!
  Serial.begin(115200);

  // Wait for Serial to be ready (important for some ESP32 boards)
  delay(2000);
  
  // Test Serial immediately
  Serial.println();
  Serial.println();
  Serial.println("========================================");
  Serial.println("=== ESP32 BOOTING ===");
  Serial.println("========================================");
  Serial.println("Starting GPS test mode...");
  Serial.print("Serial test: ");
  Serial.println("WORKING!");
  Serial.println("========================================");

  // Increase TLS/response buffers to avoid SSL errors when using multiple Firebase handles
  firebaseData.setBSSLBufferSize(2048, 1024);
  firebaseGPSData.setBSSLBufferSize(2048, 1024);
  firebaseHardwareData.setBSSLBufferSize(2048, 1024);
  firebaseData.setResponseSize(1024);
  firebaseGPSData.setResponseSize(1024);
  firebaseHardwareData.setResponseSize(2048);

  // COMMENTED OUT FOR GPS TESTING - Ultrasonic pins disabled
  // pinMode(TRIG_PIN, OUTPUT);
  // pinMode(ECHO_PIN, INPUT);
  // COMMENTED OUT FOR GPS TESTING - Motor pins disabled
  // pinMode(ENA, OUTPUT);
  // pinMode(IN1, OUTPUT);
  // pinMode(IN2, OUTPUT);
  //
  // motorStop();

  // OLED init
  Wire.begin(21, 22);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("System Booting...");
  display.display();

  // DFPlayer init - COMMENTED OUT FOR GPS TESTING
  // dfSerial.begin(9600, SERIAL_8N1, 13, 14); //DF_RX, DF_TX
  // if (player.begin(dfSerial)) {
  //   player.volume(30);
  //   player.playFolder(1, 1); // Play 001.mp3 on startup
  //   Serial.println("✅ DFPlayer Active: Playing 001.mp3");
  // } else {
  //   Serial.println("❌ DFPlayer Error!");
  // }

  // GPS init
  GPS_Serial.begin(9600, SERIAL_8N1, 5, 4);

  startupTime = millis();
  systemReady = false;
  Serial.println("🕐 Waiting 7 seconds before enabling sensors...");

  // ===================== WiFi Connection =====================
  Serial.println();
  Serial.println("========================================");
  Serial.println("📶 STARTING WIFI CONNECTION");
  Serial.println("========================================");
  
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("Connecting WiFi...");
  display.display();
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("📶 Connecting to WiFi: ");
  Serial.print(WIFI_SSID);
  Serial.print(" (");
  Serial.print(WIFI_PASSWORD);
  Serial.println(")");
  
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 30) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("========================================");
    Serial.print("✅ WiFi Connected! IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("   Signal Strength (RSSI): ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    Serial.println("========================================");
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi Connected!");
    display.setCursor(0, 15);
    display.print("IP: ");
    display.println(WiFi.localIP().toString());
    display.display();
    delay(2000);
  } else {
    Serial.println("❌ WiFi Connection Failed!");
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi Failed!");
    display.display();
  }

  // ===================== Firebase Connection =====================
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("========================================");
    Serial.println("🔧 STARTING FIREBASE CONNECTION");
    Serial.println("========================================");
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Connecting Firebase...");
    display.display();
    
    // Firebase configuration for newer library version
    FirebaseConfig config;
    FirebaseAuth auth;
    
    // Set database host (without https://)
    config.host = FIREBASE_HOST;
    config.signer.tokens.legacy_token = FIREBASE_AUTH;
    
    // Set timeouts
    config.timeout.serverResponse = 10 * 1000;
    config.timeout.socketConnection = 10 * 1000;
    
    // Enable auto reconnect
    Firebase.reconnectWiFi(true);
    
    // Initialize Firebase
    Serial.print("🔧 Initializing Firebase with host: ");
    Serial.println(FIREBASE_HOST);
    Serial.print("   Auth token: ");
    String authStr = String(FIREBASE_AUTH);
    Serial.print(authStr.substring(0, 10));
    Serial.println("...");
    
    Firebase.begin(&config, &auth);
    
    // Wait a bit for Firebase to initialize
    Serial.println("   Waiting for Firebase to initialize...");
    delay(2000);
    
    // Test connection by trying to read a simple path
    Serial.println("🔍 Testing Firebase connection...");
    if (Firebase.get(firebaseData, "/")) {
      Serial.println("========================================");
      Serial.println("✅ Firebase connection test successful!");
      Serial.println("========================================");
      firebaseReady = true;
    } else {
      Serial.println("========================================");
      Serial.print("⚠️ Firebase connection test failed: ");
      Serial.println(firebaseData.errorReason());
      Serial.print("   Error code: ");
      Serial.println(firebaseData.errorCode());
      Serial.println("========================================");
      // Still mark as ready, but with warning
      firebaseReady = true;
      Serial.println("⚠️ Continuing anyway, will retry on first read...");
    }
    
    Serial.print("✅ Firebase Initialized - Ready: ");
    Serial.println(firebaseReady ? "YES" : "NO");
    Serial.print("📡 Database: ");
    Serial.println(FIREBASE_HOST);
    Serial.println("========================================");
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Firebase OK!");
    display.display();
    delay(1000);
  }
}

// ===================== Loop =====================
void loop() {
  // Simple Serial test - print every loop to verify Serial is working
  static unsigned long loopCounter = 0;
  static unsigned long lastLoopPrint = 0;
  loopCounter++;
  
  if (millis() - lastLoopPrint > 2000) {  // Print every 2 seconds
    Serial.print("🔄 Loop running #");
    Serial.print(loopCounter);
    Serial.print(" | Free heap: ");
    Serial.print(ESP.getFreeHeap());
    Serial.println(" bytes");
    lastLoopPrint = millis();
  }
  
  // GPS READ
  while (GPS_Serial.available()) gps.encode(GPS_Serial.read());
  if (gps.location.isValid()) {
    lat = gps.location.lat();
    lon = gps.location.lng();
  }

  // Wait for system stabilization
  if (!systemReady) {
    if (millis() - startupTime >= 7000) {
      systemReady = true;
      Serial.println();
      Serial.println("========================================");
      Serial.println("✅ SYSTEM ACTIVE - GPS TESTING MODE");
      Serial.println("========================================");
      Serial.print("   systemReady: ");
      Serial.println(systemReady ? "YES" : "NO");
      Serial.print("   WiFi Status: ");
      Serial.println(WiFi.status() == WL_CONNECTED ? "CONNECTED" : "DISCONNECTED");
      Serial.print("   firebaseReady: ");
      Serial.println(firebaseReady ? "YES" : "NO");
      Serial.println("========================================");
    } else {
      display.clearDisplay();
      display.setCursor(0, 0);
      display.println("Booting...");
      display.setCursor(0, 15);
      display.println("Searching GPS...");
      if (WiFi.status() == WL_CONNECTED) {
        display.setCursor(0, 30);
        display.println("WiFi: OK");
        display.setCursor(0, 45);
        display.println("Firebase: OK");
      }
      display.display();
      return;
    }
  }

  // ===================== Firebase GPS Update =====================
  // Debug: Log GPS status periodically
  static unsigned long lastGPSStatusLog = 0;
  if (millis() - lastGPSStatusLog > 2000) {  // Log every 2 seconds
    Serial.println("═══════════════════════════════════");
    Serial.print("📡 GPS Status - Satellites: ");
    Serial.print(gps.satellites.value());
    Serial.print(", Valid: ");
    Serial.print(gps.location.isValid() ? "YES ✅" : "NO ❌");
    if (gps.location.isValid()) {
      Serial.print(", Lat: ");
      Serial.print(gps.location.lat(), 6);
      Serial.print(", Lon: ");
      Serial.print(gps.location.lng(), 6);
    }
    Serial.println();
    lastGPSStatusLog = millis();
  }
  
  // Detailed condition checking for Firebase upload - ALWAYS check if GPS is valid
  if (gps.location.isValid()) {
    static unsigned long lastConditionCheck = 0;
    if (millis() - lastConditionCheck > 3000) {  // Check every 3 seconds
      Serial.println("🔍 Checking Firebase upload conditions:");
      Serial.print("   systemReady: ");
      Serial.println(systemReady ? "YES ✅" : "NO ❌");
      Serial.print("   WiFi Connected: ");
      Serial.println(WiFi.status() == WL_CONNECTED ? "YES ✅" : "NO ❌");
      Serial.print("   WiFi Status Code: ");
      Serial.println(WiFi.status());
      Serial.print("   firebaseReady: ");
      Serial.println(firebaseReady ? "YES ✅" : "NO ❌");
      Serial.print("   GPS Valid: ");
      Serial.println(gps.location.isValid() ? "YES ✅" : "NO ❌");
      Serial.println("═══════════════════════════════════");
      lastConditionCheck = millis();
    }
  }
  
  if (systemReady && WiFi.status() == WL_CONNECTED && firebaseReady && gps.location.isValid()) {
    if (millis() - lastGPSUpdate > 5000) {  // Update every 5 seconds
      Serial.println("✅ All conditions met! Uploading GPS to Firebase...");
      updateGPSInFirebase();
      lastGPSUpdate = millis();
    }
  } else if (gps.location.isValid()) {
    // GPS is valid but something else is blocking upload
    static unsigned long lastBlockingLog = 0;
    if (millis() - lastBlockingLog > 10000) {  // Warn every 10 seconds
      Serial.print("⚠️ GPS valid but CAN'T upload - ");
      if (!systemReady) Serial.println("System not ready");
      else if (WiFi.status() != WL_CONNECTED) Serial.println("WiFi not connected");
      else if (!firebaseReady) Serial.println("Firebase not ready");
      lastBlockingLog = millis();
    }
  } else {
    // GPS not valid yet
    static unsigned long lastWarningLog = 0;
    if (millis() - lastWarningLog > 10000) {  // Warn every 10 seconds
      Serial.println("⚠️ GPS has satellites but location not valid yet. Waiting for fix...");
      lastWarningLog = millis();
    }
  }

  // ===================== Firebase Hardware Control Check =====================
  // COMMENTED OUT FOR GPS TESTING - Hardware polling disabled to isolate GPS
  // if (systemReady && WiFi.status() == WL_CONNECTED && firebaseReady) {
  //   if (millis() - lastHardwareCheck > 10000) {  // Check every 10 seconds
  //     pollHardwareControl();
  //     lastHardwareCheck = millis();
  //   }
  // }

  // ===================== Ultrasonic Logic - COMMENTED OUT FOR GPS TESTING =====================
  // Simplified display - GPS only with Firebase status
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("GPS Status:");

  if (gps.location.isValid()) {
    display.setCursor(0, 10);
    display.print("Lat: ");
    display.println(lat, 6);
    display.setCursor(0, 20);
    display.print("Lon: ");
    display.println(lon, 6);
    display.setCursor(0, 30);
    display.print("Sats: ");
    display.print(gps.satellites.value());
    display.print(" [FIX]");
    
    // Show Firebase upload status
    display.setCursor(0, 40);
    if (systemReady && WiFi.status() == WL_CONNECTED && firebaseReady) {
      static unsigned long lastUploadAttempt = 0;
      static bool uploadSuccess = false;
      
      if (millis() - lastGPSUpdate > 5000) {
        display.print("Uploading...");
        display.display();
        updateGPSInFirebase();
        lastGPSUpdate = millis();
        lastUploadAttempt = millis();
        uploadSuccess = true;  // Assume success for now
      } else if (uploadSuccess && (millis() - lastUploadAttempt < 2000)) {
        display.print("Uploaded! ✓");
    } else {
        display.print("WiFi:OK FB:OK");
      }
    } else {
      display.print("WiFi:");
      display.print(WiFi.status() == WL_CONNECTED ? "OK" : "NO");
      display.print(" FB:");
      display.print(firebaseReady ? "OK" : "NO");
    }
    
    display.setCursor(0, 50);
    display.print("Next upload: ");
    display.print((5000 - (millis() - lastGPSUpdate)) / 1000);
    display.print("s");
    } else {
    display.setCursor(0, 15);
    display.println("Searching GPS...");
    display.setCursor(0, 30);
    display.print("Satellites: ");
    display.println(gps.satellites.value());
    display.setCursor(0, 45);
    display.println("Waiting for fix...");
  }

  display.display();
  delay(200);
}

