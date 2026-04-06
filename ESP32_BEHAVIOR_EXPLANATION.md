# ESP32 Code Behavior Explanation

## Overview
This document explains how the ESP32 code works in combination with the Flutter app and Firebase.

## System Architecture

### 1. **Firebase Connection**
- **WiFi Primary**: ESP32 connects to WiFi first (preferred connection)
- **GPRS Fallback**: If WiFi fails, ESP32 attempts to connect via SIM800L GPRS (if enabled)
- **Connection Status**: ESP32 checks connection every 10 seconds and switches between WiFi/GPRS as needed

### 2. **Data Flow**

#### Flutter App → Firebase → ESP32
1. **Profiling Page**: User completes questionnaire (elderly or high-risk category)
2. **Settings Page**: User adjusts settings (language, volume, vibration intensity, etc.)
3. **Flutter saves to Firebase**:
   - `/profiling/{userId}` - User profiling data (category, questionnaire answers)
   - `/hardware_control` - Hardware control settings (motor, ultrasonic, audio, behaviors)
4. **ESP32 reads from Firebase**:
   - Reads `/hardware_control` every 2 seconds (when connected)
   - Updates local variables based on Firebase data
   - Controls hardware (motor, audio, ultrasonic) based on settings

#### ESP32 → Firebase → Flutter App
1. **GPS Updates**: ESP32 uploads GPS coordinates to `/gps` every 1 second (when GPS is valid)
2. **Flutter Map Page**: Reads GPS data in real-time and displays on Google Maps

## Hardware Control Behavior

### Default State (Before Profiling)
- `motorEnabled = false` - Motor is disabled
- `ultrasonicEnabled = false` - Ultrasonic sensor is disabled
- `audioEnabled = false` - Audio is disabled
- `userLanguage = "tagalog"` - Default language
- All behaviors use default values

### After Profiling (From Flutter App)

#### Elderly Category
ESP32 reads these behaviors from `/hardware_control`:
- `sensorRange` (50, 70, or 100 cm) - Detection range
- `scanningMode` ("continuous", "semi-continuous", "event-based")
- `vibrationMode` ("strong_repeated", "normal_pulse", "soft_pulse")
- `alertCooldown` (1, 2, or 3 seconds)
- `indoorMode` (true/false)
- `alertRepetition` (1 = LOW, 2 = Standard)
- `voiceDelay` (1000ms standard, 3000ms longer)

**Category Detection**: ESP32 detects "elderly" category when `sensorRange` is present in Firebase.

#### High-Risk Category
ESP32 reads these behaviors from `/hardware_control`:
- `sensorAngle` ("upward", "downward", "forward")
- `detectionLevel` ("head_chest" for upward angle)
- `voiceRepeat` (true/false) - Continuous voice assistance
- `depthDetection` (true/false) - Terrain depth detection
- `scanningMode` - Same as elderly

**Category Detection**: ESP32 detects "high-risk" category when `sensorAngle` or `detectionLevel` is present in Firebase.

## Ultrasonic Sensor Behavior

### Reading Distance
- **Always reads distance** for OLED display (even when `ultrasonicEnabled = false`)
- When enabled: Reads based on `scanningMode`:
  - `continuous`: Every loop (~200ms)
  - `semi-continuous`: Every 500ms
  - `event-based`: Every 1000ms (default)
- When disabled: Still reads every 2 seconds for OLED display

### Motor Control
- **Only activates when** `ultrasonicEnabled = true` AND `motorEnabled = true`
- Distance-based vibration:
  - **0-50cm**: Continuous vibration
  - **50-100cm**: Fast pulsing (150ms intervals)
  - **>100cm**: Motor stops
- Respects `vibrationMode` and `alertCooldown` settings
- PWM intensity based on `vibrationIntensity` preference

### Audio Control
- **Only activates when** `ultrasonicEnabled = true` AND `audioEnabled = true`
- Plays audio when object detected in sensing range:
  - Elderly: Uses `alertRepetition` (1 = file 002/005, 2 = file 003/006)
  - High-risk: Always uses file 002/005 (head-level warning)
- Respects `alertCooldown` and `voiceDelay` settings
- High-risk with `voiceRepeat = true`: Audio loops continuously

## OLED Display Behavior

