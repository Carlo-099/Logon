/*
 * ================================================================
 * SIM800L CALL & TEXT TEST CODE
 * ================================================================
 * 
 * Purpose: Test SIM800L module for making calls and sending SMS
 * 
 * Wiring (same as ESP32_FINAL_CODE.ino):
 * - SIM800L TX -> ESP32 GPIO 17 (RX)
 * - SIM800L RX -> ESP32 GPIO 16 (TX)
 * - SIM800L PWR -> ESP32 GPIO 32 (Optional - for power control)
 * - SIM800L VCC -> 4V power supply (NOT 5V!)
 * - SIM800L GND -> ESP32 GND
 * 
 * Requirements:
 * - SIM card with load (inserted in SIM800L)
 * - Antenna connected to SIM800L
 * - Power supply: 4V, 1-2A capacity
 * 
 * Instructions:
 * 1. Upload this code to ESP32
 * 2. Open Serial Monitor (115200 baud)
 * 3. Wait for SIM800L to initialize
 * 4. The code will automatically:
 *    - Make a test call to your phone number
 *    - Send a test SMS to your phone number
 * 
 * IMPORTANT: Change the phone numbers below before testing!
 */

#include <SoftwareSerial.h>

// ===================== SIM800L Pin Configuration =====================
// WIRING (VERIFIED):
// - SIM800L TX -> ESP32 GPIO 17 (RX)
// - SIM800L RX -> ESP32 GPIO 16 (TX)
// - SIM800L VCC -> 4V power supply (NOT 5V! Needs 1-2A)
// - SIM800L GND -> ESP32 GND (shared ground)
// - SIM800L PWR -> ESP32 GPIO 32 (optional, for power control)
#define SIM800L_RX 17  // ESP32 RX pin (GPIO 17) -> connect to SIM800L TX pin
#define SIM800L_TX 16  // ESP32 TX pin (GPIO 16) -> connect to SIM800L RX pin
#define SIM800L_PWR 32 // Optional: Power pin for SIM800L

// ===================== Phone Numbers =====================
// Primary test (as requested): local Globe number format
//   1) Try this first: "09459738579"
//   2) If still no call, change BOTH lines to: "639459738579"
String TEST_PHONE_NUMBER = "09459738579";  // Receiver number for call test
String SMS_RECEIVER    = "09459738579";    // Receiver number for SMS test

// ===================== SIM800L Serial Communication =====================
SoftwareSerial SIM800L_Serial(SIM800L_RX, SIM800L_TX);

// ===================== Helper Functions =====================

// Send AT command and wait for response
String sendATCommand(String command, unsigned long timeout = 2000) {
  SIM800L_Serial.flush();
  SIM800L_Serial.println(command);
  Serial.print("📤 Sent: ");
  Serial.println(command);
  
  unsigned long start = millis();
  String response = "";
  
  while (millis() - start < timeout) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      response += c;
      if (response.indexOf("OK") >= 0 || response.indexOf("ERROR") >= 0) {
        break;
      }
    }
  }
  
  Serial.print("📥 Response: ");
  Serial.println(response);
  return response;
}

// Wait for module to be ready
bool waitForModuleReady(unsigned long timeout = 10000) {
  Serial.println("⏳ Waiting for SIM800L to be ready...");
  unsigned long start = millis();
  String bootMessage = "";
  
  while (millis() - start < timeout) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      bootMessage += c;
      
      if (bootMessage.indexOf("RDY") >= 0 || 
          bootMessage.indexOf("Call Ready") >= 0 ||
          bootMessage.indexOf("SMS Ready") >= 0) {
        Serial.println("✅ Module is ready!");
        return true;
      }
    }
  }
  
  Serial.println("⚠️ Timeout waiting for module ready");
  return false;
}

