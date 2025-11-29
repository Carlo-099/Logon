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

// ===================== SIM800L GSM MODULE =====================
// Set to 1 to enable SIM800L GPRS fallback, 0 to disable
#define ENABLE_SIM800L 1

#if ENABLE_SIM800L
// Note: Install TinyGSM library: Tools → Manage Libraries → Search "TinyGSM"
// If TinyGsmClientSecure doesn't exist, you may need to use HTTP instead of HTTPS
// or update to a newer version of TinyGSM library
#define TINY_GSM_MODEM_SIM800
#include <SoftwareSerial.h>
#include <TinyGsmClient.h>
#endif

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
#define ENA 25
#define IN1 26
#define IN2 27

// ===================== Vibration Motor PWM Control =====================
// Vibration motor rated: 3-5V
// L298N power supply: 12V
// PWM calculation: To get ~4V from 12V = 4/12 = 33% = 84/255
// Using 90/255 = 35% = ~4.2V equivalent (safe for 3-5V motor)
#define VIBRATION_MOTOR_PWM 90  // Adjust if vibration is too weak (increase) or too strong (decrease)

// ===================== Ultrasonic Sensor Thresholds =====================
// HC-SR04 ultrasonic sensors are not accurate below 2cm
// Readings below 2cm are usually false readings or noise
#define MIN_VALID_DISTANCE 2.0   // Minimum valid distance in cm (ignore readings below this)
#define MAX_VALID_DISTANCE 400.0  // Maximum valid distance in cm

// ===================== SIM800L Pins =====================
// IMPORTANT: For UART, TX connects to RX and RX connects to TX!
// ESP32 RX pin (receives from SIM800L) -> connects to SIM800L TX
// ESP32 TX pin (sends to SIM800L) -> connects to SIM800L RX
#define SIM800L_RX 17  // ESP32 RX pin (GPIO 17) -> connect to SIM800L TX pin
#define SIM800L_TX 16  // ESP32 TX pin (GPIO 16) -> connect to SIM800L RX pin
#define SIM800L_PWR 32 // Optional: Power pin for SIM800L (if you have it)

// ===================== WiFi Configuration =====================
// Current WiFi credentials (active)
//#define WIFI_SSID "LUNA LAPUK"
//#define WIFI_PASSWORD "Bog@rdyuki12"

// Previous WiFi credentials (commented out for reference - PLDT)
#define WIFI_SSID "PLDTHOMEFIBRsyhhi"
#define WIFI_PASSWORD "PLDTWIFIkyzbp"

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
#if ENABLE_SIM800L
SoftwareSerial SIM800L_Serial(SIM800L_RX, SIM800L_TX);  // Requires EspSoftwareSerial on ESP32
TinyGsm modem(SIM800L_Serial);
#endif

double lat = 0.0, lon = 0.0;
long duration;
float distance;
float filteredDistance = 0.0;  // Filtered/averaged distance for stability
int currentAudioState = 0;          // 0 = none, 1 = 002.mp3, 2 = 003.mp3
bool dfPlayerReady = false;         // Track if DFPlayer is initialized and ready
bool startupAudioPlayed = false;    // Track if startup audio (001/004) has been played
unsigned long startupAudioTime = 0; // When startup audio started (for timing/gating)
bool ultrasonicEnabledAfterDelay = false; // Prevent ultrasonic from running during startup audio
unsigned long lastMotorPulse = 0;   // Timing for fast pulsing at 100cm
bool motorPulseState = false;       // Current state for fast pulsing (on/off toggle)

unsigned long startupTime;
bool systemReady = false;

// ===================== Firebase Control Variables =====================
unsigned long lastGPSUpdate = 0;
unsigned long lastHardwareCheck = 0;
bool motorEnabled = false;        // Default to disabled until profiling enables it
bool ultrasonicEnabled = false;   // Default to disabled until profiling enables it
bool audioEnabled = false;        // Default to disabled until profiling enables it
String userLanguage = "tagalog";  // Default language: "tagalog" or "english"
unsigned long lastLanguageCheck = 0;  // Track when we last checked language preference

// ===================== Connection Management =====================
enum ConnectionType {
  CONN_NONE,
  CONN_WIFI,
  CONN_GPRS
};
ConnectionType currentConnection = CONN_NONE;
bool gprsReady = false;
unsigned long lastConnectionCheck = 0;
unsigned long lastGPRSReconnectAttempt = 0;
const unsigned long CONNECTION_CHECK_INTERVAL = 10000;  // Check every 10 seconds
const unsigned long GPRS_RECONNECT_INTERVAL = 30000;     // Try GPRS reconnect every 30 seconds

// ===================== Motor Control =====================
void motorStop() {
  analogWrite(ENA, 0);
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
}

void motorForwardContinuous() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  // Using reduced PWM to protect 3-5V vibration motor from 12V supply
  analogWrite(ENA, VIBRATION_MOTOR_PWM);
}

void motorPulse() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  // Using reduced PWM to protect 3-5V vibration motor from 12V supply
  analogWrite(ENA, VIBRATION_MOTOR_PWM);
  delay(300);
  analogWrite(ENA, 0);
  delay(300);
}

