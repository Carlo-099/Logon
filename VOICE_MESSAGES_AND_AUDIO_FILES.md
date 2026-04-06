# Voice Messages and Audio Files Guide

## 📁 Audio File Structure

The ESP32 uses DFPlayer Mini to play audio files from SD card. Files are organized in folders:
- **Folder 1**: Contains all audio files (001.mp3, 002.mp3, 003.mp3, 004.mp3, 005.mp3, 006.mp3)

## 🎵 Audio Files and Their Usage

### Startup Audio (System Boot)
**Files:**
- **001.mp3** (Tagalog): "Welcome to Gabay Tech" / "Maligayang pagdating sa Gabay Tech"
- **004.mp3** (English): "Welcome to Gabay Tech"

**When Played:**
- Once when ESP32 boots up and connects to Firebase
- Only plays if language is NOT "none"
- Plays automatically after system initialization

---

### Detection Alert Audio Files

#### LOW Repetition Files (002/005)
**Files:**
- **002.mp3** (Tagalog): Obstacle detection warning (LOW repetition)
- **005.mp3** (English): Obstacle detection warning (LOW repetition)

**When Played:**
- When object is detected within sensing range
- Used for users who get tired easily (E7 = "Oo")
- Also used for high-risk head-level warnings (H1 = "Oo")

**Example Messages (Likely Content):**
- Tagalog (002.mp3): "May bagay sa harap" / "May hadlang" / "Mag-ingat, may obstacle"
- English (005.mp3): "Object detected ahead" / "Obstacle ahead" / "Warning, obstacle detected"

---

#### Standard Repetition Files (003/006)
**Files:**
- **003.mp3** (Tagalog): Obstacle detection warning (Standard repetition)
- **006.mp3** (English): Obstacle detection warning (Standard repetition)

**When Played:**
- When object is detected within sensing range
- Used for users who don't get tired easily (E7 = "Hindi")
- Standard alert timing

**Example Messages (Likely Content):**
- Tagalog (003.mp3): "May bagay sa harap" / "May hadlang" / "Mag-ingat, may obstacle"
- English (006.mp3): "Object detected ahead" / "Obstacle ahead" / "Warning, obstacle detected"

**Note:** The difference between 002/005 and 003/006 is the **repetition rate/timing**, not the message content. Both likely say similar things but are used based on user's fatigue level.

---

## 📊 Audio File Selection Logic

### Language Mapping:
- **Tagalog/Filipino**: Uses files 001, 002, 003
- **English**: Uses files 004, 005, 006
- **None**: No audio files played

### Base File Selection:
- **Base File 1**: Startup (001/004)
- **Base File 2**: LOW repetition alerts (002/005)
- **Base File 3**: Standard repetition alerts (003/006)

---

## 🎯 When Each Audio File is Played (Based on Profiling)

### ELDERLY CATEGORY

#### Scenario 1: E7 = "Oo" (Gets tired easily)
**Audio File:** 002.mp3 (Tagalog) or 005.mp3 (English)
- **Trigger:** Object detected in sensing range
- **Repetition:** LOW (less frequent)
- **Delay:** 3000ms (longer interval between alerts)
- **Message Type:** Obstacle warning with longer pauses

#### Scenario 2: E7 = "Hindi" (Doesn't get tired easily)
**Audio File:** 003.mp3 (Tagalog) or 006.mp3 (English)
- **Trigger:** Object detected in sensing range
- **Repetition:** Standard (normal frequency)
- **Delay:** 1000ms (standard interval)
- **Message Type:** Obstacle warning with standard timing

**Additional Conditions:**
- Audio only plays if **E4 = "Oo"** (Voice preference = Yes)
- If **E4 = "Hindi"**, no audio files are played (voice is OFF)
- Language is determined by user's selection after E4

---

### HIGH-RISK CATEGORY

#### Scenario 1: H1 = "Oo" (Head-level obstacles)
**Audio File:** 002.mp3 (Tagalog) or 005.mp3 (English)
- **Trigger:** Object detected at head/chest level
- **Sensor Angle:** UPWARD
- **Detection Level:** Head/chest
- **Message Type:** Head-level obstacle warning
- **Example:** "May bagay sa taas" / "Obstacle above" / "Watch your head"

**Additional Conditions:**
- Audio only plays if **H2 = "Voice lamang"** or **"Pareho"**
- If **H2 = "Vibration lamang"**, no audio (vibration only)
- If **H3 = "Oo"** (Continuous assistance), audio **loops continuously** while object is detected
- If **H3 = "Hindi"**, audio plays once per detection (event-based)

#### Scenario 2: H1 = "Hindi" (No head-level obstacles)
**Audio File:** 002.mp3 (Tagalog) or 005.mp3 (English) - for terrain warnings
- **Trigger:** Depth/terrain detected (if H4 = "Oo")
- **Sensor Angle:** DOWNWARD (if H4 = "Oo")
- **Detection Level:** Depth detection
- **Message Type:** Terrain/depth warning
- **Example:** "May hukay sa harap" / "Uneven terrain ahead" / "Watch your step"