// Initialize SIM800L module
bool initSIM800L() {
  Serial.println("========================================");
  Serial.println("📱 INITIALIZING SIM800L MODULE");
  Serial.println("========================================");
  
  // Optional: Hardware reset via PWR pin (if connected)
  #ifdef SIM800L_PWR
  Serial.println("🔌 Attempting hardware reset via PWR pin...");
  pinMode(SIM800L_PWR, OUTPUT);
  digitalWrite(SIM800L_PWR, LOW);
  delay(1000);
  digitalWrite(SIM800L_PWR, HIGH);
  delay(5000);
  #endif
  
  // Initialize serial communication at 9600 baud
  Serial.println("🔌 Initializing SIM800L serial at 9600 baud...");
  SIM800L_Serial.end();
  delay(200);
  SIM800L_Serial.begin(9600);
  delay(3000);
  
  // Clear buffer
  delay(500);
  while (SIM800L_Serial.available()) {
    SIM800L_Serial.read();
  }
  
  // Wait for module ready
  waitForModuleReady(10000);
  
  // Test AT command
  Serial.println("🔍 Testing AT command...");
  String response = sendATCommand("AT", 2000);
  if (response.indexOf("OK") < 0) {
    Serial.println("❌ No response from SIM800L!");
    Serial.println("   Check wiring and power supply");
    return false;
  }
  Serial.println("✅ AT command OK");
  
  // Check SIM card
  Serial.println("🔍 Checking SIM card...");
  response = sendATCommand("AT+CPIN?", 2000);
  if (response.indexOf("READY") < 0) {
    Serial.println("❌ SIM card not ready!");
    Serial.println("   Make sure SIM card is inserted correctly");
    return false;
  }
  Serial.println("✅ SIM card ready");
  
  // Check network registration
  Serial.println("🔍 Checking network registration...");
  int attempts = 0;
  bool registered = false;
  
  while (attempts < 30 && !registered) {
    response = sendATCommand("AT+CREG?", 2000);
    if (response.indexOf("+CREG: 0,1") >= 0 || response.indexOf("+CREG: 0,5") >= 0) {
      registered = true;
      Serial.println("✅ Network registered!");
    } else {
      Serial.print("⏳ Waiting for network registration... (");
      Serial.print(attempts + 1);
      Serial.println("/30)");
      delay(2000);
      attempts++;
    }
  }
  
  if (!registered) {
    Serial.println("❌ Network registration failed!");
    Serial.println("   Check SIM card, antenna, and signal strength");
    return false;
  }
  
  // Get signal strength
  Serial.println("🔍 Checking signal strength...");
  response = sendATCommand("AT+CSQ", 2000);
  
  // Detailed diagnostics
  Serial.println();
  Serial.println("========================================");
  Serial.println("📊 DETAILED DIAGNOSTICS");
  Serial.println("========================================");
  
  // Check signal strength (CSQ)
  Serial.println("📶 Signal Strength (CSQ):");
  response = sendATCommand("AT+CSQ", 2000);
  if (response.indexOf("+CSQ:") >= 0) {
    int csqStart = response.indexOf("+CSQ:") + 5;
    int csqEnd = response.indexOf(",", csqStart);
    if (csqEnd > csqStart) {
      String csqStr = response.substring(csqStart, csqEnd);
      csqStr.trim();
      int csq = csqStr.toInt();
      Serial.print("   CSQ Value: ");
      Serial.println(csq);
      if (csq == 99) {
        Serial.println("   ⚠️ No signal detected!");
      } else if (csq < 10) {
        Serial.println("   ⚠️ Very weak signal!");
      } else if (csq < 20) {
        Serial.println("   ⚠️ Weak signal");
      } else {
        Serial.println("   ✅ Good signal");
      }
    }
  }
  
  // Check network operator
  Serial.println();
  Serial.println("📡 Network Operator:");
  response = sendATCommand("AT+COPS?", 3000);
  Serial.print("   ");
  Serial.println(response);
  
  // Check SIM card info
  Serial.println();
  Serial.println("📱 SIM Card Info:");
  response = sendATCommand("AT+CCID", 2000);
  Serial.print("   ");
  Serial.println(response);
  
  // Check phone number (if available)
  Serial.println();
  Serial.println("📞 Phone Number:");
  response = sendATCommand("AT+CNUM", 2000);
  Serial.print("   ");
  Serial.println(response);
  
  // Check battery status (if supported)
  Serial.println();
  Serial.println("🔋 Battery Status:");
  response = sendATCommand("AT+CBC", 2000);
  Serial.print("   ");
  Serial.println(response);
  
  Serial.println("========================================");
  Serial.println();
  
  Serial.println("✅ SIM800L initialized successfully!");
  return true;
}

