# Available GPIO Pins for Battery Monitoring

## 📌 Currently Used GPIO Pins in ESP32_FINAL_CODE.ino:

| GPIO Pin | Function | Component |
|----------|----------|-----------|
| **GPIO13** | DF_TX | DFPlayer Mini (TX) |
| **GPIO14** | DF_RX | DFPlayer Mini (RX) |
| **GPIO16** | SIM800L_TX | SIM800L Module (TX) |
| **GPIO17** | SIM800L_RX | SIM800L Module (RX) |
| **GPIO18** | TRIG_PIN | Ultrasonic Sensor (Trigger) |
| **GPIO19** | ECHO_PIN | Ultrasonic Sensor (Echo) |
| **GPIO21** | SDA | OLED Display (I2C) |
| **GPIO22** | SCL | OLED Display (I2C) |
| **GPIO25** | ENA | L298N Motor Driver (Enable) |
| **GPIO26** | IN1 | L298N Motor Driver (Input 1) |
| **GPIO27** | IN2 | L298N Motor Driver (Input 2) |
| **GPIO32** | SIM800L_PWR | SIM800L Power (optional) |

## ✅ Available ADC1 Pins for Battery Monitoring:

These pins can read analog voltage (0-3.3V) and are perfect for battery monitoring:

| GPIO Pin | ADC Channel | Status | Recommendation |
|----------|-------------|--------|----------------|
| **GPIO39** | ADC1_CH3 | ✅ **AVAILABLE** | **RECOMMENDED** - Most commonly available |
| **GPIO34** | ADC1_CH6 | ✅ **AVAILABLE** | Good alternative |
| **GPIO35** | ADC1_CH7 | ✅ **AVAILABLE** | Good alternative |
| **GPIO36** | ADC1_CH0 | ❌ Not available | (Original choice, but not on your board) |

## 🔧 Current Code Setting:

The code is now set to use **GPIO39** (ADC1_CH3) as the default.

If you want to use a different pin, change this line in `ESP32_FINAL_CODE.ino`:
```cpp
#define BATTERY_ADC_PIN 39  // Change to 34, 35, or 36 if needed
```

## 📝 Wiring for Voltage Divider:

Regardless of which GPIO pin you choose, the wiring is the same:

```
TP4056 BAT+ → [R1: 10kΩ] → GPIO39 → [R2: 10kΩ] → GND
```

**Steps:**
1. Connect battery positive to TP4056 BAT+
2. Connect first 10kΩ resistor from TP4056 BAT+ to **GPIO39** (or your chosen pin)
3. Connect second 10kΩ resistor from **GPIO39** to GND
4. Connect TP4056 BAT- to GND (common ground)

## ⚠️ Important Notes:

- **GPIO39, GPIO34, GPIO35** are all ADC1 pins and work the same way
- All support 12-bit ADC (0-4095 readings)
- All can read 0-3.3V (with proper attenuation)
- Choose the one that's physically available on your ESP32 board
- The voltage divider circuit is the same for all pins

## 🔍 How to Check Which Pin is Available:

1. Look at your ESP32 board physically
2. Check the pin labels on the board
3. GPIO39 is usually labeled on most ESP32 development boards
4. If GPIO39 is not available, try GPIO34 or GPIO35

## ✅ Recommended: GPIO39

**Why GPIO39?**
- Most commonly available on ESP32 boards
- Same ADC capabilities as GPIO36
- Not used by any other component in your code
- Works identically for battery monitoring

