# Profiling Questions at Audio Files Mapping

## 📋 ELDERLY CATEGORY - Mga Tanong

### E1. Balance and Stability
**Tanong:** Nahihirapan ka bang panatilihin ang balanse habang naglalakad?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Oo, madalas** | 002.mp3 | 005.mp3 | Kapag may object detected (LOW repetition) |
| **Paminsan-minsan** | 002.mp3 | 005.mp3 | Kapag may object detected (LOW repetition) |
| **Hindi** | Wala (Voice OFF) | Wala (Voice OFF) | Walang audio |

**Note:** Ang actual na audio file ay depende sa E7 (Walking Fatigue) at E4 (Voice Preference)

---

### E2. Obstacle Collision Experience
**Tanong:** Nakararanas ka ba ng banggaan sa mga bagay habang naglalakad?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Madalas** | 002.mp3 o 003.mp3 | 005.mp3 o 006.mp3 | Depende sa E7 (Fatigue) |
| **Paminsan-minsan** | 002.mp3 o 003.mp3 | 005.mp3 o 006.mp3 | Depende sa E7 (Fatigue) |
| **Bihira** | 002.mp3 o 003.mp3 | 005.mp3 o 006.mp3 | Depende sa E7 (Fatigue) |

**Note:** Ang audio file ay depende sa E7 (Walking Fatigue):
- E7 = "Oo" → 002.mp3 (Tagalog) o 005.mp3 (English) - LOW repetition
- E7 = "Hindi" → 003.mp3 (Tagalog) o 006.mp3 (English) - Standard repetition

---

### E3. Indoor Movement Difficulty
**Tanong:** Nahihirapan ka bang gumalaw sa loob ng bahay o gusali?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Oo** | 002.mp3 o 003.mp3 | 005.mp3 o 006.mp3 | Depende sa E7 (Fatigue) |
| **Hindi** | 002.mp3 o 003.mp3 | 005.mp3 o 006.mp3 | Depende sa E7 (Fatigue) |

**Note:** Parehong logic sa E2 - depende sa E7 (Fatigue)

---

### E4. Voice Alert Preference
**Tanong:** Mas nakakatulong ba sa iyo ang nagsasalitang babala?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Oo** | Depende sa E7 | Depende sa E7 | Kapag may object detected |
| **Hindi** | Wala (Voice OFF) | Wala (Voice OFF) | Walang audio kahit may detection |

**Important:** Ito ang **FINAL SAY** sa voice. Kung "Hindi", walang audio kahit ano pa ang ibang sagot.

**Follow-up:** Kung "Oo", tatanungin ang language preference (Tagalog/English)

---

### E5. Vibration Feedback Need
**Tanong:** Mas ramdam mo ba ang babala kapag may vibration?

| Sagot | Audio File | Epekto |
|-------|------------|--------|
| **Oo** | Walang epekto sa audio | Vibration ON lang |
| **Hindi** | Walang epekto sa audio | Vibration OFF lang |

**Note:** Walang epekto sa audio files - vibration lang ang naaapektuhan

---

### E7. Walking Fatigue
**Tanong:** Madali ka bang mapagod kapag naglalakad?

| Sagot | Audio File (Tagalog) | Audio File (English) | Voice Delay |
|-------|---------------------|---------------------|-------------|
| **Oo** | **002.mp3** (LOW repetition) | **005.mp3** (LOW repetition) | 3000ms (3 seconds) |
| **Hindi** | **003.mp3** (Standard repetition) | **006.mp3** (Standard repetition) | 1000ms (1 second) |

**Important:** Ito ang **NAG-DEDECIDE** kung aling audio file ang gagamitin:
- **E7 = "Oo"** → 002.mp3 (Tagalog) o 005.mp3 (English)
- **E7 = "Hindi"** → 003.mp3 (Tagalog) o 006.mp3 (English)

---

## ⚠️ HIGH-RISK CATEGORY - Mga Tanong

### H1. Head-Level Obstacle Risk
**Tanong:** Nakararanas ka ba ng banggaan sa mga bagay na nasa antas ng ulo o dibdib?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Oo** | **002.mp3** (Head-level warning) | **005.mp3** (Head-level warning) | Kapag may head-level object detected |
| **Hindi** | Depende sa H5 | Depende sa H5 | Kung H5 = "Oo" (Terrain voice warning) |

**Note:** 
- Kung H1 = "Oo" → Laging **002.mp3** (Tagalog) o **005.mp3** (English) para sa head-level warnings
- Kung H1 = "Hindi" → Magpapatuloy sa H4 (Terrain questions)

