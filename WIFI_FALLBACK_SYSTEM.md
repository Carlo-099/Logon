# WiFi Fallback System - Multiple Internet Connections

## 📡 Overview

Ang ESP32 code ay may **WiFi Fallback System** na nag-try ng multiple WiFi networks sa priority order. Kapag hindi available ang primary network, automatic na mag-switch sa fallback network.

---

## 🔄 How It Works

### Priority Order:

1. **Primary WiFi:** `Ao/Hr` (Office/Home WiFi)
   - Unang susubukan
   - Kapag available, dito magco-connect
   - Uses office/home internet connection

2. **Fallback WiFi:** `iPhone` (Smartphone Hotspot)
   - Susubukan lang kapag hindi available ang `Ao/Hr`
   - Uses phone's mobile data
   - Automatic na mag-activate kapag primary WiFi walang signal

---

## 📋 WiFi Networks Configuration

### Current Setup:

```cpp
const WiFiNetwork wifiNetworks[] = {
  {"Ao/Hr", "@AoHR_employee@spcc2024", "Primary WiFi (Ao/Hr)"},           // Primary
  {"iPhone", "elle2025", "Fallback Hotspot (iPhone - Phone Data)"}        // Fallback
};
```

### Network Details:

| Priority | SSID | Password | Description | Internet Source |
|----------|------|----------|-------------|----------------|
| **1** | `Ao/Hr` | `@AoHR_employee@spcc2024` | Primary WiFi | Office/Home Internet |
| **2** | `iPhone` | `elle2025` | Fallback Hotspot | Phone Mobile Data |

---

## 🎯 Connection Flow

```
ESP32 Boots
    ↓
Try WiFi Network #1: "Ao/Hr"
    ├─→ Success? → Connect & Use Ao/Hr WiFi ✅
    └─→ Failed? → Try WiFi Network #2: "iPhone"
            ├─→ Success? → Connect & Use iPhone Hotspot ✅
            └─→ Failed? → Try GPRS (if enabled) 📡
                    └─→ All Failed? → No Internet ❌
```

---

## 📊 Connection Behavior

### Scenario 1: Ao/Hr Available
```
1. ESP32 tries "Ao/Hr" → ✅ Connected
2. Uses Ao/Hr WiFi (office/home internet)
3. iPhone hotspot NOT needed
```

### Scenario 2: Ao/Hr Not Available, iPhone Available
```
1. ESP32 tries "Ao/Hr" → ❌ Failed (out of range)
2. ESP32 tries "iPhone" → ✅ Connected
3. Uses iPhone hotspot (phone's mobile data)
4. System continues normally
```

### Scenario 3: Both WiFi Networks Not Available
```
1. ESP32 tries "Ao/Hr" → ❌ Failed
2. ESP32 tries "iPhone" → ❌ Failed (hotspot not enabled)
3. ESP32 tries GPRS (if enabled) → ✅/❌
4. If all fail → System continues without internet
```

---

## 🔧 How to Add/Modify WiFi Networks

### To Add a New WiFi Network:

1. **Edit the `wifiNetworks` array** in `ESP32_FINAL_CODE.ino`:

```cpp
const WiFiNetwork wifiNetworks[] = {
  {"Ao/Hr", "@AoHR_employee@spcc2024", "Primary WiFi (Ao/Hr)"},
  {"iPhone", "elle2025", "Fallback Hotspot (iPhone - Phone Data)"},
  {"NewNetwork", "password123", "Third Network"},  // Add new network here
};
```

2. **Update `wifiNetworkCount`** (automatic - no need to change)

3. **Upload code to ESP32**

### To Change Priority:

- **Reorder the array** - networks are tried in array order
- First network = highest priority
- Last network = lowest priority

---

## 📱 iPhone Hotspot Setup

### To Enable iPhone Hotspot:

1. **Settings** → **Personal Hotspot**
2. **Turn on "Allow Others to Join"**
3. **Set Password:** `elle2025` (or update in code)
4. **Note SSID:** Usually "iPhone" (or your iPhone name)

### Important Notes:

- **Data Usage:** iPhone hotspot uses your mobile data
- **Battery:** Hotspot drains iPhone battery faster
- **Range:** Hotspot range is limited (~10-15 meters)
- **Auto-Connect:** ESP32 will auto-connect kapag Ao/Hr unavailable

---

## 🔍 Serial Monitor Output

### Successful Connection to Primary:

```
========================================
📶 STARTING WIFI CONNECTION
========================================
   Trying 2 WiFi network(s) in order...

----------------------------------------
📶 Attempt 1 of 2: Primary WiFi (Ao/Hr)
   SSID: Ao/Hr
.....................
========================================
✅ WiFi Connected! Primary WiFi (Ao/Hr)
   SSID: Ao/Hr
   IP Address: 192.168.1.100
   Signal Strength (RSSI): -45 dBm
========================================
```

### Fallback to iPhone:

```
========================================
📶 STARTING WIFI CONNECTION
========================================
   Trying 2 WiFi network(s) in order...

----------------------------------------
📶 Attempt 1 of 2: Primary WiFi (Ao/Hr)
   SSID: Ao/Hr
.....................
❌ Failed to connect to Ao/Hr (Primary WiFi (Ao/Hr))
   WiFi Status Code: 6
   ⏭️  Trying next WiFi network...

----------------------------------------
📶 Attempt 2 of 2: Fallback Hotspot (iPhone - Phone Data)
   SSID: iPhone
.....................
========================================
✅ WiFi Connected! Fallback Hotspot (iPhone - Phone Data)
   SSID: iPhone
   IP Address: 172.20.10.2
   Signal Strength (RSSI): -55 dBm
========================================
```

