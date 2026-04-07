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

// ===================== Battery Monitoring Setup (TP4056 Module) =====================
// Battery voltage monitoring pin
// 
// AVAILABLE ADC1 PINS FOR BATTERY MONITORING:
// - GPIO36 (ADC1_CH0) - if available
// - GPIO39 (ADC1_CH3) - RECOMMENDED ALTERNATIVE
// - GPIO34 (ADC1_CH6) - alternative
// - GPIO35 (ADC1_CH7) - alternative
// 
// WIRING INSTRUCTIONS FOR TP4056 MODULE:
// 1. Connect TP4056 BAT+ (battery positive) to your battery positive
// 2. Connect TP4056 BAT- (battery negative) to your battery negative and ESP32 GND
// 3. Create voltage divider circuit:
//    BAT+ → [R1: 10kΩ] → GPIO39 (or your chosen pin) → [R2: 10kΩ] → GND
//    This divides voltage by 2, so max readable = 6.6V (ESP32 ADC max = 3.3V)
// 4. TP4056 OUT+ → ESP32 VIN (5V) or 3.3V pin (if using regulator)
// 5. TP4056 OUT- → ESP32 GND
//
// NOTE: If using powerbank with USB output:
// - Connect USB output to TP4056 IN+ and IN- (for charging)
// - Or use TP4056 to charge a separate battery that powers ESP32
//
#define BATTERY_ADC_PIN 35  // GPIO35 (ADC1_CHANNEL_7) - User's wiring
#define BATTERY_R1 10000.0  // Voltage divider R1 (10kΩ)
#define BATTERY_R2 10000.0  // Voltage divider R2 (10kΩ)
#define BATTERY_VOLTAGE_DIVIDER (BATTERY_R1 + BATTERY_R2) / BATTERY_R2  // = 2.0
#define BATTERY_FULL_VOLTAGE 4.2  // Full battery voltage (for Li-ion/LiPo - typical for TP4056)
#define BATTERY_EMPTY_VOLTAGE 3.0  // Empty battery voltage (cutoff for Li-ion)

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
// COIN VIBRATION MOTOR (like smartphone vibration)
// Coin motors typically need higher PWM or direct ON/OFF
// If using L298N: PWM 180-255 works better for coin motors
// If using direct drive (transistor/MOSFET): Use digital ON/OFF or PWM 200-255
#define VIBRATION_MOTOR_PWM 200  // Increased for coin motor (was 90, now 200 for better response)
#define USE_COIN_MOTOR_MODE 1    // Set to 1 for coin motor (higher PWM), 0 for regular DC motor

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
// WiFi Fallback System: Tries networks in order (Primary → Fallback)
// Structure: {SSID, Password, Description}
struct WiFiNetwork {
  const char* ssid;
  const char* password;
  const char* description;
};

// Define WiFi networks in priority order (tries first network, then second if first fails)
const WiFiNetwork wifiNetworks[] = {
  {"Ao/Hr", "@AoHR_employee@spcc2024", "Primary WiFi (Ao/Hr)"},           // Primary: Ao/Hr WiFi
  {"iPhone", "elle2025", "Fallback Hotspot (iPhone - Phone Data)"}        // Fallback: iPhone hotspot (uses phone data)
};

const int wifiNetworkCount = sizeof(wifiNetworks) / sizeof(wifiNetworks[0]);



// ===================== Firebase Configuration =====================
// Note: Use the database URL without https:// and without trailing slash
#define FIREBASE_HOST "login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW"

// ===================== EMAIL (Gmail SMTP) =====================
// Use a Gmail App Password (NOT your normal Gmail password).
// Google Account → Security → 2-Step Verification → App passwords.
// Paste your credentials here.
#define GMAIL_SMTP_HOST "smtp.gmail.com"
#define GMAIL_SMTP_PORT 465
#define GMAIL_USER "PASTE_YOUR_GMAIL_HERE"           // e.g. "yourname@gmail.com"
#define GMAIL_APP_PASSWORD "PASTE_APP_PASSWORD_HERE" // 16-char app password (no spaces)

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
double lastKnownLat = 0.0, lastKnownLon = 0.0;
bool hasLastKnownLocation = false;
long duration;
float distance;
float filteredDistance = 0.0;  // Filtered/averaged distance for stability
int currentAudioState = 0;          // 0 = none, 1 = detection audio playing (varies by category)
bool dfPlayerReady = false;         // Track if DFPlayer is initialized and ready
bool oledReady = false;              // Track if OLED display is initialized and ready
bool startupAudioPlayed = false;    // Track if startup audio (001/004) has been played
bool startupAudioInitialized = false; // Guard to prevent duplicate audio playback
unsigned long startupAudioTime = 0; // When startup audio started (for timing/gating)
bool ultrasonicEnabledAfterDelay = false; // Prevent ultrasonic from running during startup audio
unsigned long lastMotorPulse = 0;   // Timing for fast pulsing at 100cm
bool motorPulseState = false;       // Current state for fast pulsing (on/off toggle)

// Battery monitoring variables
float batteryVoltage = 0.0;         // Current battery voltage
int batteryPercentage = 0;          // Battery percentage (0-100)
unsigned long lastBatteryCheck = 0; // Last time battery was checked
const unsigned long BATTERY_CHECK_INTERVAL = 5000; // Check battery every 5 seconds

unsigned long startupTime;
bool systemReady = false;

// ===================== Firebase Control Variables =====================
unsigned long lastGPSUpdate = 0;
unsigned long lastValidGpsFixMs = 0;
unsigned long lastGpsAlertSendMs = 0;
bool gpsLostAlertActive = false;
unsigned long lastHardwareCheck = 0;
unsigned long lastRestartTime = 0;  // Track when we last restarted to prevent restart loops
bool motorEnabled = false;        // Default to disabled until profiling enables it
bool ultrasonicEnabled = false;   // Default to disabled until profiling enables it
bool audioEnabled = false;        // Default to disabled until profiling enables it
String userLanguage = "tagalog";  // Default language: "tagalog", "english", "filipino", or "none"
String usageLocation = "outdoors"; // "indoors" or "outdoors" - affects sensing distance
String vibrationIntensity = "medium"; // "low", "medium", "high" - affects motor PWM
String volume = "medium"; // "low", "medium", "high" - affects audio volume
unsigned long lastLanguageCheck = 0;  // Track when we last checked language preference

// Elderly category behaviors (from profiling)
String userCategory = ""; // "elderly" or "high-risk"
double elderlySensorRange = 50.0; // Sensor range from elderly profiling (50, 70, or 100 cm)
String scanningMode = "event-based"; // "continuous", "semi-continuous", or "event-based"
String vibrationMode = "soft_pulse"; // "strong_repeated", "normal_pulse", or "soft_pulse"
int alertCooldown = 3; // Alert cooldown in seconds (1, 2, or 3)
bool indoorMode = false; // Indoor mode flag
int alertRepetition = 2; // Alert repetition (1 = LOW, 2 = Standard)
int voiceDelay = 1000; // Voice delay in milliseconds (3000 = longer, 1000 = standard)
unsigned long lastProfilingCheck = 0; // Track when we last checked profiling data

// High-risk category behaviors (from profiling)
String sensorAngle = "forward"; // "upward", "downward", or "forward"
String detectionLevel = ""; // "head_chest" for upward angle
bool voiceRepeat = false; // Voice repeat mode (for continuous assistance)
bool depthDetection = false; // Depth detection mode (for terrain)
bool terrainVoiceWarning = false; // H5: Terrain voice warning enabled (for terrain audio file selection)

// Dynamic settings based on Firebase preferences
// Initialize PWM based on coin motor mode
#if USE_COIN_MOTOR_MODE
int currentVibrationPWM = 200;  // Default for coin motor
#else
int currentVibrationPWM = VIBRATION_MOTOR_PWM; // Default for regular motor
#endif
float sensingDistanceMin = 50.0;  // Minimum distance for detection (adjusted based on usageLocation)
float sensingDistanceMax = 100.0; // Maximum distance for detection (adjusted based on usageLocation)
int audioVolume = 20; // DFPlayer volume (0-30, adjusted based on volume preference)

// ===================== GPS LOST ALERT SETTINGS =====================
String ownerUid = ""; // Set from /hardware_control/ownerUid by the app
const unsigned long GPS_LOST_THRESHOLD_MS = 60000;   // 60s without valid fix
const unsigned long GPS_ALERT_COOLDOWN_MS = 300000;  // 5 minutes between alerts
const int MAX_EMERGENCY_EMAILS = 3;
String emergencyEmails[MAX_EMERGENCY_EMAILS];
int emergencyEmailCount = 0;

// ===================== GPS LOST ALERT SENDER CREDS (from Firebase) =====================
// If set in Firebase, ESP32 uses these instead of the #define values above.
String senderGmail = "";
String senderAppPassword = "";
unsigned long lastSenderCredsLoadMs = 0;
const unsigned long SENDER_CREDS_REFRESH_MS = 300000; // refresh every 5 minutes (WiFi only)

// ===================== GPS Update Interval =====================
// GPS update frequency to Firebase (for real-time tracking on Google Maps)
// Options:
//   1000 = 1 second (recommended - real-time, GPS modules update at 1Hz)
//   100  = 0.1 seconds (very fast, may overload Firebase, GPS may not update this fast)
//   5000 = 5 seconds (original - less frequent, saves data/bandwidth)
const unsigned long GPS_UPDATE_INTERVAL = 1000;  // Update every 1 second (real-time)

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

