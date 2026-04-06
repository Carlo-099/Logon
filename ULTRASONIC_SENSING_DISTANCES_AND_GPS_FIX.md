# Ultrasonic Sensing Distances at GPS Fix Detection

## 📏 ULTRASONIC SENSING DISTANCES

### Overall Sensor Limits (Hardware Constraints)

| Parameter | Value | Description |
|-----------|-------|-------------|
| **MIN_VALID_DISTANCE** | **2.0 cm** | Minimum valid distance - readings below this are ignored (false readings/noise) |
| **MAX_VALID_DISTANCE** | **400.0 cm** | Maximum valid distance - readings above this are invalid |

**Note:** HC-SR04 ultrasonic sensors are not accurate below 2cm. Readings below 2cm are usually false readings or noise.

---

### Detection Range (Sensing Distance)

Ang **sensing distance** ay ang range kung saan ang motor at audio ay mag-a-activate. Ito ay nag-iiba depende sa profiling settings.

#### Default Values (Before Profiling)
- **sensingDistanceMin:** 50.0 cm
- **sensingDistanceMax:** 100.0 cm

---

### ELDERLY CATEGORY - Sensing Distances

#### 1. Based on sensorRange (E1/E2 answers)

| sensorRange (cm) | sensingDistanceMin (cm) | sensingDistanceMax (cm) | Calculation |
|------------------|------------------------|------------------------|-------------|
| **50 cm** | **25.0 cm** | **50.0 cm** | Min = 50% of max |
| **70 cm** | **35.0 cm** | **70.0 cm** | Min = 50% of max |
| **100 cm** | **50.0 cm** | **100.0 cm** | Min = 50% of max |

**Formula:** `sensingDistanceMin = sensorRange * 0.5` (50% of max)

**Example:**
- E1 = "Oo, madalas" → sensorRange = 100 cm → sensingDistanceMin = 50 cm, sensingDistanceMax = 100 cm
- E1 = "Paminsan-minsan" → sensorRange = 70 cm → sensingDistanceMin = 35 cm, sensingDistanceMax = 70 cm
- E1 = "Hindi" → sensorRange = 50 cm → sensingDistanceMin = 25 cm, sensingDistanceMax = 50 cm

---

#### 2. Indoor Mode (E3 = "Oo")

| Mode | sensingDistanceMin (cm) | sensingDistanceMax (cm) | Override |
|------|------------------------|------------------------|----------|
| **Indoor Mode ON** | **30.0 cm** | **80.0 cm** | Overrides sensorRange |
| **Indoor Mode OFF** | Uses sensorRange | Uses sensorRange | Uses E1/E2 sensorRange |

**Note:** Kung E3 = "Oo" (indoorMode = true), ang sensing distance ay naka-set sa 30-80 cm, kahit ano pa ang sensorRange.

---

### HIGH-RISK CATEGORY - Sensing Distances

#### Based on usageLocation (if sensorRange not set)

| usageLocation | sensingDistanceMin (cm) | sensingDistanceMax (cm) |
|---------------|------------------------|------------------------|
| **indoors** | **30.0 cm** | **80.0 cm** |
| **outdoors** | **50.0 cm** | **100.0 cm** |

**Note:** High-risk category ay walang sensorRange (elderly lang may sensorRange), kaya gumagamit ng usageLocation.

---

## 📊 COMPLETE SENSING DISTANCE SUMMARY

### All Possible Sensing Distance Ranges:

| Category | Condition | Min (cm) | Max (cm) | Source |
|----------|-----------|----------|----------|--------|
| **Elderly** | sensorRange = 50 cm | 25.0 | 50.0 | E1/E2 |
| **Elderly** | sensorRange = 70 cm | 35.0 | 70.0 | E1/E2 |
| **Elderly** | sensorRange = 100 cm | 50.0 | 100.0 | E1/E2 |
| **Elderly** | indoorMode = true | 30.0 | 80.0 | E3 (overrides sensorRange) |
| **High-risk** | usageLocation = "indoors" | 30.0 | 80.0 | Settings |
| **High-risk** | usageLocation = "outdoors" | 50.0 | 100.0 | Settings |
| **Default** | No profiling data | 50.0 | 100.0 | Default values |

---

## 🎯 How Sensing Distance Works

### Detection Logic:

1. **Object Detected:**
   - Kung `distance >= sensingDistanceMin` AND `distance <= sensingDistanceMax`
   - → Motor at Audio ACTIVATE

