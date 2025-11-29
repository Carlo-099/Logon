# SIM800L GSM Module Integration Guide

## Overview
This integration adds automatic failover between WiFi and GPRS (SIM800L) connections. When WiFi is available, it uses WiFi. When WiFi is lost, it automatically switches to GPRS data connection via SIM800L.

## Hardware Connections

### SIM800L to ESP32:
- **SIM800L RXD** → **ESP32 GPIO 17**
- **SIM800L TXD** → **ESP32 GPIO 16**
- **SIM800L GND** → **GND** (common ground)
- **SIM800L VCC** → **4V power supply** (see Power Requirements below)

### ⚠️ Important: Power Requirements

SIM800L requires **3.7V to 4.2V** (typically 4V) and can draw up to **2A** during transmission.

**DO NOT connect directly to ESP32's 3.3V or 5V pins!**

**Recommended Power Solutions:**
1. **External 4V power supply** (best option)
2. **Voltage regulator** (e.g., AMS1117-4.0V) from 5V source
3. **Dedicated power module** for SIM800L

**Why?** 
- ESP32's 3.3V pin cannot provide enough current (max ~600mA)
- ESP32's 5V pin is too high (SIM800L needs 4V)
- SIM800L can cause voltage drops that reboot ESP32 if not properly powered

## Library Installation

Install these libraries in Arduino IDE:

1. **TinyGSM** by Volodymyr Shymanskyy
   - Go to: Tools → Manage Libraries
   - Search: "TinyGSM"
   - Install: "TinyGSM" by Volodymyr Shymanskyy

2. **SoftwareSerial** (usually built-in, but verify)

## SIM Card Setup

1. Insert TNT SIM card into SIM800L module
2. Ensure SIM card has:
   - Active data plan (load data)
   - Network registration (check signal LED on SIM800L)

## APN Configuration

The code is configured for **TNT Philippines** with APN: `internet`

If connection fails, the code will try alternative APN: `smartbro`

**To change APN for other carriers:**
- Edit `initSIM800L()` function in `ESP32_FINAL_CODE.ino`
- Common APN settings:
  - **TNT/Smart**: `internet` or `smartbro`
  - **Globe**: `internet.globe.com.ph`
  - **Sun**: `minternet`

## How It Works

### Connection Priority:
1. **WiFi (Primary)** - Used when available
2. **GPRS (Backup)** - Automatically activated when WiFi is lost

### Automatic Failover:
- System checks connection status every 10 seconds
- If WiFi disconnects → automatically switches to GPRS
- If WiFi reconnects → automatically switches back to WiFi
- GPRS reconnection attempts every 30 seconds if connection is lost

### Functions:
- **GPS Updates**: Work with both WiFi and GPRS
- **Hardware Control**: Polls Firebase via WiFi or GPRS
- **OLED Display**: Shows connection type (WiFi/GPRS)

## Testing

### Step 1: Upload Code
1. Upload `ESP32_FINAL_CODE.ino` to ESP32
2. Open Serial Monitor (115200 baud)

### Step 2: Test WiFi Connection
1. Ensure WiFi is connected
2. Check Serial Monitor for: `✅ WiFi Connected!`
3. Check OLED: Should show `WiFi:OK`

### Step 3: Test GPRS Failover
1. Disconnect WiFi (turn off router or move out of range)
2. Wait 10-30 seconds
3. Check Serial Monitor for:
   - `⚠️ WiFi disconnected, attempting GPRS connection...`
   - `✅ Switched to GPRS connection`
4. Check OLED: Should show `GPRS:OK`

### Step 4: Test Firebase Communication
1. With GPRS active, check if GPS updates are still working
2. Check Flutter app Map page - should still receive GPS data
3. Check Serial Monitor for: `✅✅✅ GPS SUCCESSFULLY UPDATED IN FIREBASE! ✅✅✅`

## Troubleshooting

### SIM800L Not Responding
- **Check power supply**: Must be 4V, capable of 2A
- **Check connections**: RXD/TXD swapped? Check wiring
- **Check SIM card**: Is it inserted correctly? Has signal?
- **Check Serial Monitor**: Look for modem info messages

### GPRS Connection Fails
- **Check APN**: Try different APN settings (see APN Configuration)
- **Check SIM card**: Does it have active data plan?
- **Check signal**: Move to area with better signal
- **Check Serial Monitor**: Look for specific error messages

### HTTPS Connection Fails via GPRS
- **Note**: Some SIM800L modules have limited HTTPS/TLS support
- If HTTPS fails, the code will retry
- Check Serial Monitor for: `❌ GPRS HTTPS connect failed`
- **Workaround**: Ensure SIM card has good signal and data plan is active

### ESP32 Reboots When SIM800L Activates
- **Power issue**: SIM800L is drawing too much current
- **Solution**: Use external 4V power supply for SIM800L
- Add decoupling capacitors (1000µF) near SIM800L power input

## Code Structure

### Key Functions:
- `initSIM800L()` - Initializes SIM800L and connects to GPRS
- `checkGPRSConnection()` - Verifies GPRS connection status
- `checkConnectionStatus()` - Manages WiFi/GPRS failover
- `updateGPSInFirebase()` - Works with both WiFi and GPRS
- `pollHardwareControl()` - Works with both WiFi and GPRS

### Connection States:
- `CONN_NONE` - No connection
- `CONN_WIFI` - WiFi connected
- `CONN_GPRS` - GPRS connected

## Notes

1. **Power Consumption**: GPRS uses more power than WiFi. Consider using a power bank for portable operation.

2. **Data Usage**: GPRS data usage depends on:
   - GPS update frequency (every 5 seconds)
   - Hardware control polling (every 2 seconds)
   - Estimated: ~1-2 MB per hour

3. **Signal Quality**: Check Serial Monitor for signal quality in dBm. Better signal = more reliable connection.

4. **HTTPS Support**: SIM800L has limited HTTPS/TLS support. If you encounter issues, ensure:
   - Good signal strength
   - Active data plan
   - Correct APN settings

## Next Steps

After successful integration:
1. Test failover by disconnecting WiFi
2. Monitor data usage
3. Adjust update intervals if needed to save data
4. Consider adding SMS alerts for connection status (optional)