// ===================== Battery Monitoring Functions =====================
void readBatteryVoltage() {
  // Read ADC value (0-4095 for 12-bit ADC on ESP32)
  int adcValue = analogRead(BATTERY_ADC_PIN);
  
  // Debug: Log raw ADC reading occasionally
  static unsigned long lastADCDebug = 0;
  if (millis() - lastADCDebug > 10000) {  // Log every 10 seconds
    Serial.print("🔋 Raw ADC Reading (GPIO");
    Serial.print(BATTERY_ADC_PIN);
    Serial.print("): ");
    Serial.print(adcValue);
    Serial.print(" / 4095");
    lastADCDebug = millis();
  }
  
  // Convert ADC value to voltage (0-3.3V range)
  float adcVoltage = (adcValue / 4095.0) * 3.3;
  
  // Apply voltage divider correction (if using voltage divider circuit)
  batteryVoltage = adcVoltage * BATTERY_VOLTAGE_DIVIDER;
  
  // Calculate battery percentage based on voltage
  // For Li-ion/LiPo: Full = 4.2V, Empty = 3.0V
  if (batteryVoltage >= BATTERY_FULL_VOLTAGE) {
    batteryPercentage = 100;
  } else if (batteryVoltage <= BATTERY_EMPTY_VOLTAGE) {
    batteryPercentage = 0;
  } else {
    // Linear interpolation between empty and full
    float voltageRange = BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE;
    float voltageAboveEmpty = batteryVoltage - BATTERY_EMPTY_VOLTAGE;
    batteryPercentage = (int)((voltageAboveEmpty / voltageRange) * 100.0);
    // Clamp to 0-100
    if (batteryPercentage > 100) batteryPercentage = 100;
    if (batteryPercentage < 0) batteryPercentage = 0;
  }
  
  // Log battery status (every check)
  Serial.print("🔋 Battery: ");
  Serial.print(batteryVoltage, 2);
  Serial.print("V (");
  Serial.print(batteryPercentage);
  Serial.print("%) | ADC: ");
  Serial.print(adcValue);
  Serial.print(" | ADC Voltage: ");
  Serial.print(adcVoltage, 2);
  Serial.println("V");
  
  // Warning if battery reading seems wrong
  if (adcValue == 0 && batteryPercentage == 0) {
    static unsigned long lastWarning = 0;
    if (millis() - lastWarning > 30000) {  // Warn every 30 seconds
      Serial.println("⚠️ WARNING: Battery ADC reading is 0! Check wiring:");
      Serial.print("   - GPIO");
      Serial.print(BATTERY_ADC_PIN);
      Serial.println(" should be connected to voltage divider");
      Serial.println("   - Verify voltage divider circuit: BAT+ → [R1: 10kΩ] → GPIO35 → [R2: 10kΩ] → GND");
      lastWarning = millis();
    }
  }
}

// Motor test function - call this to test if motor is working
void testMotor() {
  Serial.println("========================================");
  Serial.println("🧪 TESTING VIBRATION MOTOR");
  Serial.println("========================================");
  Serial.print("   Motor Type: ");
  Serial.println(USE_COIN_MOTOR_MODE ? "COIN MOTOR" : "REGULAR DC MOTOR");
  Serial.print("   Current PWM: ");
  Serial.print(currentVibrationPWM);
  Serial.println("/255");
  Serial.println("   Testing motor for 3 seconds...");
  
  // Test 1: Low intensity
  Serial.println("   Test 1: Low intensity (PWM 150)...");
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  analogWrite(ENA, 150);
  delay(1000);
  analogWrite(ENA, 0);
  delay(500);
  
  // Test 2: Medium intensity
  Serial.println("   Test 2: Medium intensity (PWM 200)...");
  analogWrite(ENA, 200);
  delay(1000);
  analogWrite(ENA, 0);
  delay(500);
  
  // Test 3: High intensity
  Serial.println("   Test 3: High intensity (PWM 255)...");
  analogWrite(ENA, 255);
  delay(1000);
  analogWrite(ENA, 0);
  
  // Test 4: Pulse pattern
  Serial.println("   Test 4: Pulse pattern (5 pulses)...");
  for (int i = 0; i < 5; i++) {
    analogWrite(ENA, currentVibrationPWM);
    delay(200);
    analogWrite(ENA, 0);
    delay(200);
  }
  
  motorStop();
  Serial.println("✅ Motor test complete!");
  Serial.println("   Did you feel vibration? If NO, check:");
  Serial.println("   1. Wiring (ENA, IN1, IN2)");
  Serial.println("   2. Power supply to L298N");
  Serial.println("   3. Motor connected to L298N output");
  Serial.println("   4. Try increasing PWM values if too weak");
  Serial.println("========================================");
}

void motorForwardContinuous() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  // Using dynamic PWM based on vibration intensity preference
  analogWrite(ENA, currentVibrationPWM);
}

void motorPulse() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  // Using dynamic PWM based on vibration intensity preference
  analogWrite(ENA, currentVibrationPWM);
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
    analogWrite(ENA, currentVibrationPWM);
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
        analogWrite(ENA, currentVibrationPWM);
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

// ===================== Battery Icon Drawing Function =====================
// Draws a LARGE battery icon on OLED display based on battery percentage
// Icon: Horizontal battery with rounded terminal on the right
// Position: x, y coordinates on screen
// Size: width and height of battery body
void drawBatteryIcon(int x, int y, int width, int height, int percentage) {
  // Clamp percentage to 0-100
  if (percentage < 0) percentage = 0;
  if (percentage > 100) percentage = 100;
  
  // Battery body (rectangle) - thicker border for large icon
  display.drawRect(x, y, width, height, SSD1306_WHITE);
  display.drawRect(x + 1, y + 1, width - 2, height - 2, SSD1306_WHITE); // Double border for visibility
  
  // Battery terminal (small rounded rectangle on the right)
  int terminalWidth = 4;  // Increased for larger battery
  int terminalHeight = height / 3;  // Proportional terminal
  int terminalX = x + width;
  int terminalY = y + (height - terminalHeight) / 2;
  display.fillRect(terminalX, terminalY, terminalWidth, terminalHeight, SSD1306_WHITE);
  
  // Battery fill (based on percentage) - with padding for border
  int borderPadding = 3;  // Thicker border for large icon
  int fillWidth = (width - (borderPadding * 2)) * percentage / 100;
  
  // Always draw the battery outline, fill only if percentage > 0
  if (fillWidth > 0) {
    display.fillRect(x + borderPadding, y + borderPadding, fillWidth, height - (borderPadding * 2), SSD1306_WHITE);
  }
  
  // Debug: Log battery icon drawing (occasionally)
  static unsigned long lastIconDebug = 0;
  if (millis() - lastIconDebug > 10000) {  // Log every 10 seconds
    Serial.print("🔋 Drawing battery icon: ");
    Serial.print(percentage);
    Serial.print("% at (");
    Serial.print(x);
    Serial.print(",");
    Serial.print(y);
    Serial.print(") size ");
    Serial.print(width);
    Serial.print("x");
    Serial.print(height);
    Serial.print(", fillWidth=");
    Serial.println(fillWidth);
    lastIconDebug = millis();
  }
}

// ===================== Audio Language Helper =====================
// Maps audio file numbers based on language preference
// Tagalog/Filipino: 001, 002, 003
// English: 004, 005, 006
// Returns 0 if language is "none" (no audio)
int getAudioFileNumber(int baseFile) {
  // baseFile should be 1, 2, or 3 (for Tagalog files 001, 002, 003)
  if (userLanguage == "none") {
    // No audio - return 0
    return 0;
  } else if (userLanguage == "english") {
    // English files: 004, 005, 006 (baseFile + 3)
    return baseFile + 3;
  } else {
    // Tagalog/Filipino files: 001, 002, 003 (default)
    // "filipino" is treated the same as "tagalog"
    return baseFile;
  }
}

