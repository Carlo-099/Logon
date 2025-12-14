# 🔧 Coin Vibration Motor Fix

## ❌ **Problem:**
- Coin vibration motor (smartphone-type) hindi gumagana
- Kahit na-activate na sa profiling, walang vibration
- Motor type: **Coin vibration motor** (hindi regular DC motor)

---

## ✅ **Solution Applied:**

### **1. Increased PWM Values for Coin Motor**
- **Old PWM:** 60-120 (too low for coin motor)
- **New PWM:** 150-255 (proper for coin motor)
- **Default:** 200 (medium intensity)

### **2. Added Coin Motor Mode**
- `USE_COIN_MOTOR_MODE = 1` (enabled by default)
- Automatically uses higher PWM values
- Better suited for coin vibration motors

### **3. Enhanced Vibration Intensity Settings**
- **Low:** PWM 150 (was 60)
- **Medium:** PWM 200 (was 90)
- **High:** PWM 255 (was 120)

### **4. Added Motor Test Function**
- `testMotor()` function to verify motor works
- Tests different PWM levels
- Can be called on startup for testing

---

## 🔌 **Wiring for Coin Vibration Motor:**

### **Option 1: Using L298N (Current Setup)**
```
Coin Motor (+) → L298N OUT1 (or OUT2)
Coin Motor (-) → L298N OUT2 (or OUT1)
L298N ENA → ESP32 GPIO 25
L298N IN1 → ESP32 GPIO 26
L298N IN2 → ESP32 GPIO 27
L298N VCC → 5V (or 12V if available)
L298N GND → ESP32 GND
```

### **Option 2: Direct Drive (Recommended for Coin Motor)**
If L298N doesn't work, use a transistor/MOSFET:
```
Coin Motor (+) → 3.3V or 5V
Coin Motor (-) → Transistor Collector (or MOSFET Drain)
Transistor Emitter → GND (or MOSFET Source → GND)
Transistor Base → ESP32 GPIO 25 (via 1kΩ resistor)
ESP32 GND → Common GND
```

**Transistor:** 2N2222 or similar NPN
**MOSFET:** 2N7000 or IRLZ44N (better for higher current)

---

## 🧪 **Testing the Motor:**

### **Method 1: Uncomment Test Function**
In `setup()`, uncomment this line:
```cpp
// Optional: Uncomment the line below to test motor on startup
testMotor();
```

Then upload and check Serial Monitor. You should see:
```
🧪 TESTING VIBRATION MOTOR
========================================
   Motor Type: COIN MOTOR
   Current PWM: 200/255
   Testing motor for 3 seconds...
   Test 1: Low intensity (PWM 150)...
   Test 2: Medium intensity (PWM 200)...
   Test 3: High intensity (PWM 255)...
   Test 4: Pulse pattern (5 pulses)...
✅ Motor test complete!
```

### **Method 2: Check Serial Monitor During Operation**
When object is detected, you should see:
```
🔔 Motor: Fast pulse (distance 45.2cm, 30-80cm range, PWM: 200/255, motorEnabled: true, ultrasonicEnabled: true, Coin motor: YES)
```

---

## 🔍 **Troubleshooting:**

### **Motor Still Not Working?**

#### **1. Check Firebase Settings:**
- [ ] `/hardware_control/motorEnabled` = `true`
- [ ] `/hardware_control/ultrasonicEnabled` = `true`
- [ ] `/hardware_control/vibrationIntensity` = `"low"`, `"medium"`, or `"high"`

#### **2. Check Serial Monitor:**
Look for these messages:
- ✅ `🔔 Motor: Fast pulse...` = Motor should be vibrating
- ❌ `🔔 Motor: DISABLED in Firebase` = `motorEnabled = false`
- ❌ `🔔 Motor: Stopped (distance XXcm < 30cm)` = Object too close
- ❌ `🔔 Motor: Stopped (distance XXcm > 80cm)` = Object too far

