// ===================== ADD THESE INCLUDES AT THE TOP =====================
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <ArduinoJson.h>

// ===================== ADD YOUR CONFIGURATION HERE =====================
// WiFi credentials
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase configuration - USE YOUR ACTUAL VALUES
#define FIREBASE_HOST "login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW"  // Your database secret

// Firebase objects
FirebaseData firebaseData;
FirebaseJson json;

// ===================== ADD THESE VARIABLES =====================
unsigned long lastGPSUpdate = 0;
unsigned long lastHardwareCheck = 0;
bool motorEnabled = false;
bool ultrasonicEnabled = false;
bool audioEnabled = false;

// ===================== ADD THIS FUNCTION =====================
void updateGPSInFirebase() {
  if (gps.location.isValid()) {
    json.clear();
    json.set("latitude", gps.location.lat());
    json.set("longitude", gps.location.lng());
    json.set("timestamp", millis());
    
    if (Firebase.setJSON(firebaseData, "/gps", json)) {
      Serial.println("✅ GPS updated in Firebase");
    } else {
      Serial.println("❌ Firebase GPS update failed: " + firebaseData.errorReason());
    }
  }
}

// ===================== ADD THIS FUNCTION =====================
void checkHardwareControl() {
  if (Firebase.getJSON(firebaseData, "/hardware_control")) {
    FirebaseJson &json = firebaseData.jsonObject();
    FirebaseJsonData jsonData;
    
    bool newMotorEnabled = false;
    bool newUltrasonicEnabled = false;
    bool newAudioEnabled = false;
    
    if (json.get(jsonData, "motorEnabled")) {
      newMotorEnabled = jsonData.boolValue;
    }
    if (json.get(jsonData, "ultrasonicEnabled")) {
      newUltrasonicEnabled = jsonData.boolValue;
    }
    if (json.get(jsonData, "audioEnabled")) {
      newAudioEnabled = jsonData.boolValue;
    }
    
    // Update local variables
    motorEnabled = newMotorEnabled;
    ultrasonicEnabled = newUltrasonicEnabled;
    audioEnabled = newAudioEnabled;
    
    Serial.println("📡 Hardware Control from Firebase:");
    Serial.println("   Motor: " + String(motorEnabled ? "ON" : "OFF"));
    Serial.println("   Ultrasonic: " + String(ultrasonicEnabled ? "ON" : "OFF"));
    Serial.println("   Audio: " + String(audioEnabled ? "ON" : "OFF"));
    
    // Control hardware based on Firebase values
    if (!motorEnabled) {
      motorStop();
      Serial.println("🛑 Motor stopped by Firebase control");
    }
    // Add similar logic for ultrasonic and audio if needed
    
  } else {
    Serial.println("❌ Failed to read hardware control: " + firebaseData.errorReason());
  }
}

// ===================== MODIFY YOUR setup() FUNCTION =====================
// Add this code at the END of your existing setup() function:

void setup() {
  // ... your existing setup code ...
  
  // Initialize WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("✅ Connected with IP: ");
  Serial.println(WiFi.localIP());
  
  // Initialize Firebase
  Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
  Firebase.reconnectWiFi(true);
  
  // Set database read timeout
  Firebase.setReadTimeout(firebaseData, 1000 * 60);
  Firebase.setwriteSizeLimit(firebaseData, "tiny");
  
  Serial.println("✅ Firebase Connected");
  Serial.println("📡 Database URL: " + String(FIREBASE_HOST));
}

// ===================== MODIFY YOUR loop() FUNCTION =====================
// Add this code in your existing loop() function:

void loop() {
  // ... your existing GPS reading code ...
  
  // Update Firebase with GPS data (every 5 seconds)
  if (gps.location.isValid()) {
    if (millis() - lastGPSUpdate > 5000) {
      updateGPSInFirebase();
      lastGPSUpdate = millis();
    }
  }
  
  // Check Firebase for hardware control (every 2 seconds)
  if (millis() - lastHardwareCheck > 2000) {
    checkHardwareControl();
    lastHardwareCheck = millis();
  }
  
  // ===================== MODIFY YOUR ULTRASONIC LOGIC =====================
  // Update your existing ultrasonic logic to respect Firebase control:
  
  // Measure distance
  distance = getDistance();
  
  // Only process ultrasonic if enabled in Firebase
  if (!ultrasonicEnabled) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setCursor(0, 0);
    display.print("Ultrasonic");
    display.println(" Disabled");
    display.setTextSize(1);
    display.setCursor(0, 25);
    display.println("Check Firebase");
    display.display();
    motorStop();
    if (currentAudioState != 0) {
      player.stop();
      currentAudioState = 0;
    }
    delay(200);
    return; // Skip ultrasonic processing
  }
  
  // ... your existing ultrasonic logic continues here ...
  // But add motorEnabled check:
  
  if (distance < 29) {
    display.setCursor(0, 25);
    display.println("INVALID");
    motorStop();
    if (currentAudioState != 0) {
      player.stop();
      currentAudioState = 0;
    }
  }
  else if (distance >= 30 && distance <= 50) {
    display.setCursor(0, 25);
    display.println("Object Detected (NEAR)");
    
    // Only play audio if enabled in Firebase
    if (audioEnabled) {
      if (currentAudioState != 1 || !player.available()) {
        player.stop();
        delay(100);
        player.loop(2);
        currentAudioState = 1;
        Serial.println("▶ Looping 002.mp3 (Near Mode)");
      }
    }
    
    // Only run motor if enabled in Firebase
    if (motorEnabled) {
      motorForwardContinuous();
    } else {
      motorStop();
    }
  }
  else if (distance >= 51 && distance <= 101) {
    display.setCursor(0, 25);
    display.println("Object Detected (MID)");
    
    // Only play audio if enabled in Firebase
    if (audioEnabled) {
      if (currentAudioState != 2 || !player.available()) {
        player.stop();
        delay(100);
        player.loop(3);
        currentAudioState = 2;
        Serial.println("▶ Looping 003.mp3 (Mid Mode)");
      }
    }
    
    // Only run motor if enabled in Firebase
    if (motorEnabled) {
      motorPulse();
    } else {
      motorStop();
    }
  }
  else {
    display.setCursor(0, 25);
    display.println("No Object Detected");
    motorStop();
    if (currentAudioState != 0) {
      player.stop();
      currentAudioState = 0;
      Serial.println("■ Audio & Motor Stopped (Clear Area)");
    }
  }
  
  // ... rest of your existing code ...
}