### All Networks Failed:

```
========================================
📶 STARTING WIFI CONNECTION
========================================
   Trying 2 WiFi network(s) in order...

----------------------------------------
📶 Attempt 1 of 2: Primary WiFi (Ao/Hr)
   SSID: Ao/Hr
.....................
❌ Failed to connect to Ao/Hr (Primary WiFi (Ao/Hr))
   ⏭️  Trying next WiFi network...

----------------------------------------
📶 Attempt 2 of 2: Fallback Hotspot (iPhone - Phone Data)
   SSID: iPhone
.....................
❌ Failed to connect to iPhone (Fallback Hotspot (iPhone - Phone Data))

========================================
❌ ALL WiFi Networks Failed!
========================================
   Tried the following networks:
   1. Ao/Hr (Primary WiFi (Ao/Hr))
   2. iPhone (Fallback Hotspot (iPhone - Phone Data))

   ⚠️  System will continue without WiFi.
   📡 Will try GPRS fallback (if enabled)...
========================================
```

---

## 🖥️ OLED Display

### During Connection:

```
WiFi 1/2
Ao/Hr
```

### After Connection:

```
WiFi Connected!
SSID: Ao/Hr
IP: 192.168.1.100
```

### Connection Failed:

```
WiFi Failed!
All networks
unavailable
```

---

## ⚙️ Technical Details

### Connection Attempts:

- **Per Network:** 30 attempts × 500ms = 15 seconds max per network
- **Total Time:** Up to 30 seconds (2 networks × 15 seconds)
- **Retry Logic:** Tries networks sequentially, stops at first success

### WiFi Status Codes:

| Code | Meaning |
|------|---------|
| 0 | WL_IDLE_STATUS - WiFi changing statuses |
| 1 | WL_NO_SSID_AVAIL - SSID not found |
| 3 | WL_CONNECTED - Connected successfully |
| 4 | WL_CONNECT_FAILED - Connection failed |
| 5 | WL_CONNECTION_LOST - Connection lost |
| 6 | WL_DISCONNECTED - Disconnected |

---

## ✅ Benefits

1. **Automatic Fallback:** No manual switching needed
2. **Seamless Transition:** System continues working even if primary WiFi fails
3. **Mobile Data Backup:** iPhone hotspot provides internet when WiFi unavailable
4. **Flexible:** Easy to add more networks
5. **Priority-Based:** Always tries best connection first

---

## 🔄 Reconnection Logic

### During Operation:

- ESP32 checks WiFi connection every 10 seconds
- If WiFi disconnects, automatic reconnection attempt
- Tries networks in same priority order
- Falls back to GPRS if all WiFi networks fail

### Connection Management:

- **WiFi Preferred:** Always tries WiFi first
- **GPRS Fallback:** Only uses GPRS if all WiFi networks fail
- **Auto-Switch:** Switches between WiFi networks automatically

---

## 📝 Important Notes

1. **iPhone Hotspot:**
   - Dapat naka-enable ang Personal Hotspot sa iPhone
   - Uses mobile data (may data charges)
   - Limited range (10-15 meters)

2. **Password Security:**
   - WiFi passwords ay naka-hardcode sa code
   - For production, consider using secure storage

3. **Network Priority:**
   - Networks ay tinatry sa array order
   - First network = highest priority

4. **GPRS Fallback:**
   - If all WiFi networks fail, ESP32 tries GPRS (if enabled)
   - GPRS uses SIM card data (may charges)

---

## 🎯 Quick Reference

**Primary WiFi:** `Ao/Hr` (Office/Home Internet)  
**Fallback WiFi:** `iPhone` (Phone Mobile Data)  
**Connection Time:** Up to 30 seconds (2 networks)  
**Auto-Reconnect:** Every 10 seconds if disconnected  
**GPRS Fallback:** Enabled (if SIM800L configured)

---

## 🔧 Troubleshooting

### Problem: ESP32 hindi nagco-connect sa iPhone hotspot

**Solutions:**
1. Check kung naka-enable ang Personal Hotspot sa iPhone
2. Verify SSID name (dapat "iPhone" o exact name)
3. Check password (dapat `elle2025`)
4. Move ESP32 closer to iPhone (within 10-15 meters)
5. Check iPhone mobile data (dapat may signal)

### Problem: ESP32 laging nagco-connect sa iPhone kahit available ang Ao/Hr

**Solutions:**
1. Check Ao/Hr WiFi signal strength
2. Verify Ao/Hr password
3. Check kung naka-broadcast ang SSID
4. Move ESP32 closer to Ao/Hr router

### Problem: Parehong networks failed

**Solutions:**
1. Check WiFi passwords
2. Verify SSID names
3. Check router/hotspot status
4. Enable iPhone Personal Hotspot
5. Check ESP32 WiFi hardware

---

## 📍 Code Location

**File:** `ESP32_FINAL_CODE.ino`  
**WiFi Configuration:** Lines 97-113  
**Connection Code:** Lines 1696-1820
