import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  // Use a single, shared RTDB instance configured via `firebase_options.dart`.
  // Creating multiple instances with different configs can trigger
  // "Database initialized multiple times" fatal errors (especially on web).
  static FirebaseDatabase get _databaseInstance => FirebaseDatabase.instance;

  late final DatabaseReference _database = _databaseInstance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // ===================== PER-USER CANE CONTROL (B) =====================
  DatabaseReference _userCaneControlRef(String uid) {
    return _database.child('users').child(uid).child('cane_control');
  }
  DatabaseReference _userWifiConfigsRef(String uid) {
    return _database.child('users').child(uid).child('wifi_configs');
  }

  /// Relatives / emergency notification emails (max 3). Used when GPS fix is lost;
  /// actual email sending must be done by a backend (e.g. Cloud Functions + SendGrid).
  DatabaseReference _userEmergencyContactsRef(String uid) {
    return _database.child('users').child(uid).child('emergency_contacts');
  }

  /// Sender Gmail credentials used by ESP32 to send GPS-lost emails (Option C).
  /// WARNING: Storing app passwords in RTDB is insecure; use only if you accept the risk.
  DatabaseReference _userGpsEmailSenderRef(String uid) {
    // Single canonical path for ESP32 + app (do not add flat keys on `gps_email_sender` parent).
    return _database
        .child('users')
        .child(uid)
        .child('gps_email_sender')
        .child('smtp_sender');
  }

  /// Removes legacy duplicate data:
  /// - Flat `gmail` / `appPassword` / `updatedAt` on `gps_email_sender` (old experiments)
  /// - Wrong sibling `users/{uid}/smtp_sender` (should only live under `gps_email_sender/`)
  Future<void> _cleanupLegacyGpsEmailSenderDuplicates(String userId) async {
    final gpsParent = _database.child('users').child(userId).child('gps_email_sender');
    await Future.wait<void>([
      gpsParent.child('gmail').remove(),
      gpsParent.child('appPassword').remove(),
      gpsParent.child('updatedAt').remove(),
    ]);
    await _database.child('users').child(userId).child('smtp_sender').remove();
  }

  static bool isValidEmailFormat(String email) {
    final e = email.trim();
    if (e.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  Future<List<String>> getEmergencyContactEmails() async {
    final userId = getCurrentUserId();
    if (userId == null) return <String>[];

    final snapshot =
        await _userEmergencyContactsRef(userId).child('emails').get();
    if (!snapshot.exists || snapshot.value == null) return <String>[];

    final value = snapshot.value;
    if (value is List) {
      return value
          .map((x) => x?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    }
    return <String>[];
  }

  Stream<List<String>> streamEmergencyContactEmails() {
    final userId = getCurrentUserId();
    if (userId == null) return Stream.value(<String>[]);

    return _userEmergencyContactsRef(userId).child('emails').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <String>[];
      }
      final value = event.snapshot.value;
      if (value is List) {
        return value
            .map((x) => x?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .take(3)
            .toList();
      }
      return <String>[];
    });
  }

  Future<void> saveEmergencyContactEmails(List<String> emails) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final clean = emails
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();

    for (final e in clean) {
      if (!isValidEmailFormat(e)) {
        throw Exception('Invalid email: $e');
      }
    }

    await _userEmergencyContactsRef(userId).set({
      'emails': clean,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clearEmergencyContactEmails() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('User not logged in');
    }
    await _userEmergencyContactsRef(userId).remove();
  }

  Future<Map<String, String>?> getGpsEmailSenderCredentials() async {
    final userId = getCurrentUserId();
    if (userId == null) return null;

    final snapshot = await _userGpsEmailSenderRef(userId).get();
    if (!snapshot.exists || snapshot.value == null) return null;

    final raw = snapshot.value;
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    // Support both keys for compatibility.
    final gmail = (data['email'] ?? data['gmail'] ?? '').toString().trim();
    final appPassword = (data['appPassword'] ?? '').toString();
    if (gmail.isEmpty || appPassword.trim().isEmpty) return null;

    return {
      'gmail': gmail,
      'appPassword': appPassword,
    };
  }

  Future<void> saveGpsEmailSenderCredentials({
    required String gmail,
    required String appPassword,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final g = gmail.trim();
    if (!isValidEmailFormat(g)) {
      throw Exception('Invalid sender Gmail: $g');
    }

    final pw = appPassword.replaceAll(' ', '').trim();
    if (pw.isEmpty) {
      throw Exception('Sender app password is required');
    }

    final ref = _userGpsEmailSenderRef(userId);
    final payload = <String, dynamic>{
      'email': g,
      'appPassword': pw,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await ref.set(payload);
    } on FirebaseException catch (e) {
      throw Exception(
        'Cannot save SMTP sender (${e.code}): ${e.message}. '
        'Allow write on users/$userId/gps_email_sender/smtp_sender in Realtime Database rules.',
      );
    }

    // Read-back from server so we know the write actually persisted (not just local cache).
    final verify = await ref.get();
    if (!verify.exists || verify.value == null || verify.value is! Map) {
      throw Exception('SMTP sender write did not persist (empty or invalid snapshot after save).');
    }
    await _cleanupLegacyGpsEmailSenderDuplicates(userId);
  }

  Future<void> clearGpsEmailSenderCredentials() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('User not logged in');
    }
    await _database.child('users').child(userId).child('gps_email_sender').remove();
    await _database.child('users').child(userId).child('smtp_sender').remove();
  }

  Future<Map<String, dynamic>?> getUserCaneControl() async {
    final userId = getCurrentUserId();
    if (userId == null) return null;
    final snapshot = await _userCaneControlRef(userId).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  Stream<Map<String, dynamic>?> streamUserCaneControl() {
    final userId = getCurrentUserId();
    if (userId == null) return Stream.value(null);
    return _userCaneControlRef(userId).onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  Future<List<Map<String, dynamic>>> getUserWifiConfigs() async {
    final userId = getCurrentUserId();
    if (userId == null) return <Map<String, dynamic>>[];

    final snapshot = await _userWifiConfigsRef(userId).get();
    if (!snapshot.exists || snapshot.value == null) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> result = [];
    final raw = Map<String, dynamic>.from(snapshot.value as Map);
    for (final entry in raw.entries) {
      final item = Map<String, dynamic>.from(entry.value as Map);
      final ssid = (item['ssid'] ?? '').toString();
      final password = (item['password'] ?? '').toString();
      final priority = (item['priority'] is num) ? (item['priority'] as num).toInt() : 9999;
      if (ssid.isNotEmpty) {
        result.add({
          'id': entry.key,
          'ssid': ssid,
          'password': password,
          'priority': priority,
        });
      }
    }
    result.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
    return result;
  }

  Future<void> saveUserWifiConfigsAndMirror(List<Map<String, dynamic>> wifiConfigs) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception("User not logged in");

    final Map<String, dynamic> normalized = {};
    for (int i = 0; i < wifiConfigs.length; i++) {
      final ssid = (wifiConfigs[i]['ssid'] ?? '').toString().trim();
      final password = (wifiConfigs[i]['password'] ?? '').toString();
      if (ssid.isEmpty) continue;
      normalized['wifi_${i + 1}'] = {
        'ssid': ssid,
        'password': password,
        'priority': i + 1,
      };
    }

    await _userWifiConfigsRef(userId).set(normalized);
    await _database.child('wifi_configs').set(normalized);

    // Force ESP32 to restart so it reloads updated WiFi list in setup().
    await _database.child('hardware_control').update({
      'restartRequested': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Saves per-user cane settings to `/users/{uid}/cane_control`
  /// then mirrors to `/hardware_control` (ESP32 reads this).
  Future<void> saveUserCaneControlAndMirror({
    required bool motorEnabled,
    required bool ultrasonicEnabled,
    required bool audioEnabled,
    String? language,
    String? usageLocation,
    String? vibrationIntensity,
    String? volume,
    double? sensorRange,
    String? scanningMode,
    String? vibrationMode,
    int? alertCooldown,
    bool? indoorMode,
    int? alertRepetition,
    int? voiceDelay,
    String? sensorAngle,
    String? detectionLevel,
    bool? voiceRepeat,
    bool? depthDetection,
    bool? terrainVoiceWarning,
    bool restartRequested = false,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception("User not logged in");
    }

    final data = <String, dynamic>{
      'motorEnabled': motorEnabled,
      'ultrasonicEnabled': ultrasonicEnabled,
      'audioEnabled': audioEnabled,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (language != null) data['language'] = language;
    if (usageLocation != null) data['usageLocation'] = usageLocation;
    if (vibrationIntensity != null) data['vibrationIntensity'] = vibrationIntensity;
    if (volume != null) data['volume'] = volume;

    if (sensorRange != null) data['sensorRange'] = sensorRange;
    if (scanningMode != null) data['scanningMode'] = scanningMode;
    if (vibrationMode != null) data['vibrationMode'] = vibrationMode;
    if (alertCooldown != null) data['alertCooldown'] = alertCooldown;
    if (indoorMode != null) data['indoorMode'] = indoorMode;
    if (alertRepetition != null) data['alertRepetition'] = alertRepetition;
    if (voiceDelay != null) data['voiceDelay'] = voiceDelay;

    if (sensorAngle != null) data['sensorAngle'] = sensorAngle;
    if (detectionLevel != null) data['detectionLevel'] = detectionLevel;
    if (voiceRepeat != null) data['voiceRepeat'] = voiceRepeat;
    if (depthDetection != null) data['depthDetection'] = depthDetection;
    if (terrainVoiceWarning != null) data['terrainVoiceWarning'] = terrainVoiceWarning;
    if (restartRequested) data['restartRequested'] = true;

    // Per-user save
    await _userCaneControlRef(userId).set(data);

    // Mirror to hardware_control for ESP32
    await saveHardwareControl(
      motorEnabled: motorEnabled,
      ultrasonicEnabled: ultrasonicEnabled,
      audioEnabled: audioEnabled,
      language: language,
      usageLocation: usageLocation,
      vibrationIntensity: vibrationIntensity,
      volume: volume,
      sensorRange: sensorRange,
      scanningMode: scanningMode,
      vibrationMode: vibrationMode,
      alertCooldown: alertCooldown,
      indoorMode: indoorMode,
      alertRepetition: alertRepetition,
      voiceDelay: voiceDelay,
      sensorAngle: sensorAngle,
      detectionLevel: detectionLevel,
      voiceRepeat: voiceRepeat,
      depthDetection: depthDetection,
      terrainVoiceWarning: terrainVoiceWarning,
      restartRequested: restartRequested,
    );
  }

  // ===================== PROFILING METHODS =====================
  
  // Save profiling data (questionnaire responses) - flexible for both elderly and high-risk
  Future<void> saveProfilingData({
    required String name,
    required String category,
    // Old high-risk fields (deprecated)
    String? usageLocation,
    bool? handSensitivity,
    String? vibrationIntensity,
    bool? voiceAlertEnabled,
    // Common fields
    String? language,
    String? volume,
    // Elderly category specific fields
    String? balanceStability,
    String? obstacleCollision,
    bool? indoorDifficulty,
    bool? voicePreference,
    bool? vibrationNeed,
    bool? walkingFatigue,
    // High-risk category fields (H1-H6)
    bool? headLevelObstacle,
    String? preferredWarningType,
    bool? continuousAssistance,
    bool? unevenTerrain,
    bool? terrainVoiceWarning,
    bool? terrainVibrationAlert,
    // Calculated behaviors (for elderly)
    Map<String, dynamic>? behaviors,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception("User not logged in");
      }

      final data = <String, dynamic>{
        'name': name,
        'category': category,
        'questionnaireCompleted': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Add category-specific fields
      if (category == 'elderly') {
        if (balanceStability != null) data['balanceStability'] = balanceStability;
        if (obstacleCollision != null) data['obstacleCollision'] = obstacleCollision;
        if (indoorDifficulty != null) data['indoorDifficulty'] = indoorDifficulty;
        if (voicePreference != null) data['voicePreference'] = voicePreference;
        if (vibrationNeed != null) data['vibrationNeed'] = vibrationNeed;
        if (walkingFatigue != null) data['walkingFatigue'] = walkingFatigue;
        if (behaviors != null) {
          data.addAll(behaviors);
        }
      } else if (category == 'high-risk') {
        // High-risk category (H1-H6)
        if (headLevelObstacle != null) data['headLevelObstacle'] = headLevelObstacle;
        if (preferredWarningType != null) data['preferredWarningType'] = preferredWarningType;
        if (continuousAssistance != null) data['continuousAssistance'] = continuousAssistance;
        if (unevenTerrain != null) data['unevenTerrain'] = unevenTerrain;
        if (terrainVoiceWarning != null) data['terrainVoiceWarning'] = terrainVoiceWarning;
        if (terrainVibrationAlert != null) data['terrainVibrationAlert'] = terrainVibrationAlert;
      }
      
      // Common fields for both categories
      if (language != null) data['language'] = language;
      if (volume != null) data['volume'] = volume;

      await _database.child('profiling').child(userId).set(data);
    } catch (e) {
      throw Exception("Failed to save profiling data: $e");
    }
  }

  // Get profiling data
  // Delete profiling data for current user
  Future<void> deleteProfilingData() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception("User not logged in");
      }
      
      // Delete profiling data
      await _database.child('profiling').child(userId).remove();
      
      // Also clear hardware_control to reset ESP32
      await _database.child('hardware_control').remove();
    } catch (e) {
      throw Exception("Failed to delete profiling data: $e");
    }
  }

  Future<Map<String, dynamic>?> getProfilingData() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return null;

      final snapshot = await _database.child('profiling').child(userId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception("Failed to get profiling data: $e");
    }
  }

  // Stream profiling data for real-time updates
  Stream<Map<String, dynamic>?> streamProfilingData() {
    final userId = getCurrentUserId();
    if (userId == null) {
      return Stream.value(null);
    }

    return _database.child('profiling').child(userId).onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  // ===================== GPS METHODS =====================

  // Save GPS coordinates (called by ESP32, but can be used from app too)
  Future<void> saveGPSData({
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _database.child('gps').set({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception("Failed to save GPS data: $e");
    }
  }

  // Get GPS data
  Future<Map<String, dynamic>?> getGPSData() async {
    try {
      final snapshot = await _database.child('gps').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception("Failed to get GPS data: $e");
    }
  }

  // Stream GPS data for real-time updates
  Stream<Map<String, dynamic>?> streamGPSData() {
    return _database.child('gps').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  // ===================== ESP32 CONTROL METHODS =====================

  // Save hardware control settings (for ESP32 to read)
  Future<void> saveHardwareControl({
    required bool motorEnabled,
    required bool ultrasonicEnabled,
    required bool audioEnabled,
    String? language,
    String? usageLocation,
    String? vibrationIntensity,
    String? volume,
    // Elderly category specific behaviors
    double? sensorRange,
    String? scanningMode,
    String? vibrationMode,
    int? alertCooldown,
    bool? indoorMode,
    int? alertRepetition,
    int? voiceDelay,
    // High-risk category specific behaviors
    String? sensorAngle,
    String? detectionLevel,
    bool? voiceRepeat,
    bool? depthDetection,
    bool? terrainVoiceWarning, // H5: Terrain voice warning enabled
    bool? restartRequested, // Optional: only set if restart is needed
  }) async {
    try {
      final ownerUid = getCurrentUserId();
      final data = {
        'motorEnabled': motorEnabled,
        'ultrasonicEnabled': ultrasonicEnabled,
        'audioEnabled': audioEnabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      if (ownerUid != null && ownerUid.isNotEmpty) {
        data['ownerUid'] = ownerUid;
      }
      
      // Add optional fields if provided
      if (language != null) {
        data['language'] = language;
      }
      if (usageLocation != null) {
        data['usageLocation'] = usageLocation;
      }
      if (vibrationIntensity != null) {
        data['vibrationIntensity'] = vibrationIntensity;
      }
      if (volume != null) {
        data['volume'] = volume;
      }
      
      // Add elderly category behaviors if provided
      if (sensorRange != null) {
        data['sensorRange'] = sensorRange;
      }
      if (scanningMode != null) {
        data['scanningMode'] = scanningMode;
      }
      if (vibrationMode != null) {
        data['vibrationMode'] = vibrationMode;
      }
      if (alertCooldown != null) {
        data['alertCooldown'] = alertCooldown;
      }
      if (indoorMode != null) {
        data['indoorMode'] = indoorMode;
      }
      if (alertRepetition != null) {
        data['alertRepetition'] = alertRepetition;
      }
      if (voiceDelay != null) {
        data['voiceDelay'] = voiceDelay;
      }
      
      // Add high-risk category behaviors if provided
      if (sensorAngle != null) {
        data['sensorAngle'] = sensorAngle;
      }
      if (detectionLevel != null) {
        data['detectionLevel'] = detectionLevel;
      }
      if (voiceRepeat != null) {
        data['voiceRepeat'] = voiceRepeat;
      }
      if (depthDetection != null) {
        data['depthDetection'] = depthDetection;
      }
      if (terrainVoiceWarning != null) {
        data['terrainVoiceWarning'] = terrainVoiceWarning;
      }
      
      // Only set restart flag when explicitly requested by the app.
      if (restartRequested == true) {
        data['restartRequested'] = true;
      }
      
      await _database.child('hardware_control').set(data);
    } catch (e) {
      throw Exception("Failed to save hardware control: $e");
    }
  }

  // Get hardware control settings
  Stream<Map<String, dynamic>?> streamHardwareControl() {
    return _database.child('hardware_control').onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  // ===================== TEXT SIZE SETTINGS =====================

  // Save text size preference (medium or large) - saved to profiling data
  Future<void> saveTextSize(String textSize) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception("User not logged in");
      }

      // Save to profiling data (which has proper auth rules)
      await _database.child('profiling').child(userId).child('textSize').set(textSize);
    } catch (e) {
      throw Exception("Failed to save text size: $e");
    }
  }

  // Get text size preference
  Future<String?> getTextSize() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return null;

      final snapshot = await _database.child('profiling').child(userId).child('textSize').get();
      if (snapshot.exists) {
        return snapshot.value as String;
      }
      return 'medium'; // Default
    } catch (e) {
      return 'medium'; // Default on error
    }
  }
}