**Additional Conditions:**
- Audio only plays if **H5 = "Oo"** (Terrain voice warning = Yes)
- If **H5 = "Hindi"**, no audio for terrain (voice is OFF)
- Language is determined by user's selection after H2 (if voice was selected)

---

## 🔄 Audio Playback Modes

### 1. Single Play (Default)
- Audio plays once when object is detected
- Respects cooldown period before playing again
- Used for: Standard detection alerts

### 2. Continuous Loop
- Audio loops continuously while object is in range
- No cooldown (plays continuously)
- Used for: High-risk continuous assistance (H3 = "Oo")

### 3. Cooldown-Based
- Audio plays, then waits for cooldown period
- Cooldown: 1s (frequent collisions), 2s (occasional), 3s (rare)
- Used for: Elderly category with obstacle collision settings

---

## 📋 Complete Audio File Usage Matrix

| Profiling Answer | Audio File (Tagalog) | Audio File (English) | When Played | Repetition |
|-----------------|---------------------|---------------------|-------------|------------|
| **Startup** | 001.mp3 | 004.mp3 | System boot | Once |
| **E7 = Oo** (Elderly) | 002.mp3 | 005.mp3 | Object detected | LOW (3000ms delay) |
| **E7 = Hindi** (Elderly) | 003.mp3 | 006.mp3 | Object detected | Standard (1000ms delay) |
| **H1 = Oo** (High-risk) | 002.mp3 | 005.mp3 | Head-level detected | Continuous if H3=Oo |
| **H4 = Oo, H5 = Oo** (High-risk) | 002.mp3 | 005.mp3 | Terrain detected | Event-based |

---

## 🎤 Expected Voice Message Content

### Based on Detection Type:

#### 1. Forward Obstacle (Elderly, Standard)
- **Tagalog (002/003):** "May bagay sa harap, mag-ingat"
- **English (005/006):** "Object ahead, be careful"

#### 2. Head-Level Obstacle (High-risk, H1 = Oo)
- **Tagalog (002):** "May bagay sa taas, bantayan ang ulo"
- **English (005):** "Obstacle above, watch your head"

#### 3. Terrain/Depth (High-risk, H4 = Oo)
- **Tagalog (002):** "May hukay o hindi pantay na daan, mag-ingat"
- **English (005):** "Uneven terrain or hole ahead, be careful"

#### 4. Startup Message
- **Tagalog (001):** "Maligayang pagdating sa Gabay Tech. Ang sistema ay handa na."
- **English (004):** "Welcome to Gabay Tech. System is ready."

---

## ⚙️ Audio Control Logic

### Audio is DISABLED when:
1. **E4 = "Hindi"** (Elderly voice preference = No)
2. **H2 = "Vibration lamang"** (High-risk prefers vibration only)
3. **H5 = "Hindi"** (High-risk terrain voice = No)
4. **Language = "none"** (User selected no language)
5. **audioEnabled = false** in Firebase settings

### Audio is ENABLED when:
1. **E4 = "Oo"** AND language is selected (Elderly)
2. **H2 = "Voice lamang"** or **"Pareho"** AND language is selected (High-risk)
3. **H5 = "Oo"** for terrain warnings (High-risk, if H1 = Hindi)

---

## 📝 Notes:

1. **File Numbers:**
   - Tagalog: 001, 002, 003
   - English: 004, 005, 006 (baseFile + 3)

2. **Repetition vs Content:**
   - 002/005 and 003/006 may have the same message content
   - Difference is in **timing/delay** between plays
   - 002/005 = Longer delays (for tired users)
   - 003/006 = Standard delays (for active users)

3. **Continuous Mode:**
   - When H3 = "Oo" (Continuous assistance), audio loops
   - Plays continuously while object is in range
   - No cooldown period

4. **Voice Delay:**
   - Standard: 1000ms (1 second) delay before playing
   - Longer: 3000ms (3 seconds) delay (for E7 = "Oo")

5. **Cooldown:**
   - Prevents audio spam
   - 1s, 2s, or 3s based on E2 answer (Obstacle collision frequency)

---

## 🔍 How to Verify Audio Files

To know the exact content of each audio file, you need to:
1. Check the SD card in DFPlayer Mini
2. Listen to files: 001.mp3, 002.mp3, 003.mp3, 004.mp3, 005.mp3, 006.mp3
3. Or record/replace them with your desired messages

**Recommended Audio File Content:**

### 001.mp3 / 004.mp3 (Startup):
- Tagalog: "Maligayang pagdating sa Gabay Tech. Ang sistema ay handa na."
- English: "Welcome to Gabay Tech. System is ready."

### 002.mp3 / 005.mp3 (LOW Repetition / Head-Level):
- Tagalog: "May bagay sa harap, mag-ingat ka."
- English: "Object detected ahead, be careful."

### 003.mp3 / 006.mp3 (Standard Repetition):
- Tagalog: "May bagay sa harap, mag-ingat ka."
- English: "Object detected ahead, be careful."

**Note:** The actual content depends on what you recorded in these files. The code just selects which file to play based on the profiling answers.