// ===================== New Audio File Selection =====================
// Returns the correct audio file number based on category and settings
// NEW MAPPING:
// Elderly E7="Oo": 009 (Tagalog) or 0014 (English) - "may harang" / "There is an Obstacle"
// Elderly E7="Hindi": 0010 (Tagalog) or 0015 (English) - "babala malapit na ang harang" / "Warning: obstacle approaching"
// High-risk H1="Oo": 002 (Tagalog) or 005 (English) - Head-level warning (no change)
// High-risk H5="Oo" + H1="Hindi": 0012 (Tagalog) or 0017 (English) - "babala, may lalim sa unahan" / "Warning: there's a drop ahead"
int getDetectionAudioFile() {
  if (userLanguage == "none") {
    return 0;  // No audio
  }
  
  // Elderly category
  if (userCategory == "elderly") {
    if (alertRepetition == 1) {
      // E7 = "Oo" (Gets tired easily) - LOW repetition
      return (userLanguage == "english") ? 14 : 9;  // 0014.mp3 (English) or 009.mp3 (Tagalog)
    } else {
      // E7 = "Hindi" (Doesn't get tired easily) - Standard repetition
      return (userLanguage == "english") ? 15 : 10;  // 0015.mp3 (English) or 0010.mp3 (Tagalog)
    }
  }
  
  // High-risk category
  if (userCategory == "high-risk") {
    if (detectionLevel == "head_chest") {
      // H1 = "Oo" (Head-level obstacles) - Keep using 002/005
      return (userLanguage == "english") ? 5 : 2;  // 005.mp3 (English) or 002.mp3 (Tagalog)
    } else if (terrainVoiceWarning || depthDetection) {
      // H5 = "Oo" + H1 = "Hindi" (Terrain warnings)
      // Use terrainVoiceWarning if available, otherwise use depthDetection as fallback
      return (userLanguage == "english") ? 17 : 12;  // 0017.mp3 (English) or 0012.mp3 (Tagalog)
    } else {
      // Default fallback (shouldn't happen, but just in case)
      return (userLanguage == "english") ? 5 : 2;  // 005.mp3 (English) or 002.mp3 (Tagalog)
    }
  }
  
  // Default fallback (no category detected yet)
  return (userLanguage == "english") ? 5 : 2;  // 005.mp3 (English) or 002.mp3 (Tagalog)
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

// --- Base64 helper (SMTP auth) ---
static const char* _b64 =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

String base64Encode(const String& in) {
  const uint8_t* bytes = (const uint8_t*)in.c_str();
  int len = in.length();
  String out;
  out.reserve(((len + 2) / 3) * 4);
  for (int i = 0; i < len; i += 3) {
    int v = bytes[i];
    v = i + 1 < len ? (v << 8) | bytes[i + 1] : (v << 8);
    v = i + 2 < len ? (v << 8) | bytes[i + 2] : (v << 8);

    out += _b64[(v >> 18) & 0x3F];
    out += _b64[(v >> 12) & 0x3F];
    out += (i + 1 < len) ? _b64[(v >> 6) & 0x3F] : '=';
    out += (i + 2 < len) ? _b64[v & 0x3F] : '=';
  }
  return out;
}

bool putJsonToFirebasePath(const String& pathWithAuth, const String& jsonPayload) {
  bool connected = false;
  String response = "";

  if (currentConnection == CONN_WIFI) {
    WiFiClientSecure client;
    client.setInsecure();
    if (client.connect(FIREBASE_HOST, 443)) {
      connected = true;
      String request = "PUT " + pathWithAuth + " HTTP/1.1\r\n";
      request += "Host: " + String(FIREBASE_HOST) + "\r\n";
      request += "Content-Type: application/json\r\n";
      request += "Content-Length: " + String(jsonPayload.length()) + "\r\n";
      request += "Connection: close\r\n\r\n";
      request += jsonPayload;
      client.print(request);

      unsigned long start = millis();
      while (client.connected() && !client.available()) {
        if (millis() - start > 5000) {
          client.stop();
          return false;
        }
        delay(10);
      }
      while (client.available()) response += client.readString();
      client.stop();
    }
#if ENABLE_SIM800L
  } else if (currentConnection == CONN_GPRS && gprsReady) {
    TinyGsmClientSecure client(modem);
    if (client.connect(FIREBASE_HOST, 443)) {
      connected = true;
      String request = "PUT " + pathWithAuth + " HTTP/1.1\r\n";
      request += "Host: " + String(FIREBASE_HOST) + "\r\n";
      request += "Content-Type: application/json\r\n";
      request += "Content-Length: " + String(jsonPayload.length()) + "\r\n";
      request += "Connection: close\r\n\r\n";
      request += jsonPayload;
      client.print(request);

      unsigned long start = millis();
      while (client.connected() && !client.available()) {
        if (millis() - start > 10000) {
          client.stop();
          return false;
        }
        delay(10);
      }
      while (client.available()) response += client.readString();
      client.stop();
    }
#endif
  }

  return connected && (response.indexOf("200 OK") > 0 || response.indexOf("{") >= 0);
}

String getJsonFromFirebasePath(const String& pathWithAuth) {
  if (currentConnection != CONN_WIFI) {
    // Keep SMTP + reads WiFi-only for simplicity and reliability.
    return "";
  }

  WiFiClientSecure client;
  client.setInsecure();
  if (!client.connect(FIREBASE_HOST, 443)) return "";

  client.printf("GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n",
                pathWithAuth.c_str(), FIREBASE_HOST);

  unsigned long start = millis();
  while (client.connected() && !client.available()) {
    if (millis() - start > 5000) {
      client.stop();
      return "";
    }
    delay(10);
  }

  // Skip headers
  while (client.available()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") break;
  }

  String body;
  while (client.available()) {
    body += client.readString();
  }
  client.stop();
  body.trim();
  return body;
}

bool loadEmergencyEmailsFromFirebase() {
  emergencyEmailCount = 0;
  if (!firebaseReady) return false;
  if (ownerUid.length() == 0) return false;

  String path = "/users/" + ownerUid + "/emergency_contacts/emails.json?auth=" + String(FIREBASE_AUTH);
  String body = getJsonFromFirebasePath(path);
  if (body.length() == 0 || body == "null") return false;

  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    Serial.print("⚠️ Failed to parse emergency emails JSON: ");
    Serial.println(err.c_str());
    return false;
  }

  if (!doc.is<JsonArray>()) return false;

  JsonArray arr = doc.as<JsonArray>();
  for (JsonVariant v : arr) {
    if (emergencyEmailCount >= MAX_EMERGENCY_EMAILS) break;
    String e = v.as<String>();
    e.trim();
    if (e.length() == 0) continue;
    emergencyEmails[emergencyEmailCount++] = e;
  }

  return emergencyEmailCount > 0;
}

bool loadSenderCredsFromFirebase() {
  senderGmail = "";
  senderAppPassword = "";
  lastSenderCredsLoadMs = millis();

  if (!firebaseReady) return false;
  if (ownerUid.length() == 0) return false;

  // Canonical path (only one the app writes): `/users/{uid}/gps_email_sender/smtp_sender`
  String path =
      "/users/" + ownerUid + "/gps_email_sender/smtp_sender.json?auth=" + String(FIREBASE_AUTH);
  String body = getJsonFromFirebasePath(path);
  // Legacy fallback only: flat `/users/{uid}/gps_email_sender` (remove after DB cleanup)
  if (body.length() == 0 || body == "null") {
    path = "/users/" + ownerUid + "/gps_email_sender.json?auth=" + String(FIREBASE_AUTH);
    body = getJsonFromFirebasePath(path);
  }
  if (body.length() == 0 || body == "null") return false;

  StaticJsonDocument<384> doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    Serial.print("⚠️ Failed to parse sender creds JSON: ");
    Serial.println(err.c_str());
    return false;
  }
  if (!doc.is<JsonObject>()) return false;

  // Support both keys: `email` (current) and `gmail` (older).
  String g = doc["email"] | "";
  if (g.length() == 0) g = doc["gmail"] | "";
  String pw = doc["appPassword"] | "";
  g.trim();
  pw.trim();
  pw.replace(" ", "");
  if (g.length() == 0 || pw.length() == 0) return false;

  senderGmail = g;
  senderAppPassword = pw;
  return true;
}

bool smtpReadUntilCode(WiFiClientSecure& client, const char* code, unsigned long timeoutMs = 10000) {
  String line;
  unsigned long start = millis();
  while (millis() - start < timeoutMs) {
    while (client.available()) {
      line = client.readStringUntil('\n');
      line.trim();
      if (line.length() == 0) continue;
      // Multi-line responses start with "XYZ-" then end with "XYZ "
      if (line.startsWith(code)) return true;
      if (line.length() >= 4 && line.substring(0, 3) == String(code) && line.charAt(3) == ' ') return true;
    }
    delay(10);
  }
  return false;
}

bool smtpSendLine(WiFiClientSecure& client, const String& s) {
  client.print(s);
  client.print("\r\n");
  return true;
}