// Motor control with distance-based vibration patterns
void motorControlByDistance(float dist) {
  if (!motorEnabled) {
    motorStop();
    return;
  }
  
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  
  static float lastLoggedDist = 0;
  static unsigned long lastMotorLog = 0;
  
  if (dist <= 50) {  // At 0.5 meters (50cm) or closer
    // Continuous vibration
    analogWrite(ENA, VIBRATION_MOTOR_PWM);
    // Log only when entering this range or every 2 seconds
    if (lastLoggedDist > 50 || millis() - lastMotorLog > 2000) {
      Serial.print("🔔 Motor: Continuous vibration (");
      Serial.print(dist);
      Serial.println("cm)");
      lastLoggedDist = dist;
      lastMotorLog = millis();
    }
  } else if (dist <= 100) {  // At 1 meter (100cm) or closer (but >50cm)
    // Fast pulsing/bouncing effect
    unsigned long currentTime = millis();
    if (currentTime - lastMotorPulse >= 150) {  // Fast pulse every 150ms
      motorPulseState = !motorPulseState;
      if (motorPulseState) {
        analogWrite(ENA, VIBRATION_MOTOR_PWM);
      } else {
        analogWrite(ENA, 0);
      }
      lastMotorPulse = currentTime;
      // Log only when entering this range or every 2 seconds
      if (lastLoggedDist <= 50 || lastLoggedDist > 100 || millis() - lastMotorLog > 2000) {
        Serial.print("🔔 Motor: Fast pulse (");
        Serial.print(dist);
        Serial.println("cm)");
        lastLoggedDist = dist;
        lastMotorLog = millis();
      }
    }
  } else {
    // Object too far - stop motor
    motorStop();
    if (lastLoggedDist <= 100) {  // Log when motor stops
      Serial.println("🔔 Motor: Stopped (object >100cm)");
      lastLoggedDist = dist;
    }
  }
}

// ===================== Audio Language Helper =====================
// Maps audio file numbers based on language preference
// Tagalog: 001, 002, 003
// English: 004, 005, 006
int getAudioFileNumber(int baseFile) {
  // baseFile should be 1, 2, or 3 (for Tagalog files 001, 002, 003)
  if (userLanguage == "english") {
    // English files: 004, 005, 006 (baseFile + 3)
    return baseFile + 3;
  } else {
    // Tagalog files: 001, 002, 003 (default)
    return baseFile;
  }
}

// ===================== Ultrasonic =====================
// Get distance with averaging for stability (takes 3 readings and averages them)
// Reduced from 5 to 3 for faster response time
float getDistance() {
  const int numReadings = 3;  // Number of readings to average (reduced for faster response)
  float readings[numReadings];
  float sum = 0;
  int validReadings = 0;
  
  // Take multiple readings
  for (int i = 0; i < numReadings; i++) {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    long duration = pulseIn(ECHO_PIN, HIGH, 30000);
    float dist = duration * 0.034 / 2;
    
    // Accept all readings (even < 2cm) for averaging, but mark invalid ones
    if (dist > 0 && dist < 400.0) {
      readings[validReadings] = dist;
      sum += dist;
      validReadings++;
    }
    delayMicroseconds(50);  // Reduced delay for faster readings
  }
  
  // Return average if we have readings, otherwise return 0 (invalid)
  if (validReadings > 0) {
    return sum / validReadings;
  } else {
    return 0;  // Invalid reading
  }
}

// Get filtered distance using exponential moving average for smoother readings
// Made more responsive for faster updates when object moves
float getFilteredDistance(float newReading) {
  const float alpha = 0.7;  // Smoothing factor (0.0-1.0, higher = more responsive)
  // Increased from 0.3 to 0.7 for faster response to actual distance changes
  
  if (newReading > 0 && newReading < 400.0) {
    // Any reading (including < 2cm) - apply exponential moving average
    if (filteredDistance == 0.0) {
      // First reading - use it directly
      filteredDistance = newReading;
    } else {
      // Smooth the reading but be more responsive (70% new, 30% old)
      filteredDistance = alpha * newReading + (1.0 - alpha) * filteredDistance;
    }
  } else {
    // Completely invalid reading (0 or >= 400) - reset
    filteredDistance = 0.0;
  }
  
  return filteredDistance;
}

// ===================== SIM800L GPRS Functions =====================
#if ENABLE_SIM800L

// Helper function to send AT command and wait for response
String sendATCommand(String command, unsigned long timeout = 2000) {
  SIM800L_Serial.flush();
  SIM800L_Serial.println(command);
  Serial.print("📤 Sent: ");
  Serial.println(command);
  
  unsigned long start = millis();
  String response = "";
  
  while (millis() - start < timeout) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      response += c;
      if (response.indexOf("OK") >= 0 || response.indexOf("ERROR") >= 0) {
        break;
      }
    }
    delay(10);
  }
  
  response.trim();
  if (response.length() > 0) {
    Serial.print("📥 Response: ");
    Serial.println(response);
    // Also show raw hex for debugging
    Serial.print("   Hex: ");
    for (int i = 0; i < response.length() && i < 20; i++) {
      if (response[i] < 0x20 || response[i] > 0x7E) {
        Serial.print("\\x");
        if (response[i] < 0x10) Serial.print("0");
        Serial.print((int)response[i], HEX);
      } else {
        Serial.print(response[i]);
      }
    }
    Serial.println();
  } else {
    Serial.println("⚠️ No response received");
  }
  
  return response;
}

// Wait for module to finish booting (looks for "RDY" or "Call Ready")
bool waitForModuleReady(unsigned long timeout = 10000) {
  Serial.println("⏳ Waiting for module to finish booting...");
  unsigned long start = millis();
  String bootMessage = "";
  
  while (millis() - start < timeout) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      bootMessage += c;
      
      // Check for boot completion messages
      if (bootMessage.indexOf("RDY") >= 0 || 
          bootMessage.indexOf("Call Ready") >= 0 ||
          bootMessage.indexOf("SMS Ready") >= 0) {
        Serial.println("✅ Module boot complete!");
        Serial.print("   Boot message: ");
        Serial.println(bootMessage);
        return true;
      }
      
      // Show any data we're receiving
      if (bootMessage.length() > 0 && bootMessage.length() % 10 == 0) {
        Serial.print("   Receiving: ");
        Serial.println(bootMessage.substring(bootMessage.length() - 10));
      }
    }
    delay(10);
  }
  
  if (bootMessage.length() > 0) {
    Serial.print("⚠️ Got boot data but no 'RDY': ");
    Serial.println(bootMessage);
  } else {
    Serial.println("⚠️ No boot messages received");
  }
  
  return false;
}

