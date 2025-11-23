# Setup Instructions

## Flutter App Setup

### 1. Install Dependencies
Run the following command to install all required packages:
```bash
flutter pub get
```

### 2. Configure Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable **Maps SDK for Android** API
4. Go to **Credentials** and create an API key
5. Restrict the API key to Android apps (optional but recommended)
6. Open `android/app/src/main/AndroidManifest.xml`
7. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE"/>
```

### 3. Configure Firebase Realtime Database

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `login-4e779`
3. Go to **Realtime Database**
4. Click **Create Database**
5. Choose a location (e.g., `us-central1`)
6. Start in **test mode** for development (or configure security rules)

### 4. Firebase Security Rules

Update your Firebase Realtime Database rules:

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

**Important:** For production, use more restrictive rules. The above allows public read/write for `gps` and `hardware_control` which is needed for ESP32 communication.

## ESP32 Setup

See `ESP32_FIREBASE_INTEGRATION.md` for detailed ESP32 integration instructions.

### Quick Summary:
1. Install `FirebaseESP32` library in Arduino IDE
2. Add WiFi credentials
3. Add Firebase host and authentication
4. Modify your code to:
   - Write GPS coordinates to Firebase every 5 seconds
   - Read hardware control settings from Firebase every 2 seconds
5. Control hardware based on Firebase values

## How It Works

### Profiling Page
- User enters name and toggles hardware components (DC Motor, Ultrasonic, DFPlayer, OLED, GPS)
- Data is saved to Firebase under `/profiling/{userId}`
- Hardware control settings are saved to `/hardware_control`
- ESP32 reads from `/hardware_control` and controls hardware accordingly

### Map Page
- ESP32 writes GPS coordinates to `/gps` in Firebase
- Flutter app reads GPS data in real-time
- Google Maps displays the ESP32 location with a marker
- Location updates automatically when ESP32 sends new coordinates

## Testing

1. **Test Profiling:**
   - Login to the app
   - Click "Profiling" button
   - Enter your name
   - Toggle hardware components
   - Click "Save Profiling"
   - Verify ESP32 responds to changes

2. **Test Map:**
   - Ensure ESP32 is running and has GPS lock
   - Click "Map" button
   - You should see the ESP32 location on the map
   - Location should update in real-time

## Troubleshooting

### Google Maps Not Showing
- Verify API key is correct in `AndroidManifest.xml`
- Check that Maps SDK for Android is enabled in Google Cloud Console
- Ensure internet permission is granted

### Firebase Connection Issues
- Verify Firebase Realtime Database is created
- Check security rules allow read/write
- Verify ESP32 has correct Firebase host and auth credentials

### GPS Not Updating
- Ensure ESP32 has GPS module connected and has satellite lock
- Check ESP32 Serial Monitor for GPS data
- Verify ESP32 is writing to Firebase `/gps` path

### Hardware Not Responding
- Check ESP32 is reading from `/hardware_control` path
- Verify Firebase data structure matches expected format
- Check ESP32 Serial Monitor for Firebase read errors