// Make a phone call
bool makeCall(String phoneNumber) {
  Serial.println("========================================");
  Serial.println("📞 MAKING PHONE CALL");
  Serial.println("========================================");
  
  // First, verify network registration
  Serial.println("🔍 Verifying network registration...");
  String regResponse = sendATCommand("AT+CREG?", 2000);
  Serial.print("   Network status: ");
  Serial.println(regResponse);
  
  if (regResponse.indexOf("+CREG: 0,1") < 0 && regResponse.indexOf("+CREG: 0,5") < 0) {
    Serial.println("❌ Network not registered! Cannot make call.");
    Serial.println("   Please wait for network registration first.");
    return false;
  }
  
  // Check signal strength
  Serial.println("🔍 Checking signal strength...");
  String signalResponse = sendATCommand("AT+CSQ", 2000);
  Serial.print("   Signal: ");
  Serial.println(signalResponse);
  
  Serial.print("📱 Calling: ");
  Serial.println(phoneNumber);
  
  // Clear serial buffer before dialing
  delay(500);
  while (SIM800L_Serial.available()) {
    SIM800L_Serial.read();
  }
  
  // Try dialing with semicolon (voice call)
  String command = "ATD" + phoneNumber + ";";
  SIM800L_Serial.println(command);
  Serial.print("📤 Sent: ");
  Serial.println(command);
  
  // Wait for response (longer timeout for call initiation)
  String response = "";
  unsigned long start = millis();
  while (millis() - start < 10000) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      response += c;
      Serial.print(c); // Print character as it arrives
      
      // Check for various responses
      if (response.indexOf("OK") >= 0 || 
          response.indexOf("CONNECT") >= 0 ||
          response.indexOf("NO CARRIER") >= 0 ||
          response.indexOf("BUSY") >= 0 ||
          response.indexOf("NO ANSWER") >= 0 ||
          response.indexOf("ERROR") >= 0) {
        break;
      }
    }
  }
  Serial.println();
  
  if (response.indexOf("OK") >= 0 || response.indexOf("CONNECT") >= 0) {
    Serial.println("✅ Call initiated!");
    Serial.println("📞 Call in progress...");
    Serial.println("   (Call will last 10 seconds, then hang up)");
    
    // Wait for 10 seconds
    delay(10000);
    
    // Hang up
    Serial.println("📞 Hanging up...");
    SIM800L_Serial.println("ATH");
    delay(2000);
    
    // Read hang up response
    String hangResponse = "";
    start = millis();
    while (millis() - start < 3000) {
      if (SIM800L_Serial.available()) {
        char c = SIM800L_Serial.read();
        hangResponse += c;
        if (hangResponse.indexOf("OK") >= 0) {
          break;
        }
      }
    }
    
    if (hangResponse.indexOf("OK") >= 0) {
      Serial.println("✅ Call ended");
    } else {
      Serial.println("⚠️ Hang up command sent (may take a moment)");
    }
    return true;
  } else if (response.indexOf("NO CARRIER") >= 0) {
    Serial.println("❌ No carrier - call failed");
    Serial.println("   Check phone number and network signal");
    return false;
  } else if (response.indexOf("BUSY") >= 0) {
    Serial.println("⚠️ Line is busy");
    return false;
  } else if (response.indexOf("NO ANSWER") >= 0) {
    Serial.println("⚠️ No answer");
    return false;
  } else {
    Serial.println("❌ Failed to make call");
    Serial.print("   Response: ");
    Serial.println(response);
    Serial.println("   Possible issues:");
    Serial.println("   1. Wrong phone number format");
    Serial.println("   2. Network not fully registered");
    Serial.println("   3. No signal or weak signal");
    Serial.println("   4. SIM card has no call credits");
    return false;
  }
}

