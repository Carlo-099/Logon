import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  // Configure Firebase Realtime Database with your database URL
  static FirebaseDatabase get _databaseInstance {
    try {
      return FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: 'https://login-4e779-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
    } catch (e) {
      // Fallback to default instance if custom URL fails
      return FirebaseDatabase.instance;
    }
  }

  late final DatabaseReference _database = _databaseInstance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // ===================== PROFILING METHODS =====================
  
  // Save profiling data (questionnaire responses)
  Future<void> saveProfilingData({
    required String name,
    required String category,
    required String usageLocation,
    required bool handSensitivity,
    required String vibrationIntensity,
    required bool voiceAlertEnabled,
    required String language,
    required String volume,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception("User not logged in");
      }

      await _database.child('profiling').child(userId).set({
        'name': name,
        'category': category,
        'usageLocation': usageLocation,
        'handSensitivity': handSensitivity,
        'vibrationIntensity': vibrationIntensity,
        'voiceAlertEnabled': voiceAlertEnabled,
        'language': language,
        'volume': volume,
        'questionnaireCompleted': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception("Failed to save profiling data: $e");
    }
  }

  // Get profiling data
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
  }) async {
    try {
      final data = {
        'motorEnabled': motorEnabled,
        'ultrasonicEnabled': ultrasonicEnabled,
        'audioEnabled': audioEnabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
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
}