bool initSIM800L() {
  Serial.println("========================================");
  Serial.println("📱 INITIALIZING SIM800L MODULE");
  Serial.println("========================================");
  
  // Optional: Hardware reset via PWR pin (if connected)
  #ifdef SIM800L_PWR
  Serial.println("🔌 Attempting hardware reset via PWR pin...");
  pinMode(SIM800L_PWR, OUTPUT);
  digitalWrite(SIM800L_PWR, LOW);
  delay(1000);
  digitalWrite(SIM800L_PWR, HIGH);
  delay(5000);  // Give module more time to boot after reset
  #endif
  
  // Use a single, fixed baud rate for SIM800L
  // Your module clearly responds at 9600 (AT OK at 9600), so we lock to that.
  const long simBaud = 9600;
  Serial.print("🔌 Initializing SIM800L at fixed baud (no scan): ");
  Serial.println(simBaud);

  SIM800L_Serial.end();
  delay(200);
  SIM800L_Serial.begin(simBaud);
  delay(3000);  // Wait for serial to stabilize

  // Clear any garbage in buffer first
  delay(500);
  while (SIM800L_Serial.available()) {
    char c = SIM800L_Serial.read();
    Serial.print("   Flushed: 0x");
    Serial.println((int)c, HEX);
  }

  // Wait for module to finish booting (if it's still booting)
  Serial.println("   Waiting for module ready...");
  waitForModuleReady(5000);

  // Clear buffer again after boot messages
  delay(500);
  while (SIM800L_Serial.available()) {
    SIM800L_Serial.read();
  }

  // Try AT command a few times at this fixed baud
  String atResponse = "";
  bool atOk = false;
  for (int attempt = 0; attempt < 3; attempt++) {
    Serial.print("🔍 Testing AT command (attempt ");
    Serial.print(attempt + 1);
    Serial.println(")...");
    
    atResponse = sendATCommand("AT", 3000);
    
    if (atResponse.indexOf("OK") >= 0) {
      Serial.println("✅✅✅ AT OK at fixed baud rate");
      atOk = true;
      break;
    }
    
    if (atResponse.length() > 0) {
      Serial.print("   Got response but not OK (length: ");
      Serial.print(atResponse.length());
      Serial.println(")");
    }
    
    delay(500);
  }
  
  if (!atOk) {
    Serial.println("❌ No valid AT response at fixed baud - checking hardware:");
    Serial.println("   1. SIM800L Vcc connected to 4V power?");
    Serial.println("   2. GND shared between ESP32 and SIM800L?");
    Serial.println("   3. SIM800L TX -> ESP32 GPIO17?");
    Serial.println("   4. SIM800L RX -> ESP32 GPIO16?");
    Serial.println("   5. SIM card inserted and antenna connected?");
    Serial.println("   6. Module LED blinking? (should blink every 3s when registered)");
    
    // Try to read any raw data that might be coming
    Serial.println("🔍 Checking for any incoming data...");
    delay(2000);
    if (SIM800L_Serial.available()) {
      Serial.print("📥 Raw data received: ");
      while (SIM800L_Serial.available()) {
        Serial.print((char)SIM800L_Serial.read());
      }
      Serial.println();
    } else {
      Serial.println("   No data received at all");
    }
    
    return false;
  }
  
  Serial.println("✅ Basic AT communication OK!");
  
  // Test modem communication with TinyGSM
  Serial.println("🔍 Testing modem info via TinyGSM...");
  modem.restart();
  delay(3000);
  
  String modemInfo = modem.getModemInfo();
  if (modemInfo.length() > 0) {
    Serial.print("✅ Modem Info: ");
    Serial.println(modemInfo);
  } else {
    Serial.println("❌ Failed to get modem info via TinyGSM");
    Serial.println("   But basic AT works - trying to continue...");
    // Continue anyway if basic AT works
  }
  
  // Wait for network registration - THIS IS THE KEY TEST FOR 2G SUPPORT
  Serial.println("========================================");
  Serial.println("📶 TESTING NETWORK REGISTRATION (2G)");
  Serial.println("========================================");
  Serial.println("⏳ Waiting up to 60 seconds for network registration...");
  Serial.println("   This will tell us if 2G is available in your area");
  Serial.println("   (No load needed for this test)");

  // Extra diagnostics before registration attempt
  Serial.println("🔍 Pre-registration diagnostics (before waitForNetwork):");
  String csqBefore = sendATCommand("AT+CSQ", 3000);
  Serial.println("   Signal quality (CSQ): " + csqBefore);
  String copsBefore = sendATCommand("AT+COPS?", 3000);
  Serial.println("   Operator (COPS?): " + copsBefore);
  
  unsigned long regStart = millis();
  bool registered = modem.waitForNetwork(60000);
  unsigned long regTime = millis() - regStart;
  
  if (!registered) {
    Serial.println("========================================");
    Serial.println("❌❌❌ NETWORK REGISTRATION FAILED! ❌❌❌");
    Serial.println("========================================");
    Serial.println("This means:");
    Serial.println("  1. NO 2G (GSM) signal in your area, OR");
    Serial.println("  2. Your SIM doesn't support 2G, OR");
    Serial.println("  3. SIM800L hardware issue");
    Serial.println("");
    Serial.println("Time waited: " + String(regTime/1000) + " seconds");
    
    // Extra diagnostics after failure
    Serial.println("🔍 Post-failure diagnostics:");
    String netStatus = sendATCommand("AT+CREG?", 3000);
    Serial.println("   CREG? (registration status): " + netStatus);
    String csqAfter = sendATCommand("AT+CSQ", 3000);
    Serial.println("   CSQ (signal quality): " + csqAfter);
    String copsAfter = sendATCommand("AT+COPS?", 3000);
    Serial.println("   COPS? (current operator): " + copsAfter);
    String cgatt = sendATCommand("AT+CGATT?", 3000);
    Serial.println("   CGATT? (GPRS attach): " + cgatt);
    
    return false;
  }
  
  Serial.println("========================================");
  Serial.println("✅✅✅ NETWORK REGISTRATION SUCCESS! ✅✅✅");
  Serial.println("========================================");
  Serial.println("🎉 Your SIM has 2G support!");
  Serial.println("   Registration time: " + String(regTime/1000) + " seconds");
  
  // Get network operator info
  Serial.println("📡 Getting network operator info...");
  String operatorInfo = sendATCommand("AT+COPS?", 3000);
  Serial.println("   Operator: " + operatorInfo);
  
  // Check signal quality
  Serial.println("📶 Checking signal quality...");
  int signalQuality = modem.getSignalQuality();
  Serial.print("   Signal Quality: ");
  Serial.print(signalQuality);
  Serial.println(" dBm");
  
  if (signalQuality > 0 && signalQuality < 32) {
    Serial.println("   ✅ Good signal strength!");
  } else if (signalQuality >= 32) {
    Serial.println("   ⚠️ Weak signal (might affect GPRS)");
  }
  
  // Connect to GPRS (NOTE: This requires load/data plan)
  Serial.println("========================================");
  Serial.println("🌐 TESTING GPRS CONNECTION");
  Serial.println("========================================");
  Serial.println("⚠️ NOTE: GPRS requires load/data plan");
  Serial.println("   If this fails, you need to load your SIM");
  Serial.println("   But network registration (above) already confirms 2G works!");
  
  // APN for TNT Philippines: "internet" (no username/password needed)
  // If this doesn't work, try: "smartbro" or check with your carrier
  Serial.println("🌐 Connecting to GPRS...");
  Serial.println("   APN: internet (TNT)");
  if (!modem.gprsConnect("internet", "", "")) {
    Serial.println("⚠️ First APN attempt failed, trying 'smartbro'...");
    if (!modem.gprsConnect("smartbro", "", "")) {
      Serial.println("❌ GPRS connection failed!");
      Serial.println("   This might be because:");
      Serial.println("   1. No load/data plan on SIM");
      Serial.println("   2. Wrong APN settings");
      Serial.println("   3. Network issue");
      Serial.println("");
      Serial.println("✅ BUT: Network registration success means 2G WORKS!");
      Serial.println("   Just add load to use GPRS for Firebase");
      return false;  // Return false but network test already passed
    }
  }
  
  Serial.println("✅✅✅ GPRS Connected! ✅✅✅");
  Serial.print("   IP Address: ");
  Serial.println(modem.getLocalIP());
  Serial.println("   🎉 Your SIM is ready for Firebase uploads!");
  
  return true;
}