// Send SMS
bool sendSMS(String phoneNumber, String message) {
  Serial.println("========================================");
  Serial.println("💬 SENDING SMS");
  Serial.println("========================================");
  Serial.print("📱 To: ");
  Serial.println(phoneNumber);
  Serial.print("💬 Message: ");
  Serial.println(message);
  
  // Clear serial buffer first
  delay(500);
  while (SIM800L_Serial.available()) {
    SIM800L_Serial.read();
  }
  
  // Set SMS mode to text
  Serial.println("🔍 Setting SMS mode to text...");
  SIM800L_Serial.println("AT+CMGF=1");
  delay(1000);
  
  String response = "";
  unsigned long start = millis();
  while (millis() - start < 3000) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      response += c;
      if (response.indexOf("OK") >= 0 || response.indexOf("ERROR") >= 0) {
        break;
      }
    }
  }
  
  if (response.indexOf("OK") < 0) {
    Serial.println("❌ Failed to set SMS mode");
    Serial.print("   Response: ");
    Serial.println(response);
    return false;
  }
  Serial.println("✅ SMS mode set to text");
  
  // Set recipient number
  Serial.println("🔍 Setting recipient number...");
  String command = "AT+CMGS=\"" + phoneNumber + "\"";
  SIM800L_Serial.println(command);
  Serial.print("📤 Sent: ");
  Serial.println(command);
  
  // Wait for ">" prompt (this means ready to receive message)
  response = "";
  start = millis();
  bool gotPrompt = false;
  while (millis() - start < 5000) {
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      response += c;
      Serial.print(c); // Print as it arrives
      if (c == '>') {
        gotPrompt = true;
        break;
      }
    }
  }
  Serial.println();
  
  if (!gotPrompt) {
    Serial.println("❌ Did not receive '>' prompt");
    Serial.print("   Response: ");
    Serial.println(response);
    return false;
  }
  
  Serial.println("✅ Ready to send message...");
  
  // Send message
  Serial.println("📤 Sending message...");
  SIM800L_Serial.print(message);
  delay(100); // Small delay before sending Ctrl+Z
  SIM800L_Serial.write(26); // Ctrl+Z (ASCII 26) to end message
  Serial.println("✅ Message sent, waiting for confirmation...");
  
  // Wait for response (longer timeout for SMS)
  String smsResponse = "";
  start = millis();
  while (millis() - start < 15000) { // Wait up to 15 seconds
    if (SIM800L_Serial.available()) {
      char c = SIM800L_Serial.read();
      smsResponse += c;
      Serial.print(c); // Print as it arrives
      
      if (smsResponse.indexOf("OK") >= 0) {
        Serial.println();
        Serial.println("✅ SMS sent successfully!");
        return true;
      }
      if (smsResponse.indexOf("ERROR") >= 0 || 
          smsResponse.indexOf("+CMS ERROR") >= 0) {
        Serial.println();
        Serial.println("❌ SMS failed to send");
        Serial.print("   Error response: ");
        Serial.println(smsResponse);
        return false;
      }
    }
  }
  
  Serial.println();
  Serial.println("⚠️ Timeout waiting for SMS confirmation");
  Serial.print("   Received: ");
  Serial.println(smsResponse);
  Serial.println("   (SMS may still be sending - check your phone)");
  return false;
}