2. **Object Too Close:**
   - Kung `distance < sensingDistanceMin`
   - → Motor at Audio STOP (ignored - too close)

3. **Object Too Far:**
   - Kung `distance > sensingDistanceMax`
   - → Motor at Audio STOP (no object detected)

4. **Invalid Reading:**
   - Kung `distance < 2.0 cm` o `distance >= 400.0 cm`
   - → Motor at Audio STOP (invalid reading)

---

## 📡 GPS FIX DETECTION

### How to Know if GPS Has a Fix Signal

#### 1. **OLED Display Indicator**

Sa OLED display, makikita mo:
```
Sats: X FIX    ← May GPS fix
Sats: X ---    ← Walang GPS fix pa
```

**Location sa OLED:** Bottom left area

**Meaning:**
- **"FIX"** = GPS has valid location fix
- **"---"** = GPS walang fix pa (waiting for satellites)

---

#### 2. **Serial Monitor Logs**

##### GPS Status Log (Every 2 seconds):
```
═══════════════════════════════════
📡 GPS Status - Satellites: 8, Valid: YES ✅
   Lat: 14.599512, Lon: 120.984222
═══════════════════════════════════
```

**Indicators:**
- **"Valid: YES ✅"** = May GPS fix
- **"Valid: NO ❌"** = Walang GPS fix pa
- **Satellites: X** = Number of satellites detected

---

##### GPS Upload Condition Check (Every 3 seconds):
```
🔍 Checking Firebase upload conditions:
   systemReady: YES ✅
   WiFi Connected: YES ✅
   firebaseReady: YES ✅
   GPS Valid: YES ✅
═══════════════════════════════════
```

**Meaning:**
- Lahat ng conditions (including GPS Valid) ay dapat "YES ✅" para ma-upload ang GPS

---

##### GPS Upload Success:
```
✅ All conditions met! Uploading GPS to Firebase...
✅✅✅ GPS SUCCESSFULLY UPDATED IN FIREBASE! ✅✅✅
   Via: WiFi
```

**Meaning:**
- GPS coordinates ay na-upload na sa Firebase

---

##### GPS Not Ready Warnings:

**Scenario 1: GPS valid pero walang connection**
```
⚠️ GPS valid but CAN'T upload - WiFi not connected
```

**Scenario 2: GPS walang fix pa**
```
⚠️ GPS has satellites but location not valid yet. Waiting for fix...
```

---

#### 3. **Code Logic for GPS Fix**

##### GPS Fix Detection:
```cpp
if (gps.location.isValid()) {
    // GPS HAS FIX - coordinates are valid
    // Can upload to Firebase
} else {
    // GPS NO FIX - waiting for satellites
    // Cannot upload to Firebase
}
```

##### GPS Upload Requirements (ALL must be true):
1. ✅ `systemReady = true` (7 seconds after boot)
2. ✅ `WiFi.status() == WL_CONNECTED` o GPRS connected
3. ✅ `firebaseReady = true` (Firebase initialized)
4. ✅ `gps.location.isValid() = true` (GPS has fix) ⭐ **MOST IMPORTANT**

---

## 🔍 How GPS Fix Works

### GPS Module Behavior:

1. **Startup:**
   - GPS module ay nagsisimula mag-scan para sa satellites
   - Kailangan ng **clear view of sky** para makakuha ng signal
   - Usually takes **30 seconds to 5 minutes** para makakuha ng fix

2. **Satellite Detection:**
   - GPS module ay makikita ang satellites (`gps.satellites.value()`)
   - Pero hindi pa valid ang location hanggang may **fix**

3. **GPS Fix:**
   - Kailangan ng **at least 4 satellites** para makakuha ng fix
   - Kapag may fix na, `gps.location.isValid()` = `true`
   - Coordinates ay accurate na

4. **Upload to Firebase:**
   - Kapag may fix na, ESP32 ay mag-u-upload ng coordinates every 1 second
   - Coordinates ay makikita sa Flutter Map page

---

## 📊 GPS Status Indicators Summary

### OLED Display:
| Display | Meaning |
|---------|---------|
| `Sats: 0 ---` | Walang satellites detected |
| `Sats: 4 ---` | May satellites pero walang fix pa |
| `Sats: 8 FIX` | May GPS fix na! ✅ |