bool sendEmailViaGmailSMTP(const String& toEmail, const String& subject, const String& bodyText) {
  // Prefer per-owner credentials from Firebase, fallback to compile-time defines.
  String fromUser = senderGmail;
  String fromPw = senderAppPassword;
  if (fromUser.length() == 0 || fromPw.length() == 0) {
    fromUser = String(GMAIL_USER);
    fromPw = String(GMAIL_APP_PASSWORD);
  }
  if (fromUser.indexOf("PASTE_") == 0 || fromPw.indexOf("PASTE_") == 0) {
    Serial.println("❌ Gmail credentials not set (set in app settings or edit GMAIL_USER / GMAIL_APP_PASSWORD).");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();
  if (!client.connect(GMAIL_SMTP_HOST, GMAIL_SMTP_PORT)) {
    Serial.println("❌ SMTP connect failed");
    return false;
  }

  if (!smtpReadUntilCode(client, "220")) {
    Serial.println("❌ SMTP: no 220 greeting");
    client.stop();
    return false;
  }

  smtpSendLine(client, "EHLO esp32");
  if (!smtpReadUntilCode(client, "250")) {
    Serial.println("❌ SMTP: EHLO failed");
    client.stop();
    return false;
  }

  smtpSendLine(client, "AUTH LOGIN");
  if (!smtpReadUntilCode(client, "334")) {
    Serial.println("❌ SMTP: AUTH LOGIN not accepted");
    client.stop();
    return false;
  }

  smtpSendLine(client, base64Encode(fromUser));
  if (!smtpReadUntilCode(client, "334")) {
    Serial.println("❌ SMTP: username rejected");
    client.stop();
    return false;
  }

  smtpSendLine(client, base64Encode(fromPw));
  if (!smtpReadUntilCode(client, "235")) {
    Serial.println("❌ SMTP: password rejected (use App Password)");
    client.stop();
    return false;
  }

  smtpSendLine(client, "MAIL FROM:<" + fromUser + ">");
  if (!smtpReadUntilCode(client, "250")) {
    Serial.println("❌ SMTP: MAIL FROM failed");
    client.stop();
    return false;
  }

  smtpSendLine(client, "RCPT TO:<" + toEmail + ">");
  if (!smtpReadUntilCode(client, "250")) {
    Serial.println("❌ SMTP: RCPT TO failed");
    client.stop();
    return false;
  }

  smtpSendLine(client, "DATA");
  if (!smtpReadUntilCode(client, "354")) {
    Serial.println("❌ SMTP: DATA failed");
    client.stop();
    return false;
  }

  // RFC822 message
  client.print("From: Logon Cane <");
  client.print(fromUser);
  client.print(">\r\n");
  client.print("To: <");
  client.print(toEmail);
  client.print(">\r\n");
  client.print("Subject: ");
  client.print(subject);
  client.print("\r\n");
  client.print("Content-Type: text/plain; charset=utf-8\r\n");
  client.print("\r\n");
  client.print(bodyText);
  client.print("\r\n.\r\n");

  if (!smtpReadUntilCode(client, "250")) {
    Serial.println("❌ SMTP: message not accepted");
    client.stop();
    return false;
  }

  smtpSendLine(client, "QUIT");
  client.stop();
  return true;
}

void sendGpsLostAlertIfNeeded() {
  if (!firebaseReady) return;
  if (ownerUid.length() == 0) return;
  if (!hasLastKnownLocation) return;
  if (gpsLostAlertActive) return;
  if (millis() - lastValidGpsFixMs < GPS_LOST_THRESHOLD_MS) return;
  if (millis() - lastGpsAlertSendMs < GPS_ALERT_COOLDOWN_MS) return;

  // Refresh sender credentials occasionally (WiFi only).
  if (currentConnection == CONN_WIFI &&
      (lastSenderCredsLoadMs == 0 || millis() - lastSenderCredsLoadMs > SENDER_CREDS_REFRESH_MS)) {
    loadSenderCredsFromFirebase();
  }

  Serial.println("📨 GPS lost detected. Loading emergency emails...");
  if (!loadEmergencyEmailsFromFirebase()) {
    Serial.println("⚠️ No emergency emails found in Firebase. Skipping SMTP send.");
  } else {
    String mapsLink = "https://www.google.com/maps?q=" + String(lastKnownLat, 6) + "," + String(lastKnownLon, 6);
    String subject = "Logon cane alert: GPS signal lost";
    String text =
      "The cane device reported GPS signal loss.\n\n"
      "Last known location:\n"
      "Latitude: " + String(lastKnownLat, 6) + "\n"
      "Longitude: " + String(lastKnownLon, 6) + "\n\n"
      "Open in Google Maps:\n" + mapsLink + "\n\n"
      "If needed, copy-paste the coordinates into Google Maps.\n";

    Serial.print("📧 Sending email to ");
    Serial.print(emergencyEmailCount);
    Serial.println(" recipient(s)...");

    bool anyOk = false;
    for (int i = 0; i < emergencyEmailCount; i++) {
      Serial.print("   -> ");
      Serial.println(emergencyEmails[i]);
      bool ok = sendEmailViaGmailSMTP(emergencyEmails[i], subject, text);
      Serial.println(ok ? "   ✅ Sent" : "   ❌ Failed");
      anyOk = anyOk || ok;
      delay(300);
    }

    if (anyOk) {
      gpsLostAlertActive = true;
      lastGpsAlertSendMs = millis();
      Serial.println("✅ GPS-lost email alert sent (cooldown started).");
    } else {
      Serial.println("❌ All SMTP sends failed.");
    }
  }
}

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
  lastKnownLat = lat_val;
  lastKnownLon = lon_val;
  hasLastKnownLocation = true;
  lastValidGpsFixMs = millis();
  gpsLostAlertActive = false;
  
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

  // Read motorEnabled - explicitly check if false is set (not just default)
  // Read motorEnabled - explicitly check if false is set (not just default)
  bool newMotorEnabled = motorEnabled; // Default to current value
  if (doc.containsKey("motorEnabled")) {
    newMotorEnabled = doc["motorEnabled"].as<bool>();
  }
  
  // Read ultrasonicEnabled - explicitly check
  bool newUltrasonicEnabled = ultrasonicEnabled; // Default to current value
  if (doc.containsKey("ultrasonicEnabled")) {
    newUltrasonicEnabled = doc["ultrasonicEnabled"].as<bool>();
  }
  
  // Read audioEnabled - explicitly check if false is set (CRITICAL: must respect false values)
  bool newAudioEnabled = audioEnabled; // Default to current value
  if (doc.containsKey("audioEnabled")) {
    newAudioEnabled = doc["audioEnabled"].as<bool>();
    // Explicitly log when audio is disabled
    if (!newAudioEnabled) {
      Serial.println("🔇 Audio explicitly DISABLED in Firebase (audioEnabled = false)");
    }
  }
  
  // Read language preference (default to "tagalog" if not set)
  String newLanguage = "tagalog";  // Default
  if (doc.containsKey("language")) {
    newLanguage = doc["language"].as<String>();
  }
  // Normalize to lowercase and handle variations
  newLanguage.toLowerCase();
  if (newLanguage == "english") {
    newLanguage = "english";
  } else if (newLanguage == "filipino" || newLanguage == "tagalog") {
    newLanguage = "tagalog";  // Treat filipino same as tagalog
  } else if (newLanguage == "none") {
    newLanguage = "none";
  } else {
    newLanguage = "tagalog";  // Default fallback
  }
  
  if (newLanguage != userLanguage) {
    Serial.println("🌐 Language changed: " + userLanguage + " → " + newLanguage);
    userLanguage = newLanguage;
    // If audio is currently playing, we might want to restart it with new language
    // But for now, just log the change - next detection will use new language
  }
  
  // Read elderly category behaviors (if available)
  if (doc.containsKey("sensorRange")) {
    double newSensorRange = doc["sensorRange"].as<double>();
    if (newSensorRange != elderlySensorRange) {
      Serial.println("📏 Sensor range changed: " + String(elderlySensorRange) + " → " + String(newSensorRange) + " cm");
      elderlySensorRange = newSensorRange;
      // Apply sensor range to sensing distance
      // Use sensorRange as max, calculate min as 50% of max
      sensingDistanceMin = elderlySensorRange * 0.5;
      sensingDistanceMax = elderlySensorRange;
      Serial.print("   Sensing range updated: ");
      Serial.print(sensingDistanceMin);
      Serial.print("-");
      Serial.print(sensingDistanceMax);
      Serial.println("cm");
    }
  }
  
  if (doc.containsKey("scanningMode")) {
    String newScanningMode = doc["scanningMode"].as<String>();
    if (newScanningMode != scanningMode) {
      Serial.println("🔄 Scanning mode changed: " + scanningMode + " → " + newScanningMode);
      scanningMode = newScanningMode;
    }
  }
  
  if (doc.containsKey("vibrationMode")) {
    String newVibrationMode = doc["vibrationMode"].as<String>();
    if (newVibrationMode != vibrationMode) {
      Serial.println("📳 Vibration mode changed: " + vibrationMode + " → " + newVibrationMode);
      vibrationMode = newVibrationMode;
      // Map vibration mode to PWM intensity
      if (vibrationMode == "strong_repeated") {
        currentVibrationPWM = USE_COIN_MOTOR_MODE ? 255 : 120;
      } else if (vibrationMode == "normal_pulse") {
        currentVibrationPWM = USE_COIN_MOTOR_MODE ? 200 : 90;
      } else if (vibrationMode == "soft_pulse") {
        currentVibrationPWM = USE_COIN_MOTOR_MODE ? 150 : 60;
      }
      Serial.print("   Motor PWM updated: ");
      Serial.println(currentVibrationPWM);
    }
  }
  
  if (doc.containsKey("alertCooldown")) {
    int newAlertCooldown = doc["alertCooldown"].as<int>();
    if (newAlertCooldown != alertCooldown) {
      Serial.println("⏱️ Alert cooldown changed: " + String(alertCooldown) + "s → " + String(newAlertCooldown) + "s");
      alertCooldown = newAlertCooldown;
    }
  }
  
  if (doc.containsKey("indoorMode")) {
    bool newIndoorMode = doc["indoorMode"].as<bool>();
    if (newIndoorMode != indoorMode) {
      Serial.println("🏠 Indoor mode changed: " + String(indoorMode ? "ON" : "OFF") + " → " + String(newIndoorMode ? "ON" : "OFF"));
      indoorMode = newIndoorMode;
      // Adjust sensing distance for indoor mode
      if (indoorMode) {
        sensingDistanceMin = 30.0;
        sensingDistanceMax = 80.0;
      } else {
        // Use sensorRange if available, otherwise default
        if (elderlySensorRange > 0) {
          sensingDistanceMin = elderlySensorRange * 0.5;
          sensingDistanceMax = elderlySensorRange;
        } else {
          sensingDistanceMin = 50.0;
          sensingDistanceMax = 100.0;
        }
      }
    }
  }
  
  if (doc.containsKey("alertRepetition")) {
    int newAlertRepetition = doc["alertRepetition"].as<int>();
    if (newAlertRepetition != alertRepetition) {
      Serial.println("🔔 Alert repetition changed: " + String(alertRepetition) + " → " + String(newAlertRepetition) + " (1=LOW, 2=Standard)");
      alertRepetition = newAlertRepetition;
    }
  }
  
  if (doc.containsKey("voiceDelay")) {
    int newVoiceDelay = doc["voiceDelay"].as<int>();
    if (newVoiceDelay != voiceDelay) {
      Serial.println("🔊 Voice delay changed: " + String(voiceDelay) + "ms → " + String(newVoiceDelay) + "ms");
      voiceDelay = newVoiceDelay;
    }
  }
  
  // Read high-risk category behaviors (if available)
  if (doc.containsKey("sensorAngle")) {
    String newSensorAngle = doc["sensorAngle"].as<String>();
    if (newSensorAngle != sensorAngle) {
      Serial.println("📐 Sensor angle changed: " + sensorAngle + " → " + newSensorAngle);
      sensorAngle = newSensorAngle;
      // If sensorAngle is set, likely high-risk category
      if (userCategory == "") {
        userCategory = "high-risk";
        Serial.println("   Detected user category: high-risk (from sensorAngle)");
      }
    }
  }
  
  if (doc.containsKey("detectionLevel")) {
    String newDetectionLevel = doc["detectionLevel"].as<String>();
    if (newDetectionLevel != detectionLevel) {
      Serial.println("🎯 Detection level changed: " + detectionLevel + " → " + newDetectionLevel);
      detectionLevel = newDetectionLevel;
      // If detectionLevel is set, likely high-risk category
      if (userCategory == "") {
        userCategory = "high-risk";
        Serial.println("   Detected user category: high-risk (from detectionLevel)");
      }
    }
  }
  
  if (doc.containsKey("voiceRepeat")) {
    bool newVoiceRepeat = doc["voiceRepeat"].as<bool>();
    if (newVoiceRepeat != voiceRepeat) {
      Serial.println("🔁 Voice repeat changed: " + String(voiceRepeat ? "ON" : "OFF") + " → " + String(newVoiceRepeat ? "ON" : "OFF"));
      voiceRepeat = newVoiceRepeat;
    }
  }
  
  if (doc.containsKey("depthDetection")) {
    bool newDepthDetection = doc["depthDetection"].as<bool>();
    if (newDepthDetection != depthDetection) {
      Serial.println("🔍 Depth detection changed: " + String(depthDetection ? "ON" : "OFF") + " → " + String(newDepthDetection ? "ON" : "OFF"));
      depthDetection = newDepthDetection;
    }
  }
  
  // Read terrain voice warning (H5) - if available in hardware_control
  // Note: This might not be in hardware_control, so we'll use depthDetection as fallback
  if (doc.containsKey("terrainVoiceWarning")) {
    bool newTerrainVoiceWarning = doc["terrainVoiceWarning"].as<bool>();
    if (newTerrainVoiceWarning != terrainVoiceWarning) {
      Serial.println("🔊 Terrain voice warning changed: " + String(terrainVoiceWarning ? "ON" : "OFF") + " → " + String(newTerrainVoiceWarning ? "ON" : "OFF"));
      terrainVoiceWarning = newTerrainVoiceWarning;
    }
  } else {
    // Fallback: If terrainVoiceWarning not in hardware_control, use depthDetection as indicator
    // (H4 = "Oo" usually means terrain is enabled, and H5 = "Oo" means voice is enabled)
    terrainVoiceWarning = depthDetection;  // Use depthDetection as proxy for terrain voice
  }
  
  // Detect user category from behaviors
  // If sensorRange is set, it's elderly category
  if (doc.containsKey("sensorRange") && userCategory == "") {
    userCategory = "elderly";
    Serial.println("   Detected user category: elderly (from sensorRange)");
  }

  // Read usage location (affects sensing distance) - for high-risk category or fallback
  String newUsageLocation = doc["usageLocation"] | usageLocation;
  if (newUsageLocation != usageLocation && !doc.containsKey("sensorRange")) {
    // Only apply if sensorRange not set (i.e., not elderly category)
    Serial.println("📍 Usage location changed: " + usageLocation + " → " + newUsageLocation);
    usageLocation = newUsageLocation;
    // Adjust sensing distance based on location
    if (usageLocation == "indoors") {
      // Indoors: shorter range (30-80cm)
      sensingDistanceMin = 30.0;
      sensingDistanceMax = 80.0;
    } else {
      // Outdoors: longer range (50-100cm)
      sensingDistanceMin = 50.0;
      sensingDistanceMax = 100.0;
    }
    Serial.print("   Sensing range updated: ");
    Serial.print(sensingDistanceMin);
    Serial.print("-");
    Serial.print(sensingDistanceMax);
    Serial.println("cm");
  }

  // Read owner UID for user-specific GPS-lost alerts
  if (doc.containsKey("ownerUid")) {
    String newOwnerUid = doc["ownerUid"].as<String>();
    if (newOwnerUid != ownerUid) {
      ownerUid = newOwnerUid;
      Serial.print("👤 ownerUid updated for alerts: ");
      Serial.println(ownerUid);
      // Force refresh of sender creds for new owner.
      senderGmail = "";
      senderAppPassword = "";
      lastSenderCredsLoadMs = 0;
      if (currentConnection == CONN_WIFI) {
        loadSenderCredsFromFirebase();
      }
    }
  }
  
  // Check for restart request (only if we haven't restarted recently to prevent loops)
  if (doc.containsKey("restartRequested") && doc["restartRequested"] == true) {
    // Prevent restart loop: only restart if it's been more than 10 seconds since last restart
    if (millis() - lastRestartTime < 10000) {
      Serial.println("⚠️ Restart requested but ignored (too soon after last restart - preventing loop)");
      // Still clear the flag to prevent future restarts
      String clearUrl = String("/hardware_control/restartRequested.json?auth=") + FIREBASE_AUTH;
      String clearData = "false";
      if (currentConnection == CONN_WIFI) {
        WiFiClientSecure clearClient;
        clearClient.setInsecure();
        if (clearClient.connect(FIREBASE_HOST, 443)) {
          clearClient.printf("PUT %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s", 
                            clearUrl.c_str(), FIREBASE_HOST, clearData.length(), clearData.c_str());
          delay(500);
          clearClient.stop();
        }
      }
      return;
    }
    
    Serial.println("🔄 Restart requested from Firebase!");
    
    // Clear the restart flag BEFORE restarting to prevent restart loop
    Serial.println("   Clearing restart flag in Firebase...");
    String clearUrl = String("/hardware_control/restartRequested.json?auth=") + FIREBASE_AUTH;
    String clearData = "false";
    
    if (currentConnection == CONN_WIFI) {
      WiFiClientSecure clearClient;
      clearClient.setInsecure();
      if (clearClient.connect(FIREBASE_HOST, 443)) {
        clearClient.printf("PUT %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s", 
                          clearUrl.c_str(), FIREBASE_HOST, clearData.length(), clearData.c_str());
        delay(500); // Wait for request to complete
        clearClient.stop();
        Serial.println("   ✅ Restart flag cleared");
      }
    }
    
    lastRestartTime = millis(); // Record restart time
    startupAudioInitialized = false; // Reset audio guard for next startup
    Serial.println("   Restarting ESP32 in 1 second...");
    delay(1000); // Reduced from 2 seconds to 1 second for faster restart
    ESP.restart();
    return; // This won't execute, but good practice
  }
  
  // Read vibration intensity (affects motor PWM)
  String newVibrationIntensity = doc["vibrationIntensity"] | vibrationIntensity;
  if (newVibrationIntensity != vibrationIntensity) {
    Serial.println("🔔 Vibration intensity changed: " + vibrationIntensity + " → " + newVibrationIntensity);
    vibrationIntensity = newVibrationIntensity;
    // Adjust motor PWM based on intensity
    // COIN MOTOR: Needs higher PWM values (150-255) for proper operation
    if (USE_COIN_MOTOR_MODE) {
      // Coin motor mode: Higher PWM values
      if (vibrationIntensity == "low") {
        currentVibrationPWM = 150;  // Low intensity for coin motor
      } else if (vibrationIntensity == "high") {
        currentVibrationPWM = 255;   // Maximum for coin motor
      } else {
        currentVibrationPWM = 200;   // Medium: default 200 for coin motor
      }
    } else {
      // Regular DC motor mode: Lower PWM values
      if (vibrationIntensity == "low") {
        currentVibrationPWM = 60;  // ~2.8V equivalent
      } else if (vibrationIntensity == "high") {
        currentVibrationPWM = 120; // ~5.6V equivalent (max safe for 3-5V motor)
      } else {
        currentVibrationPWM = VIBRATION_MOTOR_PWM; // Medium: default
      }
    }
    Serial.print("   Motor PWM updated: ");
    Serial.print(currentVibrationPWM);
    Serial.print(" (Coin motor mode: ");
    Serial.print(USE_COIN_MOTOR_MODE ? "YES" : "NO");
    Serial.println(")");
  }
  
  // Read volume preference (affects DFPlayer volume)
  String newVolume = doc["volume"] | volume;
  if (newVolume != volume) {
    Serial.println("🔊 Volume changed: " + volume + " → " + newVolume);
    volume = newVolume;
    // Adjust DFPlayer volume (0-30 range)
    if (volume == "low") {
      audioVolume = 10;
    } else if (volume == "high") {
      audioVolume = 30;
    } else {
      audioVolume = 20; // Medium
    }
    if (dfPlayerReady) {
      player.volume(audioVolume);
    }
    Serial.print("   Audio volume updated: ");
    Serial.println(audioVolume);
  }

  Serial.println("   motorEnabled = " + String(newMotorEnabled ? "true" : "false"));
  Serial.println("   ultrasonicEnabled = " + String(newUltrasonicEnabled ? "true" : "false"));
  Serial.println("   audioEnabled = " + String(newAudioEnabled ? "true" : "false"));
  Serial.println("   language = " + userLanguage + " (normalized)");
  Serial.println("   usageLocation = " + usageLocation);
  Serial.println("   vibrationIntensity = " + vibrationIntensity);
  Serial.println("   volume = " + volume);
  Serial.println("   userCategory = " + (userCategory.length() > 0 ? userCategory : "not set"));
  if (userCategory == "high-risk") {
    Serial.println("   sensorAngle = " + sensorAngle);
    Serial.println("   detectionLevel = " + detectionLevel);
    Serial.println("   voiceRepeat = " + String(voiceRepeat ? "true" : "false"));
    Serial.println("   depthDetection = " + String(depthDetection ? "true" : "false"));
    Serial.println("   terrainVoiceWarning = " + String(terrainVoiceWarning ? "true" : "false"));
  }
  Serial.print("   Sensing range: ");
  Serial.print(sensingDistanceMin);
  Serial.print("-");
  Serial.print(sensingDistanceMax);
  Serial.println("cm");
  Serial.print("   Motor PWM: ");
  Serial.println(currentVibrationPWM);

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

  // Battery monitoring ADC setup
  pinMode(BATTERY_ADC_PIN, INPUT);
  analogSetAttenuation(ADC_11db); // Set ADC attenuation for 0-3.3V range
  Serial.print("🔋 Battery monitoring initialized (GPIO");
  Serial.print(BATTERY_ADC_PIN);
  Serial.println("/ADC1)");
  Serial.println("   TP4056 Module Setup:");
  Serial.println("   1. Connect battery to TP4056 BAT+ and BAT-");
  Serial.print("   2. Voltage divider: BAT+ → [10kΩ] → GPIO");
  Serial.print(BATTERY_ADC_PIN);
  Serial.println(" → [10kΩ] → GND");
  Serial.println("   3. TP4056 OUT+ → ESP32 VIN (or 3.3V if using regulator)");
  Serial.println("   4. TP4056 OUT- → ESP32 GND");
  Serial.println("   5. USB power → TP4056 IN+ and IN- (for charging)");
  
  // OLED init with error checking
  Wire.begin(21, 22);  // SDA=21, SCL=22 for ESP32
  Serial.println("🔍 Initializing OLED display...");
  
  // Try both common I2C addresses (0x3C and 0x3D)
  bool oledFound = false;
  if (display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    oledFound = true;
    Serial.println("✅ OLED found at address 0x3C");
  } else if (display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) {
    oledFound = true;
    Serial.println("✅ OLED found at address 0x3D");
  } else {
    Serial.println("❌ OLED initialization FAILED!");
    Serial.println("   Check wiring: SDA=GPIO21, SCL=GPIO22");
    Serial.println("   Check I2C address (try 0x3C or 0x3D)");
    Serial.println("   OLED will not display, but system will continue...");
  }
  
  if (oledFound) {
    oledReady = true;
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("System Booting...");
    display.display();
    Serial.println("✅ OLED display initialized successfully");
  } else {
    oledReady = false;
  }

  // DFPlayer init (initialize only, don't play yet - will play after language is read)
  dfSerial.begin(9600, SERIAL_8N1, 13, 14); //DF_RX, DF_TX
  if (player.begin(dfSerial)) {
    player.volume(audioVolume);  // Use dynamic volume based on preference
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
  lastRestartTime = millis(); // Initialize restart time tracker to prevent restart loops
  systemReady = false;
  Serial.println("🕐 Waiting 7 seconds before enabling sensors...");
  
  // Optional: Uncomment the line below to test motor on startup
  // testMotor();

  // ===================== WiFi Connection (with Fallback) =====================
  Serial.println();
  Serial.println("========================================");
  Serial.println("📶 STARTING WIFI CONNECTION");
  Serial.println("========================================");
  Serial.print("   Trying ");
  Serial.print(wifiNetworkCount);
  Serial.println(" WiFi network(s) in order...");
  Serial.println();
  
  if (oledReady) {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Connecting WiFi...");
    display.display();
  }
  
  bool wifiConnected = false;
  String connectedSSID = "";
  
  // Try each WiFi network in order
  for (int i = 0; i < wifiNetworkCount; i++) {
    Serial.println("----------------------------------------");
    Serial.print("📶 Attempt ");
    Serial.print(i + 1);
    Serial.print(" of ");
    Serial.print(wifiNetworkCount);
    Serial.print(": ");
    Serial.print(wifiNetworks[i].description);
    Serial.println();
    Serial.print("   SSID: ");
    Serial.println(wifiNetworks[i].ssid);
    
    if (oledReady) {
      display.clearDisplay();
      display.setCursor(0, 0);
      display.print("WiFi ");
      display.print(i + 1);
      display.print("/");
      display.print(wifiNetworkCount);
      display.println();
      display.setCursor(0, 15);
      display.print(wifiNetworks[i].ssid);
      display.display();
    }
    
    // Disconnect from previous network (if any)
    WiFi.disconnect();
    delay(500);
    
    // Try to connect to current network
    WiFi.begin(wifiNetworks[i].ssid, wifiNetworks[i].password);
    
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
    
    // Check if connection successful
    if (WiFi.status() == WL_CONNECTED) {
      wifiConnected = true;
      connectedSSID = wifiNetworks[i].ssid;
      Serial.println("========================================");
      Serial.print("✅ WiFi Connected! ");
      Serial.print(wifiNetworks[i].description);
      Serial.println();
      Serial.print("   SSID: ");
      Serial.println(connectedSSID);
      Serial.print("   IP Address: ");
      Serial.println(WiFi.localIP());
      Serial.print("   Signal Strength (RSSI): ");
      Serial.print(WiFi.RSSI());
      Serial.println(" dBm");
      Serial.println("========================================");
      
      if (oledReady) {
        display.clearDisplay();
        display.setCursor(0, 0);
        display.println("WiFi Connected!");
        display.setCursor(0, 15);
        display.print("SSID: ");
        display.println(connectedSSID);
        display.setCursor(0, 30);
        display.print("IP: ");
        display.println(WiFi.localIP().toString());
        display.display();
      }
      delay(2000);
      break; // Exit loop - connection successful
    } else {
      // Connection failed for this network
      Serial.print("❌ Failed to connect to ");
      Serial.print(wifiNetworks[i].ssid);
      Serial.print(" (");
      Serial.print(wifiNetworks[i].description);
      Serial.println(")");
      Serial.print("   WiFi Status Code: ");
      int status = WiFi.status();
      Serial.println(status);
      
      // If this is not the last network, try next one
      if (i < wifiNetworkCount - 1) {
        Serial.println("   ⏭️  Trying next WiFi network...");
        Serial.println();
        delay(1000); // Brief delay before trying next network
      }
    }
  }
  
  // If all networks failed
  if (!wifiConnected) {
    Serial.println("========================================");
    Serial.println("❌ ALL WiFi Networks Failed!");
    Serial.println("========================================");
    Serial.println("   Tried the following networks:");
    for (int i = 0; i < wifiNetworkCount; i++) {
      Serial.print("   ");
      Serial.print(i + 1);
      Serial.print(". ");
      Serial.print(wifiNetworks[i].ssid);
      Serial.print(" (");
      Serial.print(wifiNetworks[i].description);
      Serial.println(")");
    }
    Serial.println();
    Serial.println("   Possible causes:");
    Serial.println("   1. All WiFi networks out of range");
    Serial.println("   2. Wrong WiFi passwords");
    Serial.println("   3. WiFi routers not broadcasting SSID");
    Serial.println("   4. ESP32 WiFi hardware issue");
    Serial.println("   5. iPhone hotspot not enabled");
    Serial.println();
    Serial.println("   ⚠️  System will continue without WiFi.");
    Serial.println("   📡 Will try GPRS fallback (if enabled)...");
    Serial.println("========================================");
    
    if (oledReady) {
      display.clearDisplay();
      display.setCursor(0, 0);
      display.println("WiFi Failed!");
      display.setCursor(0, 15);
      display.println("All networks");
      display.setCursor(0, 30);
      display.println("unavailable");
      display.display();
    }
  }

  // ===================== Firebase Connection =====================
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("========================================");
    Serial.println("🔧 STARTING FIREBASE CONNECTION");
    Serial.println("========================================");
    
    if (oledReady) {
      display.clearDisplay();
      display.setCursor(0, 0);
      display.println("Connecting Firebase...");
      display.display();
    }
    
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
    } else if (lang == "filipino" || lang == "tagalog") {
      userLanguage = "tagalog";  // Treat filipino same as tagalog
    } else if (lang == "none") {
      userLanguage = "none";
    } else {
      userLanguage = "tagalog";  // Default
    }
    
    // Also initialize other settings from Firebase if available
    // This will read usageLocation, vibrationIntensity, volume, and hardware control flags
    pollHardwareControl();
    
     // Now play startup audio with correct language (only once)
     if (!startupAudioInitialized && dfPlayerReady) {
       startupAudioInitialized = true; // Set guard to prevent duplicate
       int startupFile = getAudioFileNumber(1); // Get correct file based on language (001 or 004)
       Serial.print("🔍 Startup audio selection: baseFile=1, userLanguage=");
       Serial.print(userLanguage);
       Serial.print(", selected file=");
       Serial.println(startupFile);
       if (startupFile > 0) {  // Only play if language is not "none"
         player.playFolder(1, startupFile);
         startupAudioPlayed = true;
         startupAudioTime = millis();
         Serial.print("✅ DFPlayer: Playing startup audio ");
         Serial.print(startupFile < 10 ? "00" : "0");
         Serial.print(startupFile);
         Serial.print(".mp3 (language=");
         Serial.print(userLanguage);
         Serial.println(")");
       } else {
         Serial.println("⚠️ Language is 'none' - skipping startup audio");
         startupAudioPlayed = true;  // Mark as played so system can continue
         startupAudioTime = millis();
       }
     } else if (!dfPlayerReady) {
       Serial.println("⚠️ DFPlayer not ready, skipping startup audio");
     } else if (startupAudioInitialized) {
       Serial.println("⚠️ Startup audio already played - skipping duplicate");
     }
    
    if (oledReady) {
      display.clearDisplay();
      display.setCursor(0, 0);
      display.println("Firebase OK!");
      display.display();
    }
    delay(1000);
  } else {
    // WiFi/Firebase connection failed - play default Tagalog startup audio (only once)
    Serial.println();
    Serial.println("⚠️ WiFi/Firebase not connected - using default language (Tagalog)");
     userLanguage = "tagalog";
     if (!startupAudioInitialized && dfPlayerReady) {
       startupAudioInitialized = true; // Set guard to prevent duplicate
       int startupFile = getAudioFileNumber(1); // Will use default "tagalog" = 001.mp3
       if (startupFile > 0) {  // Only play if language is not "none"
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
         Serial.println("⚠️ Language is 'none' - skipping startup audio (no WiFi/Firebase)");
         startupAudioPlayed = true;  // Mark as played so system can continue
         startupAudioTime = millis();
       }
     } else if (!dfPlayerReady) {
       Serial.println("⚠️ DFPlayer not ready, skipping startup audio (no WiFi/Firebase)");
     } else if (startupAudioInitialized) {
       Serial.println("⚠️ Startup audio already played - skipping duplicate (no WiFi/Firebase)");
     }
  }
}

