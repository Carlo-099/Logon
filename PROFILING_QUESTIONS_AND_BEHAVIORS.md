# Profiling Questions and Cane Behaviors Guide

## 📋 ELDERLY CATEGORY

### E1. Balance and Stability
**Question:** Nahihirapan ka bang panatilihin ang balanse habang naglalakad?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo, madalas** | • Sensor range: **100 cm**<br>• Scanning: **Continuous**<br>• Vibration: **Strong, repeated**<br>• Voice: **ON** (002.mp3 or 005.mp3 - depends on language) |
| **Paminsan-minsan** | • Sensor range: **70 cm**<br>• Scanning: **Semi-continuous**<br>• Vibration: **Normal pulse**<br>• Voice: **ON** (002.mp3 or 005.mp3 - depends on language) |
| **Hindi** | • Sensor range: **50 cm**<br>• Scanning: **Event-based**<br>• Vibration: **Soft pulse**<br>• Voice: **OFF** (default) |

---

### E2. Obstacle Collision Experience
**Question:** Nakararanas ka ba ng banggaan sa mga bagay habang naglalakad?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Madalas** | • Range: **100 cm** (overrides E1 if lower)<br>• Alert cooldown: **1 second**<br>• Voice: **ON** (002.mp3 or 005.mp3 - depends on language) |
| **Paminsan-minsan** | • Range: **70 cm** (uses higher of E1 or 70)<br>• Cooldown: **2 seconds**<br>• Voice: **ON** (002.mp3 or 005.mp3 - depends on language) |
| **Bihira** | • Range: **50 cm** (uses higher of E1 or 50)<br>• Cooldown: **3 seconds**<br>• Voice: **OFF** (unless E1 already enabled it) |

---

### E3. Indoor Movement Difficulty
**Question:** Nahihirapan ka bang gumalaw sa loob ng bahay o gusali?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Mode: **Indoor Mode**<br>• Sensor priority: **ON**<br>• Sensing range: **30-80 cm** (adjusted for indoor)<br>• Voice: **ON** (002.mp3 or 005.mp3 - depends on language) |
| **Hindi** | • Mode: **Standard Mode**<br>• Uses sensor range from E1/E2 |

---

### E4. Voice Alert Preference
**Question:** Mas nakakatulong ba sa iyo ang nagsasalitang babala?

**Answers and Behaviors:**

| Answer | Cane Behavior | Follow-up Question |
|--------|---------------|-------------------|
| **Oo** | • DFPlayer + Speaker: **ON**<br>• Voice alerts enabled | **→ Language Selection**<br>• Tagalog or English |
| **Hindi** | • Voice: **OFF**<br>• Vibration: **ON** (if E5 = Oo) | **→ Skip to E5** |

**Note:** If user selects "Oo", they will be asked to choose preferred language (Tagalog/English) before proceeding to E5.

---

### E5. Vibration Feedback Need
**Question:** Mas ramdam mo ba ang babala kapag may vibration?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Coin motor: **ON**<br>• Vibration enabled |
| **Hindi** | • Coin motor: **OFF**<br>• Vibration disabled |

**Important:** This is the **final say** on vibration. If user says "Hindi", vibration will be disabled regardless of other answers.

---

### E7. Walking Fatigue
**Question:** Madali ka bang mapagod kapag naglalakad?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Alert repetition: **LOW** (file 002/005)<br>• Voice delay: **Longer interval** (3000ms) |
| **Hindi** | • Alert repetition: **Standard** (file 003/006)<br>• Voice delay: **Standard interval** (1000ms) |

---

## ⚠️ HIGH-RISK CATEGORY

### H1. Head-Level Obstacle Risk
**Question:** Nakararanas ka ba ng banggaan sa mga bagay na nasa antas ng ulo o dibdib?

**Answers and Behaviors:**

| Answer | Cane Behavior | Next Question |
|--------|---------------|---------------|
| **Oo** | • Sensor angle: **UPWARD**<br>• Detection level: **Head / chest**<br>• Voice: **ON** (002 or 005 - depends on language)<br>• Vibration: **Strong pulse** | **→ H2** (Preferred Warning Type) |
| **Hindi** | • Sensor angle: **Forward** | **→ H4** (Uneven Terrain) |

**Important:** This determines the flow:
- If **Oo**: H1 → H2 → H3 → Save
- If **Hindi**: H1 → H4 → H5 → H6 → Save

---

### H2. Preferred Warning Type
**Question:** Alin ang mas epektibong babala para sa iyo?

**Answers and Behaviors:**