### Serial Monitor:
| Log | Meaning |
|-----|---------|
| `GPS Valid: YES ✅` | May GPS fix - ready to upload |
| `GPS Valid: NO ❌` | Walang GPS fix - waiting |
| `Satellites: 0` | Walang satellites detected |
| `Satellites: 4+` | May satellites (need 4+ for fix) |
| `✅ GPS SUCCESSFULLY UPDATED` | Coordinates uploaded to Firebase |

---

## 🎯 Complete GPS Fix Flow

```
1. ESP32 Boots
   ↓
2. GPS Module Initializes
   ↓
3. GPS Scans for Satellites
   ├─→ Satellites: 0 → "Sats: 0 ---"
   ├─→ Satellites: 1-3 → "Sats: X ---" (not enough for fix)
   └─→ Satellites: 4+ → "Sats: X ---" (waiting for fix)
   ↓
4. GPS Gets Fix (4+ satellites)
   ├─→ gps.location.isValid() = true
   ├─→ OLED shows "Sats: X FIX"
   └─→ Serial shows "GPS Valid: YES ✅"
   ↓
5. Check Upload Conditions
   ├─→ systemReady? ✅
   ├─→ WiFi/GPRS connected? ✅
   ├─→ firebaseReady? ✅
   └─→ GPS Valid? ✅
   ↓
6. Upload GPS to Firebase
   ├─→ Every 1 second (GPS_UPDATE_INTERVAL)
   ├─→ Serial: "✅ GPS SUCCESSFULLY UPDATED"
   └─→ Flutter Map shows location
```

---

## ⚠️ Common GPS Issues

### Problem: GPS walang fix
**Possible Causes:**
1. **Walang clear view of sky** - GPS module ay dapat nakaharap sa langit
2. **Indoor location** - GPS ay hindi gumagana sa loob ng bahay
3. **GPS module wiring** - Check RX/TX connections (RX=GPIO5, TX=GPIO4)
4. **GPS module power** - Check kung may power ang GPS module
5. **Antenna issue** - Check kung naka-connect ang GPS antenna

**Solutions:**
- Ilagay ang device sa **outdoor location** na may clear view of sky
- Wait **30 seconds to 5 minutes** para makakuha ng fix
- Check Serial Monitor para sa satellite count
- Verify GPS module wiring

---

### Problem: GPS may satellites pero walang fix
**Possible Causes:**
1. **Not enough satellites** - Kailangan ng at least 4 satellites
2. **Weak signal** - Satellites ay masyadong malayo
3. **GPS module still initializing** - Wait lang ng konti

**Solutions:**
- Wait longer (sometimes takes 2-5 minutes)
- Move to better location (open area)
- Check Serial Monitor - dapat may 4+ satellites

---

### Problem: GPS fix pero hindi na-u-upload
**Possible Causes:**
1. **WiFi not connected** - Check WiFi status
2. **Firebase not ready** - Check Firebase connection
3. **System not ready** - Wait 7 seconds after boot

**Solutions:**
- Check Serial Monitor para sa blocking condition
- Verify WiFi/GPRS connection
- Check Firebase credentials

---

## 📝 Quick Reference

### Sensing Distances:
- **Minimum:** 2.0 cm (hardware limit)
- **Maximum:** 400.0 cm (hardware limit)
- **Detection Range:** 25-100 cm (depende sa profiling)
- **Indoor Mode:** 30-80 cm (fixed)
- **Outdoor Mode:** 50-100 cm (fixed)

### GPS Fix:
- **Indicator:** `gps.location.isValid() = true`
- **OLED:** Shows "FIX" instead of "---"
- **Serial:** Shows "GPS Valid: YES ✅"
- **Requirement:** At least 4 satellites
- **Upload:** Every 1 second kapag may fix

---

## 🎯 Testing Checklist

### Ultrasonic Sensing:
1. ✅ Check Serial Monitor para sa sensing distance range
2. ✅ Test different profiling settings (elderly/high-risk)
3. ✅ Verify motor/audio activates sa correct distance range
4. ✅ Check OLED display para sa distance readings

### GPS Fix:
1. ✅ Check OLED display - dapat may "FIX" indicator
2. ✅ Check Serial Monitor - dapat "GPS Valid: YES ✅"
3. ✅ Verify satellite count - dapat 4+ satellites
4. ✅ Check Firebase - dapat may GPS coordinates
5. ✅ Check Flutter Map - dapat may marker sa map
