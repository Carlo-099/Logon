# ESP32 Firebase Integration Guide

This guide explains how to connect your ESP32 to Firebase Realtime Database to communicate with your Flutter app.

## Firebase Database Structure

The Flutter app uses the following Firebase Realtime Database structure:

```
    firebase-database/
    ├── profiling/
    │   └── {userId}/
    │       ├── name: string
    │       ├── dcMotor: boolean
    │       ├── ultrasonic: boolean
    │       ├── dfPlayer: boolean
    │       ├── oled: boolean
    │       ├── gps: boolean
    │       └── timestamp: number
    ├── gps/
    │   ├── latitude: number
    │   ├── longitude: number
    │   └── timestamp: number
    └── hardware_control/
        ├── motorEnabled: boolean
        ├── ultrasonicEnabled: boolean
        ├── audioEnabled: boolean
        └── timestamp: number
    ```

## ESP32 Code Modifications Required

### 1. Install Required Libraries

Add these libraries to your Arduino IDE:
- `FirebaseESP32` by Mobizt (for Firebase Realtime Database)
- `WiFi` (built-in ESP32 library)
- `ArduinoJson` by Benoit Blanchon (for JSON parsing)

### 2. Add WiFi and Firebase Configuration

Add these at the top of your Arduino code:

```cpp
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <ArduinoJson.h>

// WiFi credentials
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase configuration - USE YOUR ACTUAL VALUES
#define FIREBASE_HOST "login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW"  // Your database secret

FirebaseData firebaseData;
FirebaseJson json;
```

### 3. Initialize WiFi and Firebase in setup()

Add this to your `setup()` function:

```cpp
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
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
  
  // Initialize Firebase
  Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
  Firebase.reconnectWiFi(true);
  
  // Set database read timeout
  Firebase.setReadTimeout(firebaseData, 1000 * 60);
  Firebase.setwriteSizeLimit(firebaseData, "tiny");
  
  Serial.println("✅ Firebase Connected");
}
```

### 4. Write GPS Data to Firebase

Add this function and call it in your `loop()`:

```cpp
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
```

Call this in your `loop()` after reading GPS:
```cpp
void loop() {
  // ... your existing GPS reading code ...
  
  // Update Firebase with GPS data
  if (gps.location.isValid()) {
    updateGPSInFirebase();
  }
  
  // ... rest of your code ...
}
```

### 5. Read Hardware Control from Firebase

Add this function to read hardware control settings:

```cpp
void checkHardwareControl() {
  if (Firebase.getJSON(firebaseData, "/hardware_control")) {
    FirebaseJson &json = firebaseData.jsonObject();
    FirebaseJsonData jsonData;
    
    bool motorEnabled = false;
    bool ultrasonicEnabled = false;
    bool audioEnabled = false;
    
    if (json.get(jsonData, "motorEnabled")) {
      motorEnabled = jsonData.boolValue;
    }
    if (json.get(jsonData, "ultrasonicEnabled")) {
      ultrasonicEnabled = jsonData.boolValue;
    }
    if (json.get(jsonData, "audioEnabled")) {
      audioEnabled = jsonData.boolValue;
    }
    
    // Use these values to control your hardware
    // For example:
    if (!motorEnabled) {
      motorStop();
    }
    // Add similar logic for ultrasonic and audio
    
    Serial.println("Motor: " + String(motorEnabled ? "ON" : "OFF"));
  } else {
    Serial.println("❌ Failed to read hardware control: " + firebaseData.errorReason());
  }
}
```

Call this periodically in your `loop()`:
```cpp
void loop() {
  // ... existing code ...
  
  // Check Firebase for hardware control updates (every 2 seconds)
  static unsigned long lastFirebaseCheck = 0;
  if (millis() - lastFirebaseCheck > 2000) {
    checkHardwareControl();
    lastFirebaseCheck = millis();
  }
  
  // ... rest of your code ...
}
```

### 6. Complete Modified Loop Example

Here's how your loop might look with Firebase integration:

```cpp
void loop() {
  // GPS READ
  while (GPS_Serial.available()) gps.encode(GPS_Serial.read());
  
  if (gps.location.isValid()) {
    lat = gps.location.lat();
    lon = gps.location.lng();
    
    // Update Firebase with GPS data (every 5 seconds)
    static unsigned long lastGPSUpdate = 0;
    if (millis() - lastGPSUpdate > 5000) {
      updateGPSInFirebase();
      lastGPSUpdate = millis();
    }
  }
  
  // Check Firebase for hardware control (every 2 seconds)
  static unsigned long lastFirebaseCheck = 0;
  if (millis() - lastFirebaseCheck > 2000) {
    checkHardwareControl();
    lastFirebaseCheck = millis();
  }
  
  // ... rest of your existing ultrasonic and motor control code ...
}
```

## Firebase Console Setup

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: `login-4e779`
3. Go to **Realtime Database**
4. Create a database (if not already created)
5. Go to **Database Secrets** (gear icon > Project Settings > Service Accounts)
6. Copy the **Database URL** and **Secret** for your ESP32 code

## Security Rules

Update your Firebase Realtime Database rules to allow read/write:

```json
{
  "rules": {
    "gps": {
      ".read": true,
      ".write": true
    },
    "hardware_control": {
      ".read": true,
      ".write": true
    },
    "profiling": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

**Note:** For production, use more restrictive rules. These rules allow public read/write for testing.

## Testing

1. Upload the modified code to your ESP32
2. Open Serial Monitor to see connection status
3. In your Flutter app:
   - Go to Profiling page and enable/disable hardware components
   - Go to Map page to see GPS location in real-time
4. Verify ESP32 responds to Firebase changes

## Troubleshooting

- **WiFi Connection Failed**: Check SSID and password
- **Firebase Connection Failed**: Verify FIREBASE_HOST and FIREBASE_AUTH
- **GPS Not Updating**: Ensure GPS module has satellite lock
- **Hardware Not Responding**: Check Firebase path and JSON structure

