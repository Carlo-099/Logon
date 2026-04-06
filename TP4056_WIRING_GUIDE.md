# TP4056 Battery Monitoring Setup Guide

## Components Needed:
1. TP4056 Charging Module
2. ESP32 Development Board
3. OLED Display (SSD1306)
4. Li-ion/LiPo Battery (3.7V, compatible with TP4056)
5. Two 10kΩ Resistors (for voltage divider)
6. Jumper wires

## Wiring Diagram:

```
┌─────────────────────────────────────────────────────────┐
│                    TP4056 MODULE                         │
│                                                          │
│  BAT+ ──────┐                                           │
│             │                                           │
│  BAT- ──────┼─── GND (Common Ground)                    │
│             │                                           │
│  OUT+ ──────┼─── ESP32 VIN (5V) or 3.3V                │
│             │                                           │
│  OUT- ──────┼─── ESP32 GND                              │
│             │                                           │
│  IN+  ──────┼─── USB Power + (from powerbank)           │
│             │                                           │
│  IN-  ──────┼─── USB Power - (from powerbank)           │
└─────────────┼───────────────────────────────────────────┘
              │
              │ Voltage Divider Circuit:
              │
              │ BAT+ ──[R1: 10kΩ]── GPIO35 ──[R2: 10kΩ]── GND
              │ (or GPIO34, GPIO36, GPIO39 if available)
              │
              │ This divides voltage by 2 to protect ESP32 ADC
              │ (ESP32 ADC max = 3.3V, battery = 3.0-4.2V)
              │
┌─────────────┼───────────────────────────────────────────┐
│             │                                           │
│         ESP32                                           │
│                                                          │
│  GPIO35 ────┘ (ADC Input for battery voltage)          │
│  (or GPIO34/36/39 if available)                        │
│  GPIO21 ──── SDA (OLED)                                 │
│  GPIO22 ──── SCL (OLED)                                 │
│  VIN ─────── Power from TP4056 OUT+                    │
│  GND ─────── Common Ground                              │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Step-by-Step Wiring:

### 1. TP4056 to Battery:
- Connect battery positive (+) to TP4056 **BAT+**
- Connect battery negative (-) to TP4056 **BAT-**

### 2. TP4056 to ESP32 Power:
- Connect TP4056 **OUT+** to ESP32 **VIN** (or 3.3V if using regulator)
- Connect TP4056 **OUT-** to ESP32 **GND**

### 3. Voltage Divider for Battery Monitoring:
- Connect battery positive (or TP4056 BAT+) to first 10kΩ resistor (R1)
- Connect other end of R1 to **ESP32 GPIO35** (or GPIO34/36/39 if available)
- Connect **ESP32 GPIO35** to second 10kΩ resistor (R2)
- Connect other end of R2 to **GND** (common ground)

**Available ADC1 Pins for Battery Monitoring:**
- **GPIO35** (ADC1_CH7) - **CURRENTLY USED** - User's wiring
- **GPIO34** (ADC1_CH6) - Alternative option
- **GPIO36** (ADC1_CH0) - Alternative option
- **GPIO39** (ADC1_CH3) - Alternative option

### 4. TP4056 Charging (Optional):
- Connect USB powerbank output to TP4056 **IN+** and **IN-**
- TP4056 will automatically charge the battery when USB power is connected

### 5. OLED Display:
- Connect OLED **SDA** to ESP32 **GPIO21**
- Connect OLED **SCL** to ESP32 **GPIO22**
- Connect OLED **VCC** to ESP32 **3.3V**
- Connect OLED **GND** to ESP32 **GND**

## How It Works:

1. **Battery Powers ESP32**: TP4056 module regulates battery voltage and provides stable power to ESP32 via OUT+ and OUT-

2. **Voltage Monitoring**: The voltage divider circuit safely reduces battery voltage (3.0-4.2V) to ESP32-safe range (1.5-2.1V) for ADC reading

3. **Percentage Calculation**: ESP32 reads voltage, multiplies by 2 (voltage divider correction), and calculates percentage:
   - 4.2V = 100% (fully charged)
   - 3.0V = 0% (empty/cutoff)
   - Linear interpolation for values in between

4. **OLED Display**: Shows battery percentage in real-time on the OLED screen

## Important Notes:

⚠️ **Safety Warnings:**
- Always use a voltage divider! Never connect battery directly to ESP32 GPIO pins
- Ensure proper polarity when connecting battery to TP4056
- Use appropriate battery capacity for your ESP32 power requirements
- TP4056 has built-in protection, but still be careful with battery connections

✅ **Tips:**
- Use 18650 Li-ion battery (3.7V) for best compatibility with TP4056
- The voltage divider resistors (10kΩ each) are standard values and easy to find
- Battery percentage updates every 5 seconds
- You can charge the battery via USB while ESP32 is running (TP4056 handles this automatically)

## Testing:

1. Upload the ESP32 code
2. Open Serial Monitor (115200 baud)
3. Check for "🔋 Battery monitoring initialized" message
4. Look for battery voltage and percentage readings every 5 seconds
5. Check OLED display for "Battery: XX%" text

## Troubleshooting:

- **Battery shows 0% or wrong reading**: 
  - Check voltage divider wiring
  - Verify GPIO pin is correct (GPIO39, GPIO34, GPIO35, or GPIO36)
  - Check if pin is available on your ESP32 board model
- **ESP32 not powering on**: Check TP4056 OUT+ to ESP32 VIN connection
- **Battery not charging**: Check USB power connection to TP4056 IN+ and IN-
- **OLED not showing battery**: Check if OLED is initialized (look for "✅ OLED display initialized" in Serial Monitor)