bool checkGPRSConnection() {
  if (!modem.isNetworkConnected()) {
    Serial.println("⚠️ GPRS network disconnected");
    return false;
  }
  if (!modem.isGprsConnected()) {
    Serial.println("⚠️ GPRS connection lost");
    return false;
  }
  return true;
}

#endif // ENABLE_SIM800L

// ===================== Connection Management =====================

void checkConnectionStatus() {
  // Check WiFi first (preferred connection)
  if (WiFi.status() == WL_CONNECTED) {
    if (currentConnection != CONN_WIFI) {
      Serial.println("🔄 Switching to WiFi connection");
      currentConnection = CONN_WIFI;
      gprsReady = false;
    }
    return;
  }
  
  // WiFi disconnected - try GPRS (if enabled)
  #if ENABLE_SIM800L
  if (currentConnection != CONN_GPRS) {
    // Only retry GPRS after GPRS_RECONNECT_INTERVAL to avoid constant 60s waits
    unsigned long timeSinceLastAttempt = millis() - lastGPRSReconnectAttempt;
    if (timeSinceLastAttempt >= GPRS_RECONNECT_INTERVAL || lastGPRSReconnectAttempt == 0) {
      Serial.println("⚠️ WiFi disconnected, attempting GPRS connection...");
      lastGPRSReconnectAttempt = millis();
      if (initSIM800L()) {
        currentConnection = CONN_GPRS;
        gprsReady = true;
        Serial.println("✅ Switched to GPRS connection");
      } else {
        currentConnection = CONN_NONE;
        gprsReady = false;
        Serial.println("❌ Failed to connect via GPRS - will retry in 30 seconds");
      }
    } else {
      // Still waiting for retry interval
      unsigned long remaining = (GPRS_RECONNECT_INTERVAL - timeSinceLastAttempt) / 1000;
      static unsigned long lastRetryLog = 0;
      if (millis() - lastRetryLog > 10000) {  // Log every 10 seconds
        Serial.print("⏳ Waiting before GPRS retry: ");
        Serial.print(remaining);
        Serial.println(" seconds remaining");
        lastRetryLog = millis();
      }
    }
  } else {
    // Already on GPRS - check if still connected
    if (!checkGPRSConnection()) {
      // Only retry after interval
      unsigned long timeSinceLastAttempt = millis() - lastGPRSReconnectAttempt;
      if (timeSinceLastAttempt >= GPRS_RECONNECT_INTERVAL) {
        Serial.println("⚠️ GPRS connection lost, attempting reconnect...");
        lastGPRSReconnectAttempt = millis();
        if (initSIM800L()) {
          gprsReady = true;
        } else {
          currentConnection = CONN_NONE;
          gprsReady = false;
          Serial.println("❌ GPRS reconnect failed - will retry in 30 seconds");
        }
      }
    }
  }
  #else
  // SIM800L disabled - just mark as no connection
  if (currentConnection != CONN_NONE) {
    Serial.println("⚠️ WiFi disconnected (GPRS fallback disabled)");
    currentConnection = CONN_NONE;
    gprsReady = false;
  }
  #endif
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
  
  // Use manual HTTPS PUT - works with both WiFi and GPRS
  Serial.println("📡 Attempting HTTPS PUT to Firebase...");
  Serial.print("   Connection type: ");
  Serial.println(currentConnection == CONN_WIFI ? "WiFi" : (currentConnection == CONN_GPRS ? "GPRS" : "NONE"));
  
  bool connected = false;
  String response = "";
  
  if (currentConnection == CONN_WIFI) {
    // Use WiFi connection
    WiFiClientSecure client;
    client.setInsecure();  // Use TLS without certificate for simplicity
    
    if (client.connect(FIREBASE_HOST, 443)) {
      connected = true;
      
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
      
      Serial.println("   Sending PUT request via WiFi...");
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
      while (client.available()) {
        response += client.readString();
      }
      client.stop();
    }
  #if ENABLE_SIM800L
  } else if (currentConnection == CONN_GPRS && gprsReady) {
    // Use GPRS connection
    TinyGsmClientSecure client(modem);
    // TinyGsmClientSecure already skips certificate validation on SIM800
    
    if (client.connect(FIREBASE_HOST, 443)) {
      connected = true;
      
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
      
      Serial.println("   Sending PUT request via GPRS...");
      client.print(request);
      
      // Wait for response
      unsigned long start = millis();
      while (client.connected() && !client.available()) {
        if (millis() - start > 10000) {  // Longer timeout for GPRS
          Serial.println("⚠️ HTTP timeout waiting for GPRS response");
          client.stop();
          return;
        }
        delay(10);
      }
      
      // Read response
      while (client.available()) {
        response += client.readString();
      }
      client.stop();
    } else {
      Serial.println("❌ GPRS HTTPS connect failed");
    }
  #endif
  } else {
    Serial.println("❌ No active connection (WiFi" + String(ENABLE_SIM800L ? " or GPRS" : "") + ")");
    return;
  }
  
  // Check if successful (Firebase returns the data on success)
  if (connected && (response.indexOf("\"latitude\"") > 0 || response.indexOf("200 OK") > 0)) {
    Serial.println("✅✅✅ GPS SUCCESSFULLY UPDATED IN FIREBASE! ✅✅✅");
    Serial.print("   Via: ");
    Serial.println(currentConnection == CONN_WIFI ? "WiFi" : "GPRS");
    Serial.println("   Response: " + response.substring(0, 100));  // First 100 chars
  } else {
    Serial.println("❌❌❌ Firebase GPS update FAILED");
    Serial.println("   Response: " + response.substring(0, 200));  // First 200 chars
  }
}

