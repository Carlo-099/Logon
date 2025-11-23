# ESP32 Integration Steps - Quick Guide

## ✅ What's Already Done
- Flutter app is working
- Profiling page saves data to Firebase
- Map page displays Google Maps
- Firebase Realtime Database is configured
- Database structure is created with `hardware_control` and `profiling` nodes

## 🔧 What You Need to Do Now

### Step 1: Install Required Arduino Libraries

1. **Open Arduino IDE**
2. **Go to Sketch > Include Library > Manage Libraries**
3. **Install these libraries:**
   - Search for `FirebaseESP32` by **Mobizt** → Install
   - Search for `ArduinoJson` by **Benoit Blanchon** → Install (version 6.x)

### Step 2: Update Your ESP32 Code

1. **Open your existing ESP32 code** (the one with GPS, ultrasonic, motor, etc.)

2. **Add these includes at the top:**
   ```cpp
   #include <WiFi.h>
   #include <FirebaseESP32.h>
   #include <ArduinoJson.h>
   ```

3. **Add WiFi and Firebase configuration** (after your existing #define statements):
   ```cpp
   // WiFi credentials - REPLACE WITH YOUR ACTUAL VALUES
   #define WIFI_SSID "YOUR_WIFI_NETWORK_NAME"
   #define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
   
   // Firebase configuration
   #define FIREBASE_HOST "login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app"
   #define FIREBASE_AUTH "SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW"
   
   // Firebase objects
   FirebaseData firebaseData;
   FirebaseJson json;
   ```

4. **Add timing variables** (with your other global variables):
   ```cpp
   unsigned long lastGPSUpdate = 0;
   unsigned long lastHardwareCheck = 0;
   bool motorEnabled = false;
   bool ultrasonicEnabled = false;
   bool audioEnabled = false;
   ```

### Step 3: Add Firebase Functions

Copy these two functions into your code (see `ESP32_CODE_EXAMPLE.ino` for full code):

1. **`updateGPSInFirebase()`** - Writes GPS coordinates to Firebase
2. **`checkHardwareControl()`** - Reads hardware control settings from Firebase

### Step 4: Modify setup() Function

Add this code at the **END** of your existing `setup()` function:

```cpp
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
  Firebase.setReadTimeout(firebaseData, 1000 * 60);
  Firebase.setwriteSizeLimit(firebaseData, "tiny");
  
  Serial.println("✅ Firebase Connected");
```

### Step 5: Modify loop() Function

Add this code in your `loop()` function (after GPS reading):

```cpp
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
```

### Step 6: Update Your Ultrasonic Logic

Modify your existing ultrasonic/motor logic to respect Firebase control:

- Check `motorEnabled` before running motor
- Check `ultrasonicEnabled` before processing ultrasonic
- Check `audioEnabled` before playing audio

See `ESP32_CODE_EXAMPLE.ino` for detailed examples.

### Step 7: Upload and Test

1. **Upload the modified code to ESP32**
2. **Open Serial Monitor** (115200 baud)
3. **Watch for:**
   - ✅ WiFi connection message
   - ✅ Firebase connection message
   - ✅ GPS updates to Firebase
   - ✅ Hardware control reads from Firebase

## 🧪 Testing the Integration

### Test 1: GPS Tracking
1. Ensure ESP32 has GPS lock (wait for valid GPS coordinates)
2. Open Flutter app → Map page
3. You should see ESP32 location on the map
4. Location should update every 5 seconds

### Test 2: Hardware Control
1. Open Flutter app → Profiling page
2. Toggle "DC Motor" to **OFF**
3. Click "Save Profiling"
4. Check ESP32 Serial Monitor - motor should stop
5. Toggle "DC Motor" to **ON** and save
6. Motor should resume

### Test 3: Real-time Updates
1. Keep Flutter app Map page open
2. Move ESP32 (if portable) or wait for GPS to update
3. Map should update automatically
4. Profiling changes should affect ESP32 within 2 seconds

## 🐛 Troubleshooting

### ESP32 Can't Connect to WiFi
- Verify WiFi SSID and password are correct
- Check WiFi signal strength
- Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)

### Firebase Connection Failed
- Verify FIREBASE_HOST is correct (no http://, no trailing slash)
- Verify FIREBASE_AUTH (database secret) is correct
- Check Serial Monitor for specific error messages

### GPS Not Updating in Firebase
- Ensure GPS module has satellite lock
- Check Serial Monitor for GPS validity
- Verify `gps.location.isValid()` returns true

### Hardware Not Responding
- Check Serial Monitor for Firebase read errors
- Verify data structure in Firebase matches expected format
- Ensure timing variables are working (check lastHardwareCheck)

## 📝 Quick Checklist

- [ ] Arduino libraries installed (FirebaseESP32, ArduinoJson)
- [ ] WiFi credentials added to code
- [ ] Firebase host and auth added to code
- [ ] Firebase functions added (updateGPSInFirebase, checkHardwareControl)
- [ ] setup() modified with WiFi and Firebase init
- [ ] loop() modified with Firebase updates
- [ ] Ultrasonic/motor logic respects Firebase control
- [ ] Code uploaded to ESP32
- [ ] Serial Monitor shows successful connections
- [ ] GPS data appears in Firebase
- [ ] Map page shows ESP32 location
- [ ] Profiling page controls ESP32 hardware

## 🎉 Success Indicators

You'll know it's working when:
1. ✅ Serial Monitor shows "✅ Firebase Connected"
2. ✅ Serial Monitor shows "✅ GPS updated in Firebase" every 5 seconds
3. ✅ Flutter Map page shows ESP32 location
4. ✅ Toggling hardware in Profiling page affects ESP32 behavior
5. ✅ Firebase Realtime Database shows GPS data updating

Good luck! 🚀