// ===================== Loop =====================
void loop() {
  // Check battery voltage periodically
  if (millis() - lastBatteryCheck > BATTERY_CHECK_INTERVAL) {
    readBatteryVoltage();
    lastBatteryCheck = millis();
  }
  
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
  
  // Serial command to replay intro audio (type "PLAY_INTRO" in Serial Monitor)
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    command.toUpperCase();
    
    if (command == "PLAY_INTRO" || command == "INTRO") {
      Serial.println("🎵 Replaying startup intro audio...");
      if (dfPlayerReady) {
        int startupFile = getAudioFileNumber(1); // Get correct file based on language
        if (startupFile > 0) {
          player.stop(); // Stop any currently playing audio
          delay(200);
          player.playFolder(1, startupFile);
          Serial.print("✅ Playing intro audio: ");
          Serial.print(startupFile < 10 ? "00" : "0");
          Serial.print(startupFile);
          Serial.print(".mp3 (language=");
          Serial.print(userLanguage);
          Serial.println(")");
        } else {
          Serial.println("⚠️ Language is 'none' - cannot play intro audio");
        }
      } else {
        Serial.println("❌ DFPlayer not ready - cannot play intro audio");
      }
    } else if (command == "BATTERY" || command == "BAT") {
      Serial.println("🔋 Battery Status:");
      Serial.print("   Voltage: ");
      Serial.print(batteryVoltage, 2);
      Serial.println("V");
      Serial.print("   Percentage: ");
      Serial.print(batteryPercentage);
      Serial.println("%");
      Serial.print("   ADC Pin: GPIO");
      Serial.println(BATTERY_ADC_PIN);
      Serial.print("   ADC Reading: ");
      Serial.println(analogRead(BATTERY_ADC_PIN));
    }
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
      if (oledReady) {
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
      }
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
    // GPS Update Interval: Uses GPS_UPDATE_INTERVAL constant (default: 1 second)
    // Most GPS modules update at 1Hz (once per second), so 1 second is optimal for real-time
    if (millis() - lastGPSUpdate > GPS_UPDATE_INTERVAL) {
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
  sendGpsLostAlertIfNeeded();

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
  // Always read distance for OLED display (even when ultrasonicEnabled is false)
  // This helps with debugging and ensures OLED always shows sensor readings
  // Motor and audio are only activated when ultrasonicEnabled is true
  if (ultrasonicEnabledAfterDelay) {
    // Apply scanning mode logic (only when enabled)
    static unsigned long lastScanTime = 0;
    bool shouldScan = false;
    
    if (ultrasonicEnabled) {
      // Only apply scanning mode when ultrasonic is enabled
      if (scanningMode == "continuous") {
        // Continuous: Always scan (every loop)
        shouldScan = true;
      } else if (scanningMode == "semi-continuous") {
        // Semi-continuous: Scan every 500ms
        if (millis() - lastScanTime >= 500) {
          shouldScan = true;
          lastScanTime = millis();
        }
      } else { // event-based (default)
        // Event-based: Scan every 1 second
        if (millis() - lastScanTime >= 1000) {
          shouldScan = true;
          lastScanTime = millis();
        }
      }
    } else {
      // Ultrasonic disabled but still read for OLED display (slower rate: every 2 seconds)
      if (millis() - lastScanTime >= 2000) {
        shouldScan = true;
        lastScanTime = millis();
      }
    }
    
    if (shouldScan) {
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
        static unsigned long lastDistanceLog = 0;
        if (millis() - lastDistanceLog > 2000) {  // Log every 2 seconds
          Serial.print("📏 Distance: ");
          Serial.print(distance);
          Serial.print(" cm | Range: ");
          Serial.print(sensingDistanceMin);
          Serial.print("-");
          Serial.print(sensingDistanceMax);
          Serial.print(" cm | Mode: ");
          Serial.print(scanningMode);
          Serial.print(" | Ultrasonic: ");
          Serial.println(ultrasonicEnabled ? "ENABLED" : "DISABLED");
          lastDistanceLog = millis();
        }
        
         // Audio control based on distance (only when ultrasonicEnabled is true)
         // First check: If audio is disabled, stop any playing audio
         if (!audioEnabled && currentAudioState != 0) {
           player.stop();
           currentAudioState = 0;
           Serial.println("🔇 Audio stopped (audio disabled in Firebase)");
         }
         // NEW LOGIC: Audio plays ONLY when distance is in sensing range AND ultrasonicEnabled is true
         // Audio loops/continues as long as object is detected in this range
         // Gate audio so that startup voice (001/004) can finish first
         // Require: startupAudioPlayed == true AND at least 4 seconds since it started
         static unsigned long lastAudioAlert = 0;  // Track last audio alert time for cooldown
         if (ultrasonicEnabled && audioEnabled && startupAudioPlayed && millis() - startupAudioTime > 4000) {
           if (distance >= sensingDistanceMin && distance <= sensingDistanceMax) {
             // Check alert cooldown (elderly behavior) - skip cooldown for high-risk continuous mode
             bool skipCooldown = (userCategory == "high-risk" && voiceRepeat == true);
             unsigned long cooldownMs = alertCooldown * 1000;  // Convert seconds to milliseconds
             if (skipCooldown || millis() - lastAudioAlert >= cooldownMs) {
               // Object detected in valid range - play audio based on category and settings
               // NEW MAPPING:
               // Elderly E7="Oo": 009 (Tagalog) or 0014 (English)
               // Elderly E7="Hindi": 0010 (Tagalog) or 0015 (English)
               // High-risk H1="Oo": 002 (Tagalog) or 005 (English)
               // High-risk H5="Oo" + H1="Hindi": 0012 (Tagalog) or 0017 (English)
               int audioFile = getDetectionAudioFile();
               
               if (currentAudioState != 1 || voiceRepeat) {
                 Serial.print("🔍 Audio file selection: category=");
                 Serial.print(userCategory);
                 Serial.print(", userLanguage=");
                 Serial.print(userLanguage);
                 if (userCategory == "elderly") {
                   Serial.print(", alertRepetition=");
                   Serial.print(alertRepetition);
                 } else if (userCategory == "high-risk") {
                   Serial.print(", detectionLevel=");
                   Serial.print(detectionLevel);
                 Serial.print(", depthDetection=");
                 Serial.print(depthDetection);
                 Serial.print(", terrainVoiceWarning=");
                 Serial.print(terrainVoiceWarning);
                 }
                 Serial.print(", selected file=");
                 Serial.println(audioFile);
                 if (audioFile > 0) {  // Only play if language is not "none"
                   player.stop();  // Stop any currently playing audio first
                   delay(voiceDelay);  // Apply voice delay (elderly behavior: 1000ms standard, 3000ms longer)
                   
                   // For high-risk with voiceRepeat, continuously loop
                   if (voiceRepeat) {
                     player.loop(audioFile);  // Loop continuously
                   } else {
                     player.play(audioFile);  // Play once
                   }
                   
                   currentAudioState = 1;
                   lastAudioAlert = millis();  // Update last alert time for cooldown
                   Serial.print("🔊 ");
                   Serial.print(voiceRepeat ? "Looping " : "Playing ");
                   Serial.print(audioFile < 10 ? "00" : "0");
                   Serial.print(audioFile);
                   Serial.print(".mp3 (object detected ");
                   Serial.print(sensingDistanceMin);
                   Serial.print("-");
                   Serial.print(sensingDistanceMax);
                   Serial.print("cm, language=");
                   Serial.print(userLanguage);
                   Serial.print(", cooldown=");
                   Serial.print(alertCooldown);
                   Serial.print("s, delay=");
                   Serial.print(voiceDelay);
                   Serial.print("ms, repeat=");
                   Serial.print(voiceRepeat ? "ON" : "OFF");
                   Serial.println(")");
                 } else {
                   // Language is "none" - don't play audio
                   Serial.println("🔇 Audio not playing (language = 'none')");
                   currentAudioState = 0;
                 }
               }
               // If audio is already looping and voiceRepeat is true, let it continue
             } else {
               // Still in cooldown period
               static unsigned long lastCooldownLog = 0;
               if (millis() - lastCooldownLog > 2000) {
                 Serial.print("⏱️ Audio alert in cooldown (");
                 Serial.print((cooldownMs - (millis() - lastAudioAlert)) / 1000);
                 Serial.println("s remaining)");
                 lastCooldownLog = millis();
               }
             }
           } else {
             // Object too close or too far - stop audio
             if (currentAudioState != 0) {
               player.stop();
               currentAudioState = 0;
               if (distance < sensingDistanceMin) {
                 Serial.print("🔇 Audio stopped (object too close < ");
                 Serial.print(sensingDistanceMin);
                 Serial.println("cm)");
               } else {
                 Serial.print("🔇 Audio stopped (object too far > ");
                 Serial.print(sensingDistanceMax);
                 Serial.println("cm)");
               }
             }
           }
         }
        
         // Motor control based on distance (only when ultrasonicEnabled is true)
         // NEW LOGIC: Motor vibrates ONLY when distance is in sensing range AND ultrasonicEnabled is true
         // Motor stops when distance is outside the sensing range
         if (!ultrasonicEnabled || !motorEnabled) {
           // Motor disabled in Firebase - always stop
           motorStop();
           motorPulseState = false;
           static unsigned long lastMotorDisabledLog = 0;
           if (millis() - lastMotorDisabledLog > 5000) {  // Log every 5 seconds
             Serial.println("🔔 Motor: DISABLED in Firebase (motorEnabled = false)");
             lastMotorDisabledLog = millis();
           }
         } else if (distance < sensingDistanceMin) {
           // Object too close - STOP motor (ignore close readings)
           motorStop();
           motorPulseState = false;
           static unsigned long lastStopLog = 0;
           if (millis() - lastStopLog > 2000) {  // Log every 2 seconds to avoid spam
             Serial.print("🔔 Motor: Stopped (distance ");
             Serial.print(distance);
             Serial.print("cm < ");
             Serial.print(sensingDistanceMin);
             Serial.println("cm - too close, ignoring)");
             lastStopLog = millis();
           }
         } else if (distance >= sensingDistanceMin && distance <= sensingDistanceMax) {
           // Object in valid sensing range - check cooldown before activating motor
           static unsigned long lastMotorAlert = 0;
           unsigned long cooldownMs = alertCooldown * 1000;  // Convert seconds to milliseconds
           if (millis() - lastMotorAlert >= cooldownMs) {
             // Apply vibration mode based on elderly behavior
             if (vibrationMode == "strong_repeated") {
               // Strong, repeated vibration
               motorControlByDistance(distance);
               lastMotorAlert = millis();
             } else if (vibrationMode == "normal_pulse") {
               // Normal pulse vibration
               motorControlByDistance(distance);
               lastMotorAlert = millis();
             } else if (vibrationMode == "soft_pulse") {
               // Soft pulse vibration
               motorControlByDistance(distance);
               lastMotorAlert = millis();
             } else {
               // Default behavior
               motorControlByDistance(distance);
               lastMotorAlert = millis();
             }
           } else {
             // Still in cooldown period
             static unsigned long lastMotorCooldownLog = 0;
             if (millis() - lastMotorCooldownLog > 2000) {
               Serial.print("⏱️ Motor alert in cooldown (");
               Serial.print((cooldownMs - (millis() - lastMotorAlert)) / 1000);
               Serial.println("s remaining)");
               lastMotorCooldownLog = millis();
             }
           }
         } else if (distance > sensingDistanceMax) {
           // No object detected (distance > max) - STOP motor immediately
           motorStop();
           motorPulseState = false;
           static unsigned long lastStopLog2 = 0;
           if (millis() - lastStopLog2 > 2000) {  // Log every 2 seconds to avoid spam
             Serial.print("🔔 Motor: Stopped (distance ");
             Serial.print(distance);
             Serial.print("cm > ");
             Serial.print(sensingDistanceMax);
             Serial.println("cm - no object)");
             lastStopLog2 = millis();
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
        if (ultrasonicEnabled && audioEnabled && currentAudioState != 0) {
          player.stop();
          currentAudioState = 0;
          Serial.println("🔇 Audio stopped (invalid distance reading)");
        }
      }
    }
  } else {
    // Grace period not over yet - don't read sensor, but keep last distance for OLED
    // Stop motor and audio if they were running
    motorStop();
    motorPulseState = false;  // Reset motor pulse state
    if (audioEnabled && currentAudioState != 0) {
      player.stop();
      currentAudioState = 0;
    }
  }

  // ===================== OLED Display =====================
  // OLED re-init and recovery
  static unsigned long lastOLEDReinit = 0;

  // If OLED is NOT ready, try to initialize every 5 seconds
  if (!oledReady && millis() - lastOLEDReinit > 5000) {
    lastOLEDReinit = millis();
    Serial.println("🔁 OLED not ready - attempting re-initialization...");
    // Try both common I2C addresses
    if (display.begin(SSD1306_SWITCHCAPVCC, 0x3C) || display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) {
      oledReady = true;
      display.clearDisplay();
      display.setTextColor(SSD1306_WHITE);
      display.setTextSize(1);
      display.setCursor(0, 0);
      display.println("OLED Recovered");
      display.display();
      Serial.println("✅ OLED re-initialized successfully");
    } else {
      Serial.println("❌ OLED re-initialization FAILED (check SDA=21, SCL=22, address 0x3C/0x3D)");
    }
  }

  // If OLED was ready, still try a light refresh every 30 seconds to recover minor I2C glitches
  if (oledReady && millis() - lastOLEDReinit > 30000) {
    lastOLEDReinit = millis();
    display.clearDisplay();
    display.display();
  }
  
  if (oledReady) {
    display.clearDisplay();
    
    // Show ultrasonic distance with LARGER text size (size 2)
    // ALWAYS show distance reading if available, even if ultrasonicEnabled is false (for debugging)
    // This helps diagnose issues when there's no internet connection
    if (distance > 0 && distance < 400) {  // Show any reading (including < 2cm)
      display.setTextSize(2);  // Larger text for distance
      display.setCursor(0, 0);
      display.print(distance, 1);
      display.setTextSize(1);  // Smaller text for unit
      display.print(" CM");
      
      // Show sensor status if ultrasonic is disabled
      if (!ultrasonicEnabled) {
        display.setTextSize(1);
        display.setCursor(0, 18);
        display.print("SENSOR: OFF");
      }
    } else {
      // Completely invalid (0 or >= 400) - show "---"
      display.setTextSize(2);
      display.setCursor(0, 0);
      display.print("---");
      display.setTextSize(1);
      display.print(" CM");
      
      // Show sensor status
      if (!ultrasonicEnabled) {
        display.setTextSize(1);
        display.setCursor(0, 18);
        display.print("SENSOR: OFF");
      } else {
        display.setTextSize(1);
        display.setCursor(0, 18);
        display.print("NO DETECTION");
      }
    }
    
    // Reset text size to 1 for other displays
    display.setTextSize(1);
    
    // Connection status (WiFi/GPRS) and Firebase status
    bool wifiConnected = WiFi.status() == WL_CONNECTED;
    #if ENABLE_SIM800L
    bool gprsConnected = (currentConnection == CONN_GPRS && gprsReady);
    #endif

    // Adjust Y position to avoid overlap with sensor status
    int statusY = (distance > 0 && distance < 400 && !ultrasonicEnabled) ? 27 : 15;
    
    display.setCursor(0, statusY);
    display.print("WiFi:");
    display.print(wifiConnected ? "OK" : "NO");

    display.setCursor(64, statusY);
    display.print("FB:");
    display.print(firebaseReady ? "OK" : "NO");

    #if ENABLE_SIM800L
    int gprsY = (distance > 0 && distance < 400 && !ultrasonicEnabled) ? 39 : 27;
    display.setCursor(0, gprsY);
    display.print("GPRS:");
    display.print(gprsConnected ? "OK" : "NO");
    #endif
    
    // Firebase Database status
    int dbY = (distance > 0 && distance < 400 && !ultrasonicEnabled) ? 39 : 27;
    display.setCursor(64, dbY);
    display.print("DB:");
    display.print(firebaseReady ? "OK" : "NO");
    
    // GPS Satellites and Fix status
    int gpsY = (distance > 0 && distance < 400 && !ultrasonicEnabled) ? 52 : 40;
    display.setCursor(0, gpsY);
    display.print("Sats: ");
    display.print(gps.satellites.value());
    if (gps.location.isValid()) {
      display.print(" FIX");
    } else {
      display.print(" ---");
    }
    
    // Battery percentage (small text at bottom right)
    display.setCursor(64, gpsY);
    display.print("Bat: ");
    display.print(batteryPercentage);
    display.print("%");
    
    // Update display (with error handling)
    try {
      display.display();
    } catch (...) {
      // If display fails, mark OLED as not ready and try to re-initialize next time
      static unsigned long lastOLEDError = 0;
      if (millis() - lastOLEDError > 5000) {  // Log error every 5 seconds max
        Serial.println("⚠️ OLED display error - will attempt re-initialization");
        oledReady = false;
        lastOLEDError = millis();
      }
    }
  }
  delay(200);
}

