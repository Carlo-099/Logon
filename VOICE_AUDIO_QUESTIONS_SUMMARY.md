# Voice/Audio Questions Summary

## 📋 ELDERLY CATEGORY - Mga Tanong na May Kinalaman sa Voice/Audio

### E4. Voice Alert Preference ⭐ **FINAL SAY**
**Tanong:** Mas nakakatulong ba sa iyo ang nagsasalitang babala?

| Sagot | Audio File | Epekto |
|-------|------------|--------|
| **Oo** | Depende sa E7 | Voice ON - gagamitin ang audio file base sa E7 |
| **Hindi** | **WALA (Voice OFF)** | Voice OFF - walang audio kahit ano pa ang ibang sagot |

**Important:** 
- Ito ang **PINAKA-IMPORTANTE** na tanong para sa audio
- Kung "Hindi", **WALANG AUDIO** kahit ano pa ang sagot sa E7
- Kung "Oo", magpapatuloy sa E7 para malaman kung aling audio file

---

### E7. Walking Fatigue ⭐ **NAG-DEDECIDE NG AUDIO FILE**
**Tanong:** Madali ka bang mapagod kapag naglalakad?

| Sagot | Audio File (Tagalog) | Audio File (English) | Voice Delay |
|-------|---------------------|---------------------|-------------|
| **Oo** (Gets tired easily) | **002.mp3** | **005.mp3** | 3000ms (3 seconds) |
| **Hindi** (Doesn't get tired) | **003.mp3** | **006.mp3** | 1000ms (1 second) |

**Important:**
- Ito ang **NAG-DEDECIDE** kung aling audio file ang gagamitin
- **E7 = "Oo"** → 002.mp3 (Tagalog) o 005.mp3 (English) - LOW repetition
- **E7 = "Hindi"** → 003.mp3 (Tagalog) o 006.mp3 (English) - Standard repetition

**Note:** Gagana lang kung **E4 = "Oo"** (Voice preference)

---

### E1, E2, E3, E5 - WALANG DIRECT EPEKTO SA AUDIO
- **E1** (Balance): Walang direct audio file - vibration at sensor range lang
- **E2** (Obstacle): Walang direct audio file - cooldown lang
- **E3** (Indoor): Walang direct audio file - sensing range lang
- **E5** (Vibration): Walang epekto sa audio - vibration lang

---

## ⚠️ HIGH-RISK CATEGORY - Mga Tanong na May Kinalaman sa Voice/Audio

### H2. Preferred Warning Type ⭐ **FINAL SAY**
**Tanong:** Alin ang mas epektibong babala para sa iyo?

| Sagot | Audio File | Epekto |
|-------|------------|--------|
| **Voice lamang** | 002.mp3 (Tagalog) o 005.mp3 (English) | Voice ON - gagamitin ang audio file |
| **Vibration lamang** | **WALA (Voice OFF)** | Voice OFF - walang audio |
| **Pareho** | 002.mp3 (Tagalog) o 005.mp3 (English) | Voice ON - gagamitin ang audio file |

**Important:**
- Ito ang **FINAL SAY** para sa head-level warnings (H1 = "Oo")
- Kung "Vibration lamang", **WALANG AUDIO** para sa head-level
- Kung "Voice lamang" o "Pareho", gagamitin ang 002/005

---

### H3. Continuous Assistance ⭐ **NAG-DEDECIDE NG PLAYBACK MODE**
**Tanong:** Kailangan mo ba ng tuloy-tuloy na babala habang naglalakad?

| Sagot | Audio File | Playback Mode |
|-------|------------|---------------|
| **Oo** | **002.mp3** (Tagalog) o **005.mp3** (English) | **LOOPS continuously** (walang cooldown) |
| **Hindi** | **002.mp3** (Tagalog) o **005.mp3** (English) | **Plays once** (may cooldown) |

**Important:**
- Parehong audio file (002/005) ang ginagamit
- **H3 = "Oo"** → Audio **LOOPS** habang may object detected
- **H3 = "Hindi"** → Audio **plays once** per detection

**Note:** Gagana lang kung **H2 = "Voice lamang"** o **"Pareho"**

---

### H5. Terrain Voice Warning ⭐ **FINAL SAY PARA SA TERRAIN**
**Tanong:** Gusto mo bang may voice alert kapag may lalim o panganib?

| Sagot | Audio File (Tagalog) | Audio File (English) | Epekto |
|-------|---------------------|---------------------|--------|
| **Oo** | **002.mp3** | **005.mp3** | Voice ON para sa terrain warnings |
| **Hindi** | **WALA (Voice OFF)** | **WALA (Voice OFF)** | Voice OFF para sa terrain |

**Important:**
- Ito ang **FINAL SAY** para sa terrain warnings (H1 = "Hindi")
- Kung "Oo", gagamitin ang 002/005 para sa terrain detection
- Kung "Hindi", walang audio para sa terrain

**Note:** Gagana lang kung **H1 = "Hindi"** (no head-level obstacles)

---

### H1, H4, H6 - WALANG DIRECT EPEKTO SA AUDIO FILE SELECTION
- **H1** (Head-level): Nagdedecide lang kung head-level o terrain path, pero parehong 002/005 ang audio file
- **H4** (Terrain): Walang direct audio file - depth detection lang
- **H6** (Terrain Vibration): Walang epekto sa audio - vibration lang

---

## 🎵 COMPLETE AUDIO FILE MAPPING

### ELDERLY CATEGORY:

**Startup Audio:**
- Tagalog: **001.mp3**
- English: **004.mp3**

**Detection Audio (depende sa E4 at E7):**

| E4 (Voice) | E7 (Fatigue) | Audio File (Tagalog) | Audio File (English) | Voice Delay |
|------------|--------------|---------------------|---------------------|-------------|
| **Oo** | **Oo** | **002.mp3** | **005.mp3** | 3000ms |
| **Oo** | **Hindi** | **003.mp3** | **006.mp3** | 1000ms |
| **Hindi** | Anuman | **WALA** | **WALA** | N/A |

**Logic:**
1. Check E4 first - kung "Hindi", walang audio
2. Kung E4 = "Oo", check E7:
   - E7 = "Oo" → 002/005 (LOW repetition, 3000ms delay)
   - E7 = "Hindi" → 003/006 (Standard repetition, 1000ms delay)

---

### HIGH-RISK CATEGORY:

**Startup Audio:**
- Tagalog: **001.mp3**
- English: **004.mp3**

**Detection Audio (depende sa H1, H2, H3, H5):**

#### Path 1: H1 = "Oo" (Head-level obstacles)

| H2 (Warning Type) | H3 (Continuous) | Audio File (Tagalog) | Audio File (English) | Playback Mode |
|-------------------|-----------------|---------------------|---------------------|---------------|
| **Voice lamang** | **Oo** | **002.mp3** | **005.mp3** | **LOOPS** |
| **Voice lamang** | **Hindi** | **002.mp3** | **005.mp3** | **Single play** |
| **Pareho** | **Oo** | **002.mp3** | **005.mp3** | **LOOPS** |
| **Pareho** | **Hindi** | **002.mp3** | **005.mp3** | **Single play** |
| **Vibration lamang** | Anuman | **WALA** | **WALA** | N/A |

**Logic:**
1. Check H2 first - kung "Vibration lamang", walang audio
2. Kung H2 = "Voice lamang" o "Pareho":
   - Laging 002/005 ang audio file
   - H3 = "Oo" → LOOPS continuously
   - H3 = "Hindi" → Plays once (may cooldown)

#### Path 2: H1 = "Hindi" (No head-level, Terrain path)

| H5 (Terrain Voice) | Audio File (Tagalog) | Audio File (English) | Playback Mode |
|--------------------|---------------------|---------------------|---------------|
| **Oo** | **002.mp3** | **005.mp3** | **Single play** (event-based) |
| **Hindi** | **WALA** | **WALA** | N/A |

**Logic:**
1. Check H5 - kung "Oo", gagamitin ang 002/005 para sa terrain warnings
2. Kung "Hindi", walang audio para sa terrain

---

## 📊 QUICK REFERENCE TABLE

### Questions na May Kinalaman sa Audio:

| Question | Category | Epekto sa Audio | Audio File |
|----------|----------|-----------------|------------|
| **E4** | Elderly | FINAL SAY (Voice ON/OFF) | Depende sa E7 |
| **E7** | Elderly | NAG-DEDECIDE ng audio file | 002/005 o 003/006 |
| **H2** | High-risk | FINAL SAY (Voice ON/OFF) | 002/005 (kung ON) |
| **H3** | High-risk | Playback mode (loop o single) | 002/005 (same file) |
| **H5** | High-risk | FINAL SAY para sa terrain | 002/005 (kung ON) |

### Questions na WALANG Kinalaman sa Audio:

| Question | Category | Epekto |
|----------|----------|--------|
| E1 | Elderly | Sensor range, vibration mode lang |
| E2 | Elderly | Cooldown lang |
| E3 | Elderly | Sensing range lang |
| E5 | Elderly | Vibration lang |
| H1 | High-risk | Path selection lang (parehong 002/005) |
| H4 | High-risk | Depth detection lang |
| H6 | High-risk | Vibration lang |

---

## 🎯 SUMMARY

### ELDERLY - Audio Questions:
1. **E4** (Voice Preference) - FINAL SAY
   - "Oo" → Voice ON
   - "Hindi" → Voice OFF (walang audio)

2. **E7** (Walking Fatigue) - NAG-DEDECIDE NG FILE
   - "Oo" → 002.mp3 (Tagalog) o 005.mp3 (English)
   - "Hindi" → 003.mp3 (Tagalog) o 006.mp3 (English)

### HIGH-RISK - Audio Questions:
1. **H2** (Warning Type) - FINAL SAY para sa head-level
   - "Voice lamang" o "Pareho" → Voice ON (002/005)
   - "Vibration lamang" → Voice OFF

2. **H3** (Continuous) - Playback mode
   - "Oo" → LOOPS (002/005)
   - "Hindi" → Single play (002/005)

3. **H5** (Terrain Voice) - FINAL SAY para sa terrain
   - "Oo" → Voice ON (002/005)
   - "Hindi" → Voice OFF

---

## 📝 IMPORTANT NOTES:

1. **FINAL SAY Rules:**
   - E4 (Elderly) at H2 (High-risk) - kung "Hindi" o "Vibration lamang", walang audio
   - H5 (High-risk terrain) - kung "Hindi", walang audio para sa terrain

2. **Audio File Selection:**
   - Elderly: Depende sa E7 (002/005 o 003/006)
   - High-risk: Laging 002/005 (pareho para sa head-level at terrain)

3. **Playback Mode:**
   - Elderly: Laging single play (may cooldown)
   - High-risk: Depende sa H3 (loop o single play)

4. **Startup Audio:**
   - Parehong 001.mp3 (Tagalog) o 004.mp3 (English) para sa lahat
   - Hindi naaapektuhan ng profiling questions