### What's Displayed
1. **Distance Reading** (top left, large text):
   - Shows distance in cm (e.g., "45.2 CM")
   - Shows "--- CM" if no valid reading
   - **Always shows** even when `ultrasonicEnabled = false` (for debugging)

2. **Sensor Status** (if ultrasonic disabled):
   - Shows "SENSOR: OFF" below distance

3. **Connection Status**:
   - WiFi: OK/NO
   - Firebase: OK/NO
   - GPRS: OK/NO (if enabled)
   - Database: OK/NO

4. **GPS Status**:
   - Satellites count and FIX status

5. **Battery Percentage**:
   - Shows battery level (0-100%)

### OLED Issues Fixed
1. **OLED Dying**: Added re-initialization every 30 seconds to recover from I2C errors
2. **No Distance Display**: Now always shows distance even when sensor is disabled
3. **Display Updates**: Works without internet connection (reads sensor locally)

## Startup Sequence

1. **Boot** (0-2 seconds):
   - Initialize Serial, pins, OLED, DFPlayer, GPS
   - OLED shows "System Booting..."

2. **WiFi Connection** (2-15 seconds):
   - Connect to WiFi
   - OLED shows "Connecting WiFi..." then "WiFi Connected!"

3. **Firebase Connection** (15-20 seconds):
   - Initialize Firebase
   - Read language preference
   - OLED shows "Connecting Firebase..." then "Firebase OK!"

4. **Startup Audio** (20-25 seconds):
   - Play startup audio (001.mp3 for Tagalog, 004.mp3 for English)
   - Only plays if language is not "none"

5. **System Ready** (after 7 seconds from boot):
   - `systemReady = true`
   - Ultrasonic sensor enabled (after grace period)
   - GPS starts uploading to Firebase
   - Hardware control polling starts

## Common Issues and Solutions

### OLED Not Showing Distance
**Problem**: OLED shows blank or no "CM" text
**Solution**: 
- Distance is now always read (even when disabled)
- Check if `ultrasonicEnabledAfterDelay = true` (7 seconds after boot)
- Check Serial Monitor for distance readings

### OLED Dying/Not Working
**Problem**: OLED stops working when WiFi is unstable
**Solution**:
- Added automatic re-initialization every 30 seconds
- OLED now has error recovery
- Check I2C wiring (SDA=GPIO21, SCL=GPIO22)

### Sensor Not Detecting
**Problem**: No distance readings or motor/audio not activating
**Solution**:
- Check `ultrasonicEnabled` in Firebase (must be `true`)
- Check `motorEnabled` and `audioEnabled` in Firebase
- Verify sensor wiring (TRIG=GPIO18, ECHO=GPIO19)
- Check Serial Monitor for distance logs

### Firebase Not Updating
**Problem**: ESP32 not reading settings from Flutter app
**Solution**:
- Check WiFi/GPRS connection status
- Verify Firebase credentials are correct
- Check Serial Monitor for Firebase read errors
- Ensure Flutter app saved data to `/hardware_control`

### GPS Not Uploading
**Problem**: GPS coordinates not appearing on Flutter map
**Solution**:
- GPS needs satellite fix (check "Sats: X FIX" on OLED)
- Requires WiFi/GPRS connection
- Check Serial Monitor for GPS upload logs
- Verify GPS module wiring (RX=GPIO5, TX=GPIO4)

## Debugging Tips

1. **Serial Monitor**: Check for logs every 2 seconds showing:
   - Distance readings
   - Firebase hardware control values
   - Connection status
   - GPS status

2. **OLED Display**: Check if:
   - Distance is showing (even when disabled)
   - WiFi/Firebase status is OK
   - Battery percentage is updating

3. **Firebase Console**: Verify:
   - `/hardware_control` has correct values
   - `/gps` is being updated by ESP32
   - `/profiling/{userId}` has user data

4. **Flutter App**: Verify:
   - Profiling page saved successfully
   - Settings page saved successfully
   - Map page shows GPS location

## Behavior Summary

- **ESP32 always reads ultrasonic sensor** for OLED display
- **Motor and audio only activate** when `ultrasonicEnabled = true`
- **ESP32 detects user category** from behaviors (sensorRange = elderly, sensorAngle = high-risk)
- **OLED shows distance** even without internet connection
- **OLED auto-recovers** from I2C errors every 30 seconds
- **GPS uploads** every 1 second when valid and connected
- **Hardware control** updates every 2 seconds from Firebase