| Answer | Cane Behavior | Follow-up Question |
|--------|---------------|-------------------|
| **Voice lamang** | • Voice: **ON**<br>• Vibration: **OFF** | **→ Language Selection**<br>• Tagalog or English |
| **Vibration lamang** | • Vibration: **ON**<br>• Voice: **OFF** | **→ H3** (Continuous Assistance) |
| **Pareho** | • Voice + Vibration: **ON** | **→ Language Selection**<br>• Tagalog or English |

**Note:** If user selects "Voice lamang" or "Pareho", they will be asked to choose preferred language (Tagalog/English) before proceeding to H3.

---

### H3. Continuous Assistance
**Question:** Kailangan mo ba ng tuloy-tuloy na babala habang naglalakad?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Scanning: **Continuous**<br>• Voice repeat: **ON** (looping) |
| **Hindi** | • Event-based alerts<br>• Voice repeat: **OFF** |

**Note:** After H3, profiling data is automatically saved (if H1 was "Oo").

---

### H4. Uneven or Deep Terrain Experience
**Question:** Nakararanas ka ba ng biglaang pagbaba o hukay sa dinaanan?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Sensor angle: **DOWNWARD**<br>• Depth detection: **ON** |
| **Hindi** | • Standard forward scanning<br>• Depth detection: **OFF** |

**Note:** This question only appears if H1 = "Hindi".

---

### H5. Terrain Voice Warning
**Question:** Gusto mo bang may voice alert kapag may lalim o panganib?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Voice: **ON** (002 or 005 - depends on language)<br>• Terrain warnings enabled |
| **Hindi** | • Voice: **OFF**<br>• No voice for terrain |

**Note:** This question only appears if H1 = "Hindi".

---

### H6. Vibration Alert for Terrain
**Question:** Mas gusto mo bang may vibration kasabay ng babala sa terrain?

**Answers and Behaviors:**

| Answer | Cane Behavior |
|--------|---------------|
| **Oo** | • Vibration: **ON** when depth detected<br>• Terrain vibration enabled |
| **Hindi** | • Vibration: **OFF**<br>• No vibration for terrain |

**Note:** This question only appears if H1 = "Hindi". After H6, profiling data is automatically saved.

---

## 📊 Summary of Behavior Mappings

### Elderly Category Flow:
1. **E1** (Balance) → Sets base sensor range, scanning mode, vibration mode
2. **E2** (Obstacle) → Can override range and cooldown
3. **E3** (Indoor) → Sets indoor mode if "Oo"
4. **E4** (Voice) → **Final say on voice** (if "Hindi", voice is OFF)
   - If "Oo" → Language Selection → E5
   - If "Hindi" → E5
5. **E5** (Vibration) → **Final say on vibration** (if "Hindi", vibration is OFF)
6. **E7** (Fatigue) → Sets alert repetition and voice delay

### High-Risk Category Flow:

**Path 1: H1 = "Oo" (Head-level obstacles)**
- H1 → H2 → Language Selection (if voice selected) → H3 → **Save**

**Path 2: H1 = "Hindi" (No head-level obstacles)**
- H1 → H4 → H5 → H6 → **Save**

---

## 🎯 Key Behavior Parameters

### Sensor Range:
- **100 cm**: Maximum range (elderly with balance issues, frequent collisions)
- **70 cm**: Medium range (occasional issues)
- **50 cm**: Minimum range (no issues, event-based)
- **30-80 cm**: Indoor mode range

### Scanning Modes:
- **Continuous**: Constant scanning (elderly with balance issues, high-risk continuous assistance)
- **Semi-continuous**: Regular scanning
- **Event-based**: Only scans when triggered

### Vibration Modes:
- **Strong, repeated**: High PWM, frequent pulses
- **Normal pulse**: Medium PWM, regular pulses
- **Soft pulse**: Low PWM, gentle pulses

### Voice Files:
- **002.mp3**: Tagalog, LOW repetition
- **003.mp3**: Tagalog, Standard repetition
- **005.mp3**: English, LOW repetition
- **006.mp3**: English, Standard repetition

### Alert Cooldown:
- **1 second**: Frequent collisions
- **2 seconds**: Occasional collisions
- **3 seconds**: Rare collisions

---

## 📝 Notes:

1. **Language Selection**: Appears after E4 (if voice = Oo) or H2 (if voice selected)
2. **Final Say Rules**: 
   - E4 has final say on voice (if "Hindi", voice is OFF)
   - E5 has final say on vibration (if "Hindi", vibration is OFF)
3. **Conditional Flow**: High-risk has two paths based on H1 answer
4. **Auto-Save**: Profiling saves automatically after:
   - E7 (Elderly)
   - H3 (High-risk, if H1 = Oo)
   - H6 (High-risk, if H1 = Hindi)

