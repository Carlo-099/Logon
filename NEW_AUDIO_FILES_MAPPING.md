# New Audio Files Mapping

## 🎵 Updated Audio File Mapping

### ELDERLY CATEGORY

#### E4 = "Oo" + E7 = "Oo" (Gets tired easily)
- **Tagalog:** `009.mp3` - "may harang"
- **English:** `0014.mp3` - "There is an Obstacle"
- **Voice Delay:** 3000ms (3 seconds)

#### E4 = "Oo" + E7 = "Hindi" (Doesn't get tired easily)
- **Tagalog:** `0010.mp3` - "babala malapit na ang harang"
- **English:** `0015.mp3` - "Warning: obstacle approaching"
- **Voice Delay:** 1000ms (1 second)

---

### HIGH-RISK CATEGORY

#### H2 = "Voice lamang" o "Pareho" + H1 = "Oo" (Head-level obstacles)
- **Tagalog:** `002.mp3` - Head-level warning (NO CHANGE)
- **English:** `005.mp3` - Head-level warning (NO CHANGE)
- **Playback:** Depende sa H3 (loop o single play)

#### H5 = "Oo" + H1 = "Hindi" (Terrain warnings)
- **Tagalog:** `0012.mp3` - "babala, may lalim sa unahan"
- **English:** `0017.mp3` - "Warning: there's a drop ahead"
- **Playback:** Single play (event-based)

---

## 📋 Complete Audio File List

| File Number | Language | Usage | When Used |
|-------------|----------|-------|-----------|
| **001.mp3** | Tagalog | Startup | System boot (Tagalog users) |
| **002.mp3** | Tagalog | Head-level | High-risk H1="Oo" (NO CHANGE) |
| **004.mp3** | English | Startup | System boot (English users) |
| **005.mp3** | English | Head-level | High-risk H1="Oo" (NO CHANGE) |
| **009.mp3** | Tagalog | Detection | Elderly E7="Oo" (NEW) |
| **0010.mp3** | Tagalog | Detection | Elderly E7="Hindi" (NEW) |
| **0012.mp3** | Tagalog | Terrain | High-risk H5="Oo" + H1="Hindi" (NEW) |
| **0014.mp3** | English | Detection | Elderly E7="Oo" (NEW) |
| **0015.mp3** | English | Detection | Elderly E7="Hindi" (NEW) |
| **0017.mp3** | English | Terrain | High-risk H5="Oo" + H1="Hindi" (NEW) |

---

## 🔄 Changes Made

### ESP32 Code:
1. ✅ Created new `getDetectionAudioFile()` function
2. ✅ Updated audio selection logic to use new file numbers
3. ✅ Added `terrainVoiceWarning` variable to read from Firebase
4. ✅ Updated logging to show new file numbers

### Flutter Code:
1. ✅ Added `terrainVoiceWarning` parameter to `saveHardwareControl()`
2. ✅ Updated profiling page to save `terrainVoiceWarning` to hardware_control
3. ✅ Updated `_calculateHighRiskBehaviors()` to include `terrainVoiceWarning`

---

## 📝 Important Notes:

1. **File Naming:** 
   - Dapat eksaktong match: `009.mp3`, `0010.mp3`, `0012.mp3`, `0014.mp3`, `0015.mp3`, `0017.mp3`
   - Dapat nasa **Folder 1** ng SD card

2. **Old Files (No Longer Used):**
   - `003.mp3` (Tagalog Standard) - Replaced by `0010.mp3`
   - `006.mp3` (English Standard) - Replaced by `0015.mp3`
   - Pwedeng i-delete o i-keep para sa backup

3. **Still Used:**
   - `001.mp3` (Tagalog Startup) - Still used
   - `002.mp3` (Tagalog Head-level) - Still used for high-risk
   - `004.mp3` (English Startup) - Still used
   - `005.mp3` (English Head-level) - Still used for high-risk

4. **Testing:**
   - Test Elderly: E4="Oo" + E7="Oo" → Should play 009/0014
   - Test Elderly: E4="Oo" + E7="Hindi" → Should play 0010/0015
   - Test High-risk: H1="Oo" → Should play 002/005 (no change)
   - Test High-risk: H1="Hindi" + H5="Oo" → Should play 0012/0017

---

## 🎯 Quick Reference:

**Elderly Detection Audio:**
- E4="Oo" + E7="Oo" → 009.mp3 (Tagalog) o 0014.mp3 (English)
- E4="Oo" + E7="Hindi" → 0010.mp3 (Tagalog) o 0015.mp3 (English)

**High-Risk Detection Audio:**
- H1="Oo" → 002.mp3 (Tagalog) o 005.mp3 (English) - NO CHANGE
- H1="Hindi" + H5="Oo" → 0012.mp3 (Tagalog) o 0017.mp3 (English)

**Startup Audio:**
- Tagalog → 001.mp3 - NO CHANGE
- English → 004.mp3 - NO CHANGE
