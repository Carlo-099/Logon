# Firebase Error -120 Troubleshooting

## Error -120: Connection Issue

Error -120 typically means the ESP32 cannot connect to Firebase. Here are things to check:

### 1. Verify Database Rules

Go to Firebase Console → Realtime Database → Rules tab

Make sure your rules allow read access:

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

**Important:** Click "Publish" after updating rules!

### 2. Verify Database Secret

1. Go to Firebase Console
2. Click gear icon → Project Settings
3. Go to "Service Accounts" tab
4. Click "Database secrets" tab
5. Copy the secret (should match: `SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW`)

### 3. Verify Database URL

Your database URL should be:
```
login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app
```

**Note:** 
- No `https://` prefix
- No trailing slash `/`
- This is correct in your code

### 4. Test Database Connection

Try accessing your database URL directly in a browser:
```
https://login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app/.json?auth=SHLvLjohXVZ4Vs2PcVW6PvgXY7mqPaw73a0joSTW
```

If this works, you should see your database data. If it doesn't, there's an authentication issue.

### 5. Check WiFi Connection

Make sure ESP32 has stable WiFi connection:
- Serial Monitor should show: `✅ WiFi Connected! IP: 192.168.1.6`
- If WiFi keeps disconnecting, that could cause error -120

### 6. Alternative: Try Different Firebase Library Version

If error persists, you might need to:
1. Check your FirebaseESP32 library version
2. Try updating to latest version
3. Or try an older stable version

### 7. Check Serial Monitor for More Details

After uploading the updated code, you should see:
- `🔧 Initializing Firebase with host: ...`
- `🔍 Testing Firebase connection...`
- Either success or detailed error message

## Quick Fix Checklist

- [ ] Database rules allow read/write for `/hardware_control`
- [ ] Database secret is correct
- [ ] Database URL is correct (no https://, no trailing /)
- [ ] WiFi is connected and stable
- [ ] Rules are published (not just saved)
- [ ] Database exists and is not in test mode with expired rules

## Still Not Working?

If error -120 persists after checking all above:

1. **Try creating a new database secret:**
   - Firebase Console → Project Settings → Service Accounts
   - Generate new secret
   - Update ESP32 code with new secret

2. **Check if database region is correct:**
   - Your database is in `asia-southeast1`
   - Make sure this matches your Firebase project region

3. **Try simpler test:**
   - Instead of reading `/hardware_control`, try reading `/` (root)
   - This will tell us if it's a path issue or connection issue

Good luck! 🚀