void pollHardwareControl() {
  String url = String("/hardware_control.json?auth=") + FIREBASE_AUTH;
  Serial.println("🔍 HTTP GET " + url);
  Serial.print("   Connection type: ");
  Serial.println(currentConnection == CONN_WIFI ? "WiFi" : (currentConnection == CONN_GPRS ? "GPRS" : "NONE"));
  
  bool connected = false;
  String payload = "";
  
  if (currentConnection == CONN_WIFI) {
    // Use WiFi connection
    WiFiClientSecure client;
    client.setInsecure();  // use TLS without certificate for simplicity

    if (client.connect(FIREBASE_HOST, 443)) {
      connected = true;
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
      while (client.available()) {
        payload += client.readString();
      }
      client.stop();
    }
  #if ENABLE_SIM800L
  } else if (currentConnection == CONN_GPRS && gprsReady) {
    // Use GPRS connection
    TinyGsmClientSecure client(modem);
    // SIM800 TLS helper does not expose setInsecure; it already ignores cert chains

    if (client.connect(FIREBASE_HOST, 443)) {
      connected = true;
      client.printf("GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", url.c_str(), FIREBASE_HOST);

      // Wait for response headers
      unsigned long start = millis();
      while (client.connected() && !client.available()) {
        if (millis() - start > 10000) {  // Longer timeout for GPRS
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
      while (client.available()) {
        payload += client.readString();
      }
      client.stop();
    } else {
      Serial.println("❌ GPRS HTTPS connect failed");
    }
  #endif
  } else {
    Serial.println("❌ No active connection (WiFi" + String(ENABLE_SIM800L ? " or GPRS" : "") + ")");
    return;
  }
  
  if (!connected) {
    Serial.println("❌ HTTPS connect failed");
    return;
  }

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
  
  // Read language preference (default to "tagalog" if not set)
  String newLanguage = doc["language"] | "tagalog";
  if (newLanguage != userLanguage) {
    Serial.println("🌐 Language changed: " + userLanguage + " → " + newLanguage);
    userLanguage = newLanguage;
  }

  Serial.println("   motorEnabled = " + String(newMotorEnabled ? "true" : "false"));
  Serial.println("   ultrasonicEnabled = " + String(newUltrasonicEnabled ? "true" : "false"));
  Serial.println("   audioEnabled = " + String(newAudioEnabled ? "true" : "false"));
  Serial.println("   language = " + userLanguage);

    bool valuesChanged = (motorEnabled != newMotorEnabled || 
                         ultrasonicEnabled != newUltrasonicEnabled || 
                         audioEnabled != newAudioEnabled);
    
    motorEnabled = newMotorEnabled;
    ultrasonicEnabled = newUltrasonicEnabled;
    audioEnabled = newAudioEnabled;
    
    if (valuesChanged) {
      Serial.println("   ⚠️ Values changed!");
    }
    
  if (!motorEnabled) {
    motorStop();
    Serial.println("🛑 Motor stopped by Firebase control");
  }
    
  if (!audioEnabled && currentAudioState != 0) {
    player.stop();
    currentAudioState = 0;
    Serial.println("🔇 Audio stopped by Firebase control");
  }
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
  Serial.println("Starting system initialization...");
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

  // Ultrasonic pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  // Motor pins
  pinMode(ENA, OUTPUT);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  
  motorStop();

  // OLED init
  Wire.begin(21, 22);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("System Booting...");
  display.display();

  // DFPlayer init (initialize only, don't play yet - will play after language is read)
  dfSerial.begin(9600, SERIAL_8N1, 13, 14); //DF_RX, DF_TX
  if (player.begin(dfSerial)) {
    player.volume(30);
    dfPlayerReady = true;
    Serial.println("✅ DFPlayer initialized (will play startup audio after language is loaded)");
  } else {
    dfPlayerReady = false;
    Serial.println("❌ DFPlayer Error!");
  }

  // GPS init
  GPS_Serial.begin(9600, SERIAL_8N1, 5, 4);

  // SIM800L init (will be activated when WiFi is lost)
  #if ENABLE_SIM800L
  // Note: Install EspSoftwareSerial on ESP32 so SoftwareSerial works here
  Serial.println("📱 SIM800L ready (will activate if WiFi fails)");
  #else
  Serial.println("📱 SIM800L disabled (set ENABLE_SIM800L to 1 to enable)");
  #endif

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
    
    // Show WiFi status code every 5 attempts
    if (wifiAttempts % 5 == 0) {
      Serial.print(" [Status: ");
      Serial.print(WiFi.status());
      Serial.print("] ");
    }
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
    Serial.println("========================================");
    Serial.println("❌ WiFi Connection Failed!");
    Serial.println("========================================");
    Serial.print("   SSID: ");
    Serial.println(WIFI_SSID);
    Serial.print("   Password: ");
    Serial.println(WIFI_PASSWORD);
    Serial.print("   WiFi Status Code: ");
    int status = WiFi.status();
    Serial.println(status);
    Serial.print("   Status Meaning: ");
    switch(status) {
      case WL_IDLE_STATUS: Serial.println("WL_IDLE_STATUS - WiFi is in process of changing between statuses"); break;
      case WL_NO_SSID_AVAIL: Serial.println("WL_NO_SSID_AVAIL - SSID cannot be reached"); break;
      case WL_SCAN_COMPLETED: Serial.println("WL_SCAN_COMPLETED - Scan networks is completed"); break;
      case WL_CONNECTED: Serial.println("WL_CONNECTED - Connected to a WiFi network"); break;
      case WL_CONNECT_FAILED: Serial.println("WL_CONNECT_FAILED - Connection failed"); break;
      case WL_CONNECTION_LOST: Serial.println("WL_CONNECTION_LOST - Connection was lost"); break;
      case WL_DISCONNECTED: Serial.println("WL_DISCONNECTED - Disconnected from network"); break;
      default: Serial.println("Unknown status"); break;
    }
    Serial.println("   Possible causes:");
    Serial.println("   1. Wrong WiFi password");
    Serial.println("   2. WiFi network not in range");
    Serial.println("   3. WiFi router not broadcasting SSID");
    Serial.println("   4. ESP32 WiFi hardware issue");
    Serial.println("========================================");
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi Failed!");
    display.setCursor(0, 15);
    display.print("Status: ");
    display.print(status);
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
    
    // Read language preference from Firebase before playing startup audio
    Serial.println();
    Serial.println("🌐 Reading language preference from Firebase...");

    // Prefer direct Firebase read for language (more reliable at startup)
    String lang = "tagalog";
    if (Firebase.getString(firebaseHardwareData, "/hardware_control/language")) {
      lang = firebaseHardwareData.stringData();
      Serial.print("🌐 Language from Firebase (hardware_control): ");
      Serial.println(lang);
    } else {
      Serial.print("⚠️ Failed to read /hardware_control/language: ");
      Serial.println(firebaseHardwareData.errorReason());
      Serial.println("   Using default language: tagalog");
    }
    // Normalize and store language
    lang.toLowerCase();
    if (lang == "english") {
      userLanguage = "english";
    } else {
      userLanguage = "tagalog";
    }

    // Also refresh other hardware control flags (motor/audio, etc.)
    pollHardwareControl();
    
    // Now play startup audio with correct language
    if (dfPlayerReady) {
      int startupFile = getAudioFileNumber(1); // Get correct file based on language (001 or 004)
      player.playFolder(1, startupFile);
      startupAudioPlayed = true;
      startupAudioTime = millis();
      Serial.print("✅ DFPlayer: Playing startup audio ");
      Serial.print(startupFile < 10 ? "00" : "0");
      Serial.print(startupFile);
      Serial.print(".mp3 (");
      Serial.print(userLanguage);
      Serial.println(")");
    } else {
      Serial.println("⚠️ DFPlayer not ready, skipping startup audio");
    }
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Firebase OK!");
    display.display();
    delay(1000);
  } else {
    // WiFi/Firebase connection failed - play default Tagalog startup audio
    Serial.println();
    Serial.println("⚠️ WiFi/Firebase not connected - using default language (Tagalog)");
    userLanguage = "tagalog";
    if (dfPlayerReady) {
      int startupFile = getAudioFileNumber(1); // Will use default "tagalog" = 001.mp3
      player.playFolder(1, startupFile);
      startupAudioPlayed = true;
      startupAudioTime = millis();
      Serial.print("✅ DFPlayer: Playing startup audio ");
      Serial.print(startupFile < 10 ? "00" : "0");
      Serial.print(startupFile);
      Serial.print(".mp3 (default: ");
      Serial.print(userLanguage);
      Serial.println(")");
    } else {
      Serial.println("⚠️ DFPlayer not ready, skipping startup audio (no WiFi/Firebase)");
    }
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

  // Enable ultrasonic sensor only after startup audio grace period (7 seconds)
  static bool ultrasonicGraceLogPrinted = false;
  if (!ultrasonicEnabledAfterDelay) {
    unsigned long referenceTime = 0;
    if (startupAudioPlayed && startupAudioTime > 0) {
      referenceTime = startupAudioTime;
    } else if (startupTime > 0) {
      referenceTime = startupTime;
    }
    if (referenceTime > 0 && millis() - referenceTime > 7000) {
      ultrasonicEnabledAfterDelay = true;
      ultrasonicGraceLogPrinted = false;
      Serial.println("✅ Ultrasonic sensor re-enabled after startup grace period");
    } else if (!ultrasonicGraceLogPrinted) {
      Serial.println("⏳ Ultrasonic sensor paused for 7s startup grace period...");
      ultrasonicGraceLogPrinted = true;
    }
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
      Serial.println("✅ SYSTEM ACTIVE - ALL HARDWARE ENABLED");
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
  
  // Check if we have a valid connection
  bool hasConnection = (currentConnection == CONN_WIFI);
  #if ENABLE_SIM800L
  hasConnection = hasConnection || (currentConnection == CONN_GPRS && gprsReady);
  #endif
  
  if (systemReady && hasConnection && firebaseReady && gps.location.isValid()) {
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

  // ===================== Connection Management =====================
  // Check connection status periodically and switch between WiFi/GPRS
  if (millis() - lastConnectionCheck > CONNECTION_CHECK_INTERVAL) {
    checkConnectionStatus();
    lastConnectionCheck = millis();
  }

  // ===================== Firebase Hardware Control Check =====================
  // Check if we have a valid connection
  bool hasConnectionForHardware = (currentConnection == CONN_WIFI);
  #if ENABLE_SIM800L
  hasConnectionForHardware = hasConnectionForHardware || (currentConnection == CONN_GPRS && gprsReady);
  #endif
  
  if (systemReady && hasConnectionForHardware && firebaseReady) {
    if (millis() - lastHardwareCheck > 2000) {  // Check every 2 seconds
      pollHardwareControl();
      lastHardwareCheck = millis();
    }
  }

  // ===================== Ultrasonic Sensor Logic =====================
  // Calculate distance once (will be used for both logic and display)
  if (ultrasonicEnabled) {
    if (ultrasonicEnabledAfterDelay) {
      // Get distance with averaging for stability
      float rawDistance = getDistance();
      // Apply exponential moving average filter for smoother, more accurate readings
      // Now more responsive to actual distance changes
      distance = getFilteredDistance(rawDistance);
      
      // Ultrasonic sensors (HC-SR04) are not accurate below 2cm
      // Readings below 2cm are usually false readings or noise
      // BUT we still display them on OLED - just don't activate motor/audio
      if (distance >= MIN_VALID_DISTANCE && distance < MAX_VALID_DISTANCE) {
        // Valid distance reading
        Serial.print("📏 Distance: ");
        Serial.print(distance);
        Serial.println(" cm");
        
        // Audio control based on distance
        // NEW LOGIC: Audio plays ONLY when distance >= 50cm AND <= 100cm
        // Audio loops/continues as long as object is detected in this range
        // Gate audio so that startup voice (001/004) can finish first
        // Require: startupAudioPlayed == true AND at least 4 seconds since it started
        if (audioEnabled && startupAudioPlayed && millis() - startupAudioTime > 4000) {
          if (distance >= 50 && distance <= 100) {
            // Object detected in valid range (50-100cm) - play audio (005 or 006) and LOOP
            // Audio will continuously loop as long as object is detected in this range
            if (currentAudioState != 1) {
              int audioFile = getAudioFileNumber(3);  // Get correct file (003 or 006)
              player.stop();  // Stop any currently playing audio first
              delay(100);     // Small delay to ensure stop command is processed
              player.loop(audioFile);  // Loop the audio file continuously (file in folder 01)
              currentAudioState = 1;
              Serial.print("🔊 Looping ");
              Serial.print(audioFile < 10 ? "00" : "0");
              Serial.print(audioFile);
              Serial.print(".mp3 (object detected 50-100cm, ");
              Serial.print(userLanguage);
              Serial.println(") - will loop continuously while object detected");
            }
            // If audio is already looping, let it continue
          } else {
            // Object too close (< 50cm) or too far (> 100cm) - stop audio
            if (currentAudioState != 0) {
              player.stop();
              currentAudioState = 0;
              if (distance < 50) {
                Serial.println("🔇 Audio stopped (object too close < 50cm)");
              } else {
                Serial.println("🔇 Audio stopped (object too far > 100cm)");
              }
            }
          }
        }
        
        // Motor control based on distance ONLY
        // NEW LOGIC: Motor vibrates ONLY when distance >= 50cm AND <= 100cm
        // Motor stops when distance < 50cm (too close, ignore) or > 100cm (no object)
        if (!motorEnabled) {
          // Motor disabled in Firebase - always stop
          motorStop();
          motorPulseState = false;
        } else if (distance < 50) {
          // Object too close (< 50cm) - STOP motor (ignore close readings)
          motorStop();
          motorPulseState = false;
          static unsigned long lastStopLog = 0;
          if (millis() - lastStopLog > 2000) {  // Log every 2 seconds to avoid spam
            Serial.print("🔔 Motor: Stopped (distance ");
            Serial.print(distance);
            Serial.println("cm < 50cm - too close, ignoring)");
            lastStopLog = millis();
          }
        } else if (distance > 100) {
          // No object detected (distance > 100cm) - STOP motor immediately
          motorStop();
          motorPulseState = false;
          static unsigned long lastStopLog2 = 0;
          if (millis() - lastStopLog2 > 2000) {  // Log every 2 seconds to avoid spam
            Serial.print("🔔 Motor: Stopped (distance ");
            Serial.print(distance);
            Serial.println("cm > 100cm - no object)");
            lastStopLog2 = millis();
          }
        } else if (distance >= 50 && distance <= 100) {
          // Object detected in valid range (50-100cm) - VIBRATE
          // Fast pulse for this range
          unsigned long currentTime = millis();
          if (currentTime - lastMotorPulse >= 150) {  // Fast pulse every 150ms
            motorPulseState = !motorPulseState;
            digitalWrite(IN1, HIGH);
            digitalWrite(IN2, LOW);
            if (motorPulseState) {
              analogWrite(ENA, VIBRATION_MOTOR_PWM);
            } else {
              analogWrite(ENA, 0);
            }
            lastMotorPulse = currentTime;
          }
          static unsigned long lastVibrateLog = 0;
          if (millis() - lastVibrateLog > 2000) {  // Log every 2 seconds
            Serial.print("🔔 Motor: Fast pulse (distance ");
            Serial.print(distance);
            Serial.println("cm, 50-100cm range)");
            lastVibrateLog = millis();
          }
        } else {
          // Safety fallback: if distance is somehow not in expected range, stop motor
          motorStop();
          motorPulseState = false;
        }
      } else {
        // Invalid distance reading (distance < 2cm, <= 0, or >= 400cm) - NO OBJECT DETECTED
        // STOP motor immediately - this means no object is in range
        if (motorEnabled) {
          motorStop();
          motorPulseState = false;  // Reset pulse state
          if (distance > 0 && distance < MIN_VALID_DISTANCE) {
            Serial.print("🔔 Motor: Stopped (distance ");
            Serial.print(distance);
            Serial.println("cm < 2cm - false reading, no object)");
          } else {
            Serial.println("🔔 Motor: Stopped (invalid distance - no object detected)");
          }
        }
        if (audioEnabled && currentAudioState != 0) {
          player.stop();
          currentAudioState = 0;
          Serial.println("🔇 Audio stopped (invalid distance reading)");
        }
      }
    } else {
      // Waiting for grace period - keep outputs neutral
      distance = 0;
      filteredDistance = 0.0;  // Reset filtered distance
      motorStop();
      motorPulseState = false;  // Reset pulse state
      if (audioEnabled && currentAudioState != 0) {
        player.stop();
        currentAudioState = 0;
      }
    }
  } else {
    // Ultrasonic disabled - stop motor and audio if they were running
    distance = 0;  // Reset distance when disabled
    filteredDistance = 0.0;  // Reset filtered distance
    motorPulseState = false;  // Reset motor pulse state
    if (motorEnabled) {
      motorStop();
    }
    if (audioEnabled && currentAudioState != 0) {
      player.stop();
      currentAudioState = 0;
    }
  }

  // ===================== OLED Display =====================
  display.clearDisplay();
  
  // Show ultrasonic distance with LARGER text size (size 2) when enabled
  // ALWAYS show distance, even if invalid (< 2cm)
  if (ultrasonicEnabled) {
    if (distance > 0 && distance < 400) {  // Show any reading (including < 2cm)
      display.setTextSize(2);  // Larger text for distance
      display.setCursor(0, 0);
      display.print(distance, 1);
      display.setTextSize(1);  // Smaller text for unit
      display.print(" CM");
    } else {
      // Completely invalid (0 or >= 400) - show "---"
      display.setTextSize(2);
      display.setCursor(0, 0);
      display.print("---");
      display.setTextSize(1);
      display.print(" CM");
    }
  }
  // If ultrasonic disabled, show nothing (leave blank)
  
  // Reset text size to 1 for other displays
  display.setTextSize(1);
  
  // Connection status (WiFi/GPRS) and Firebase status
  bool wifiConnected = WiFi.status() == WL_CONNECTED;
  #if ENABLE_SIM800L
  bool gprsConnected = (currentConnection == CONN_GPRS && gprsReady);
  #endif

  display.setCursor(0, 15);
  display.print("WiFi:");
  display.print(wifiConnected ? "OK" : "NO");

  display.setCursor(64, 15);
  display.print("FB:");
  display.print(firebaseReady ? "OK" : "NO");

  #if ENABLE_SIM800L
  display.setCursor(0, 27);
  display.print("GPRS:");
  display.print(gprsConnected ? "OK" : "NO");
  #endif
  
  // GPS Satellites and Fix status
  display.setCursor(0, 40);
  display.print("Sats: ");
  display.print(gps.satellites.value());
  if (gps.location.isValid()) {
    display.print(" FIX");
  } else {
    display.print(" ---");
  }
  
  display.display();
  delay(200);
}