// ===================== Setup =====================
void setup() {
  // Initialize Serial Monitor
  Serial.begin(115200);
  delay(2000);
  
  Serial.println();
  Serial.println("========================================");
  Serial.println("=== SIM800L CALL & TEXT TEST ===");
  Serial.println("========================================");
  Serial.println();
  Serial.println("⚠️ IMPORTANT POWER SUPPLY CHECK:");
  Serial.println("   SIM800L requires:");
  Serial.println("   - Voltage: 4V (NOT 5V!)");
  Serial.println("   - Current: 1-2A capacity");
  Serial.println("   - Stable power supply");
  Serial.println();
  Serial.println("⚠️ WIRING CHECK:");
  Serial.println("   - SIM800L TX -> ESP32 GPIO 17");
  Serial.println("   - SIM800L RX -> ESP32 GPIO 16");
  Serial.println("   - SIM800L GND -> ESP32 GND (shared)");
  Serial.println("   - Antenna MUST be connected!");
  Serial.println();
  
  // Initialize SIM800L
  if (!initSIM800L()) {
    Serial.println("❌ SIM800L initialization failed!");
    Serial.println("   Please check:");
    Serial.println("   1. Wiring connections");
    Serial.println("   2. Power supply (4V, 1-2A)");
    Serial.println("   3. SIM card inserted");
    Serial.println("   4. Antenna connected");
    Serial.println("   5. Network signal available");
    Serial.println();
    Serial.println("   Code will retry in 30 seconds...");
    delay(30000);
    ESP.restart();
    return;
  }
  
  Serial.println();
  Serial.println("========================================");
  Serial.println("✅ SIM800L READY FOR TESTING");
  Serial.println("========================================");
  Serial.println();
  
  // Final network status check
  Serial.println("🔍 Final network status check...");
  String finalCheck = sendATCommand("AT+CREG?", 2000);
  String signalCheck = sendATCommand("AT+CSQ", 2000);
  Serial.print("   Network: ");
  Serial.println(finalCheck);
  Serial.print("   Signal: ");
  Serial.println(signalCheck);
  Serial.println();
  
  Serial.println("⚠️ IMPORTANT: Make sure you changed the phone numbers!");
  Serial.print("   Test phone number: ");
  Serial.println(TEST_PHONE_NUMBER);
  Serial.println();
  Serial.println("Starting tests in 5 seconds...");
  delay(5000);
  
  // Test 1: Make a call
  Serial.println();
  Serial.println("========================================");
  Serial.println("TEST 1: PHONE CALL");
  Serial.println("========================================");
  makeCall(TEST_PHONE_NUMBER);
  delay(5000);
  
  // Test 2: Send SMS
  Serial.println();
  Serial.println("========================================");
  Serial.println("TEST 2: SMS");
  Serial.println("========================================");
  String testMessage = "Hello from ESP32! This is a test SMS from SIM800L module. Time: " + String(millis() / 1000) + " seconds";
  sendSMS(SMS_RECEIVER, testMessage);
  delay(5000);
  
  Serial.println();
  Serial.println("========================================");
  Serial.println("✅ ALL TESTS COMPLETED");
  Serial.println("========================================");
  Serial.println();
  Serial.println("Check your phone:");
  Serial.println("  1. Did you receive a call?");
  Serial.println("  2. Did you receive an SMS?");
  Serial.println();
  Serial.println("If both worked, SIM800L call/text is working! ✅");
  Serial.println("If not, check Serial Monitor for error messages.");
  Serial.println();
}

// ===================== Loop =====================
void loop() {
  // This code runs once, then stops
  // If you want to repeat tests, uncomment the code below:
  
  /*
  Serial.println();
  Serial.println("========================================");
  Serial.println("REPEATING TESTS (every 60 seconds)");
  Serial.println("========================================");
  
  // Make call
  makeCall(TEST_PHONE_NUMBER);
  delay(5000);
  
  // Send SMS
  String testMessage = "Test SMS from ESP32 - " + String(millis() / 1000) + " seconds";
  sendSMS(SMS_RECEIVER, testMessage);
  
  delay(60000); // Wait 60 seconds before next test
  */
  
  // For now, just keep the code running
  delay(1000);
}