---

### H2. Preferred Warning Type
**Tanong:** Alin ang mas epektibong babala para sa iyo?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Voice lamang** | 002.mp3 | 005.mp3 | Kapag may head-level object detected |
| **Vibration lamang** | Wala (Voice OFF) | Wala (Voice OFF) | Walang audio |
| **Pareho** | 002.mp3 | 005.mp3 | Kapag may head-level object detected |

**Follow-up:** Kung "Voice lamang" o "Pareho", tatanungin ang language preference (Tagalog/English)

---

### H3. Continuous Assistance
**Tanong:** Kailangan mo ba ng tuloy-tuloy na babala habang naglalakad?

| Sagot | Audio File (Tagalog) | Audio File (English) | Playback Mode |
|-------|---------------------|---------------------|---------------|
| **Oo** | **002.mp3** (LOOPING) | **005.mp3** (LOOPING) | Continuous loop habang may object |
| **Hindi** | **002.mp3** (Single play) | **005.mp3** (Single play) | Play once per detection |

**Note:** Parehong audio file (002/005), pero:
- **H3 = "Oo"** → Audio **LOOPS continuously** (walang cooldown)
- **H3 = "Hindi"** → Audio **plays once** (may cooldown)

---

### H4. Uneven or Deep Terrain Experience
**Tanong:** Nakararanas ka ba ng biglaang pagbaba o hukay sa dinaanan?

| Sagot | Audio File | Epekto |
|-------|------------|--------|
| **Oo** | Depende sa H5 | Depth detection ON |
| **Hindi** | Depende sa H5 | Depth detection OFF |

**Note:** Walang direct audio file - depende sa H5 (Terrain Voice Warning)

---

### H5. Terrain Voice Warning
**Tanong:** Gusto mo bang may voice alert kapag may lalim o panganib?

| Sagot | Audio File (Tagalog) | Audio File (English) | Kailan Ginagamit |
|-------|---------------------|---------------------|------------------|
| **Oo** | **002.mp3** (Terrain warning) | **005.mp3** (Terrain warning) | Kapag may depth/terrain detected |
| **Hindi** | Wala (Voice OFF) | Wala (Voice OFF) | Walang audio para sa terrain |

**Note:** Parehong audio file (002/005) para sa terrain warnings

---

### H6. Vibration Alert for Terrain
**Tanong:** Mas gusto mo bang may vibration kasabay ng babala sa terrain?

| Sagot | Audio File | Epekto |
|-------|------------|--------|
| **Oo** | Walang epekto sa audio | Vibration ON lang para sa terrain |
| **Hindi** | Walang epekto sa audio | Vibration OFF lang para sa terrain |

**Note:** Walang epekto sa audio files - vibration lang ang naaapektuhan

---

## 🎵 AUDIO FILES SUMMARY

### Current Audio File Mapping:

| File Number | Tagalog | English | Usage |
|-------------|---------|---------|-------|
| **001.mp3** | Startup/Welcome | - | System boot (Tagalog) |
| **002.mp3** | LOW repetition / Head-level | - | Elderly (E7=Oo), High-risk (H1=Oo, H5=Oo) |
| **003.mp3** | Standard repetition | - | Elderly (E7=Hindi) |
| **004.mp3** | - | Startup/Welcome | System boot (English) |
| **005.mp3** | - | LOW repetition / Head-level | Elderly (E7=Oo), High-risk (H1=Oo, H5=Oo) |
| **006.mp3** | - | Standard repetition | Elderly (E7=Hindi) |

---

## 📊 COMPLETE AUDIO FILE SELECTION LOGIC

### ELDERLY CATEGORY:

**Startup Audio:**
- Tagalog: **001.mp3**
- English: **004.mp3**

**Detection Audio (depende sa E7):**
- **E7 = "Oo"** (Gets tired easily):
  - Tagalog: **002.mp3** (LOW repetition, 3000ms delay)
  - English: **005.mp3** (LOW repetition, 3000ms delay)
  