#### **3. Check Wiring:**
- [ ] ENA connected to GPIO 25
- [ ] IN1 connected to GPIO 26
- [ ] IN2 connected to GPIO 27
- [ ] L298N has power (5V or 12V)
- [ ] Coin motor connected to L298N OUT1 and OUT2
- [ ] All GNDs connected together

#### **4. Check PWM Values:**
If motor is too weak, increase PWM:
- Edit line 51: `#define VIBRATION_MOTOR_PWM 200` → try `220` or `255`
- Or change vibration intensity in Firebase to "high"

#### **5. Test Motor Directly:**
Add this code in `loop()` temporarily:
```cpp
// Test motor - remove after testing
static bool motorTested = false;
if (!motorTested && millis() > 10000) {
  testMotor();
  motorTested = true;
}
```

---

## 📊 **PWM Values Explained:**

### **For Coin Motor (Current Settings):**
- **PWM 150:** Low intensity (weak vibration)
- **PWM 200:** Medium intensity (normal vibration) - **DEFAULT**
- **PWM 255:** High intensity (strong vibration)

### **Why Higher PWM?**
- Coin motors need more power to overcome inertia
- L298N might have voltage drop, so higher PWM compensates
- Coin motors typically rated 3-5V, but need full power to vibrate properly

---

## ⚙️ **Code Changes Summary:**

1. **Line 46-52:** Added `USE_COIN_MOTOR_MODE` and increased default PWM to 200
2. **Line 130-135:** Initialize PWM based on coin motor mode
3. **Line 977-1000:** Updated vibration intensity to use higher PWM (150-255)
4. **Line 1652-1685:** Enhanced motor control with coin motor support
5. **Line 148-195:** Added `testMotor()` function for testing

---

## 🎯 **Expected Behavior:**

### **When Object Detected (30-80cm indoors, 50-100cm outdoors):**
1. ✅ Motor vibrates with fast pulse pattern (ON/OFF every 150ms)
2. ✅ PWM value based on vibration intensity preference
3. ✅ Serial Monitor shows: `🔔 Motor: Fast pulse (distance XXcm, 30-80cm range, PWM: 200/255, ...)`

### **When Object Too Close or Too Far:**
1. ✅ Motor stops immediately
2. ✅ Serial Monitor shows reason: `🔔 Motor: Stopped (distance XXcm < 30cm)`

---

## 📝 **Next Steps:**

1. ✅ Upload updated code to ESP32
2. ✅ Uncomment `testMotor();` in `setup()` to test motor
3. ✅ Check Serial Monitor for motor status
4. ✅ Verify Firebase settings (`motorEnabled = true`)
5. ✅ Place object at 30-80cm (indoors) or 50-100cm (outdoors)
6. ✅ Check if motor vibrates

**If still not working:**
- Check wiring (especially ENA, IN1, IN2 connections)
- Try increasing PWM to 255 (maximum)
- Consider using direct drive (transistor/MOSFET) instead of L298N
- Check if motor works when connected directly to 3.3V/5V (for testing only)

---

## 🔧 **Alternative: Direct Drive Setup**

If L298N doesn't work well with coin motor, use this simpler setup:

### **Wiring:**
```
Coin Motor (+) → 3.3V (or 5V if available)
Coin Motor (-) → MOSFET Drain (IRLZ44N)
MOSFET Source → GND
MOSFET Gate → ESP32 GPIO 25 (via 220Ω resistor)
ESP32 GND → Common GND
```

### **Code Change:**
Replace motor control functions with:
```cpp
void motorStop() {
  digitalWrite(25, LOW);  // GPIO 25 = OFF
}

void motorVibrate() {
  digitalWrite(25, HIGH);  // GPIO 25 = ON
}
```

**Note:** This requires code modification. Current code uses L298N with PWM.

---

## ✅ **Summary:**

1. ✅ **PWM increased** from 60-120 to 150-255 for coin motor
2. ✅ **Coin motor mode enabled** by default
3. ✅ **Test function added** to verify motor works
4. ✅ **Enhanced logging** to show motor status

**Upload the code and test!** The motor should now work with coin vibration motors. 🎉