- **E7 = "Hindi"** (Doesn't get tired easily):
  - Tagalog: **003.mp3** (Standard repetition, 1000ms delay)
  - English: **006.mp3** (Standard repetition, 1000ms delay)

**Conditions:**
- Audio lang gagana kung **E4 = "Oo"** (Voice preference)
- Kung **E4 = "Hindi"**, walang audio kahit ano pa ang E7

---

### HIGH-RISK CATEGORY:

**Startup Audio:**
- Tagalog: **001.mp3**
- English: **004.mp3**

**Detection Audio (laging 002/005):**
- **H1 = "Oo"** (Head-level obstacles):
  - Tagalog: **002.mp3** (Head-level warning)
  - English: **005.mp3** (Head-level warning)
  - Playback: Depende sa H3
    - H3 = "Oo" → **LOOPS continuously**
    - H3 = "Hindi" → **Plays once** (may cooldown)

- **H1 = "Hindi"** + **H5 = "Oo"** (Terrain warnings):
  - Tagalog: **002.mp3** (Terrain warning)
  - English: **005.mp3** (Terrain warning)
  - Playback: Single play (event-based)

**Conditions:**
- Audio lang gagana kung:
  - **H2 = "Voice lamang"** o **"Pareho"** (para sa head-level)
  - **H5 = "Oo"** (para sa terrain)
- Kung **H2 = "Vibration lamang"**, walang audio

---

## 🔄 AUDIO FILE REPLACEMENT GUIDE

Kung may bagong audio files ka, ito ang mga file na kailangan mong palitan:

### Para sa ELDERLY Category:

1. **001.mp3** (Tagalog Startup)
   - Current: Welcome message sa Tagalog
   - Usage: System boot (Tagalog users)

2. **002.mp3** (Tagalog LOW Repetition)
   - Current: Obstacle warning (LOW repetition)
   - Usage: E7 = "Oo" (Gets tired easily)
   - Delay: 3000ms

3. **003.mp3** (Tagalog Standard Repetition)
   - Current: Obstacle warning (Standard repetition)
   - Usage: E7 = "Hindi" (Doesn't get tired easily)
   - Delay: 1000ms

4. **004.mp3** (English Startup)
   - Current: Welcome message sa English
   - Usage: System boot (English users)

5. **005.mp3** (English LOW Repetition)
   - Current: Obstacle warning (LOW repetition)
   - Usage: E7 = "Oo" (Gets tired easily)
   - Delay: 3000ms

6. **006.mp3** (English Standard Repetition)
   - Current: Obstacle warning (Standard repetition)
   - Usage: E7 = "Hindi" (Doesn't get tired easily)
   - Delay: 1000ms

### Para sa HIGH-RISK Category:

1. **002.mp3** (Tagalog Head-level/Terrain)
   - Current: Head-level o terrain warning
   - Usage: 
     - H1 = "Oo" (Head-level obstacles)
     - H5 = "Oo" (Terrain warnings)
   - Playback: Depende sa H3 (loop o single)

2. **005.mp3** (English Head-level/Terrain)
   - Current: Head-level o terrain warning
   - Usage: 
     - H1 = "Oo" (Head-level obstacles)
     - H5 = "Oo" (Terrain warnings)
   - Playback: Depende sa H3 (loop o single)

**Note:** Parehong audio file (002/005) ang ginagamit para sa head-level at terrain warnings sa high-risk category.

---

## 📝 IMPORTANT NOTES:

1. **File Naming:** Dapat eksaktong match ang file names:
   - 001.mp3, 002.mp3, 003.mp3, 004.mp3, 005.mp3, 006.mp3
   - Dapat nasa **Folder 1** ng SD card

2. **Audio Content:**
   - 002.mp3 at 003.mp3 (Tagalog) - Parehong obstacle warning, pero iba ang timing
   - 005.mp3 at 006.mp3 (English) - Parehong obstacle warning, pero iba ang timing
   - 002.mp3 (Tagalog) at 005.mp3 (English) - Parehong content, iba lang ang language

3. **Replacement:**
   - Pwedeng palitan ang audio files basta same file names
   - Hindi kailangan baguhin ang code
   - Dapat nasa SD card na naka-insert sa DFPlayer Mini

4. **Testing:**
   - After replacing files, test lahat ng scenarios:
     - Elderly: E7 = "Oo" vs "Hindi"
     - High-risk: H1 = "Oo" vs "Hindi"
     - Both languages: Tagalog vs English

---

## 🎯 QUICK REFERENCE:

**Elderly Detection Audio:**
- E7 = "Oo" → 002.mp3 (Tagalog) o 005.mp3 (English)
- E7 = "Hindi" → 003.mp3 (Tagalog) o 006.mp3 (English)

**High-Risk Detection Audio:**
- H1 = "Oo" → 002.mp3 (Tagalog) o 005.mp3 (English)
- H1 = "Hindi" + H5 = "Oo" → 002.mp3 (Tagalog) o 005.mp3 (English)

**Startup Audio:**
- Tagalog → 001.mp3
- English → 004.mp3
