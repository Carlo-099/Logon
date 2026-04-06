import 'package:flutter/material.dart';
import 'package:logon/services/firebase_service.dart';

class ProfilingPage extends StatefulWidget {
  const ProfilingPage({super.key});

  @override
  State<ProfilingPage> createState() => _ProfilingPageState();
}

class _ProfilingPageState extends State<ProfilingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _firebaseService = FirebaseService();

  // Questionnaire state
  String? _category; // 'elderly', 'high-risk'
  
  // Elderly category specific questions
  String? _balanceStability; // 'oo_madalas', 'paminsan_minsan', 'hindi'
  String? _obstacleCollision; // 'madalas', 'paminsan_minsan', 'bihira'
  bool? _indoorDifficulty; // true = Oo, false = Hindi
  bool? _voicePreference; // true = Oo, false = Hindi
  bool? _vibrationNeed; // true = Oo, false = Hindi
  bool? _walkingFatigue; // true = Oo, false = Hindi
  
  // High-risk category - New H1-H6 questions
  bool? _headLevelObstacle; // H1: true = Oo, false = Hindi
  String? _preferredWarningType; // H2: 'voice_lamang', 'vibration_lamang', 'pareho'
  bool? _continuousAssistance; // H3: true = Oo, false = Hindi
  bool? _unevenTerrain; // H4: true = Oo, false = Hindi
  bool? _terrainVoiceWarning; // H5: true = Oo, false = Hindi
  bool? _terrainVibrationAlert; // H6: true = Oo, false = Hindi
  
  // Common fields for both categories
  String? _language; // 'english', 'tagalog' (no 'none' option)
  String? _volume; // 'low', 'medium', 'high'

  double _currentStep = 0; // Changed to double to support language selection step (4.5)
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _questionnaireCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadProfilingData();
  }

  Future<void> _loadProfilingData() async {
    try {
      final data = await _firebaseService.getProfilingData()
          .timeout(const Duration(seconds: 10));
      
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _category = data['category'];
          
          // Load elderly category data
          if (data['category'] == 'elderly') {
            _balanceStability = data['balanceStability'];
            _obstacleCollision = data['obstacleCollision'];
            _indoorDifficulty = data['indoorDifficulty'];
            _voicePreference = data['voicePreference'];
            _vibrationNeed = data['vibrationNeed'];
            _walkingFatigue = data['walkingFatigue'];
          }
          
          // Load high-risk category data (H1-H6)
          if (data['category'] == 'high-risk') {
            _headLevelObstacle = data['headLevelObstacle'];
            _preferredWarningType = data['preferredWarningType'];
            _continuousAssistance = data['continuousAssistance'];
            _unevenTerrain = data['unevenTerrain'];
            _terrainVoiceWarning = data['terrainVoiceWarning'];
            _terrainVibrationAlert = data['terrainVibrationAlert'];
          }
          
          // Common fields
          _language = data['language'];
          _volume = data['volume'];
          _questionnaireCompleted = data['questionnaireCompleted'] ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Note: Could not load existing data. Error: $e"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  // Calculate cane behaviors from elderly answers
  Map<String, dynamic> _calculateElderlyBehaviors() {
    // Default values
    double sensorRange = 50.0;
    String scanningMode = 'event-based';
    String vibrationMode = 'soft_pulse';
    bool voiceEnabled = false;
    int alertCooldown = 3;
    bool indoorMode = false;
    String language = 'tagalog'; // Default, can be changed in settings
    
    // E1: Balance and Stability (base settings)
    if (_balanceStability == 'oo_madalas') {
      sensorRange = 100.0;
      scanningMode = 'continuous';
      vibrationMode = 'strong_repeated';
      voiceEnabled = true;
    } else if (_balanceStability == 'paminsan_minsan') {
      sensorRange = 70.0;
      scanningMode = 'semi-continuous';
      vibrationMode = 'normal_pulse';
      voiceEnabled = true;
    } else if (_balanceStability == 'hindi') {
      sensorRange = 50.0;
      scanningMode = 'event-based';
      vibrationMode = 'soft_pulse';
      voiceEnabled = false;
    }
    
    // E2: Obstacle Collision Experience (can override range and cooldown)
    if (_obstacleCollision == 'madalas') {
      sensorRange = 100.0; // Use maximum range
      alertCooldown = 1; // 1 second cooldown
      voiceEnabled = true; // Enable voice if not already
    } else if (_obstacleCollision == 'paminsan_minsan') {
      sensorRange = sensorRange > 70.0 ? sensorRange : 70.0; // Use higher of E1 or 70
      alertCooldown = 2; // 2 seconds cooldown
      voiceEnabled = true; // Enable voice if not already
    } else if (_obstacleCollision == 'bihira') {
      sensorRange = sensorRange > 50.0 ? sensorRange : 50.0; // Use higher of E1 or 50
      alertCooldown = 3; // 3 seconds cooldown
      // Don't disable voice if E1 already enabled it
    }
    
    // E3: Indoor Movement Difficulty
    if (_indoorDifficulty == true) {
      indoorMode = true;
      voiceEnabled = true; // Enable voice for indoor mode
    }
    
    // E4: Voice Alert Preference (final say on voice)
    if (_voicePreference == true) {
      voiceEnabled = true;
    } else {
      voiceEnabled = false; // If user says no, disable voice regardless of other answers
    }
    
    // E5: Vibration Feedback Need (final say on vibration)
    bool vibrationEnabled = _vibrationNeed == true;
    
    // E7: Walking Fatigue (affects timing)
    int alertRepetition = _walkingFatigue == true ? 1 : 2; // LOW = 1, Standard = 2
    int voiceDelay = _walkingFatigue == true ? 3000 : 1000; // Longer interval = 3s, Standard = 1s
    
    return {
      'sensorRange': sensorRange,
      'scanningMode': scanningMode,
      'vibrationMode': vibrationMode,
      'vibrationEnabled': vibrationEnabled,
      'voiceEnabled': voiceEnabled,
      'alertCooldown': alertCooldown,
      'indoorMode': indoorMode,
      'language': language,
      'alertRepetition': alertRepetition,
      'voiceDelay': voiceDelay,
    };
  }

  Future<void> _saveProfilingData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate required fields based on category
    if (_category == null) {
      _showError("Please select a category");
      return;
    }

    // Elderly category validation
    if (_category == 'elderly') {
      if (_balanceStability == null) {
        _showError("Please answer the balance and stability question");
        return;
      }
      if (_obstacleCollision == null) {
        _showError("Please answer the obstacle collision question");
        return;
      }
      if (_indoorDifficulty == null) {
        _showError("Please answer the indoor movement question");
        return;
      }
      if (_voicePreference == null) {
        _showError("Please answer the voice preference question");
        return;
      }
      if (_vibrationNeed == null) {
        _showError("Please answer the vibration need question");
        return;
      }
      if (_walkingFatigue == null) {
        _showError("Please answer the walking fatigue question");
        return;
      }
      await _saveToFirebase();
      return;
    }

    // High-risk category validation (H1-H6)
    if (_headLevelObstacle == null) {
      _showError("Please answer the head-level obstacle question");
      return;
    }

    // If H1 is "Oo", validate H2 and H3
    if (_headLevelObstacle == true) {
      if (_preferredWarningType == null) {
        _showError("Please select preferred warning type");
        return;
      }
      if (_continuousAssistance == null) {
        _showError("Please answer the continuous assistance question");
        return;
      }
      // After H3, save data
      await _saveToFirebase();
      return;
    }

    // If H1 is "Hindi", validate H4, H5, H6
    if (_headLevelObstacle == false) {
      if (_unevenTerrain == null) {
        _showError("Please answer the uneven terrain question");
        return;
      }
      if (_terrainVoiceWarning == null) {
        _showError("Please answer the terrain voice warning question");
        return;
      }
      if (_terrainVibrationAlert == null) {
        _showError("Please answer the terrain vibration alert question");
        return;
      }
      // After H6, save data
      await _saveToFirebase();
      return;
    }
  }

  Future<void> _saveToFirebase() async {
    // Check if user already has profiling data
    final existingData = await _firebaseService.getProfilingData();
    bool hasExistingProfiling = existingData != null && existingData['questionnaireCompleted'] == true;
    
    // If user has existing profiling, show confirmation dialog
    if (hasExistingProfiling) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Replace Existing Profiling?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'You already have a saved profiling. Do you want to delete the old profiling and save this new one?\n\nNote: Only the latest profiling will be used by the cane.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Replace
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Delete Old & Save New',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      
      // If user cancelled, don't save
      if (shouldReplace != true) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profiling save cancelled. Old data preserved.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // User confirmed - delete old profiling first
      try {
        await _firebaseService.deleteProfilingData();
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting old profiling: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_category == 'elderly') {
        // Calculate cane behaviors from elderly answers
        final behaviors = _calculateElderlyBehaviors();
        
        // Save elderly profiling data
      await _firebaseService.saveProfilingData(
        name: _nameController.text.trim(),
          category: 'elderly',
          balanceStability: _balanceStability,
          obstacleCollision: _obstacleCollision,
          indoorDifficulty: _indoorDifficulty,
          voicePreference: _voicePreference,
          vibrationNeed: _vibrationNeed,
          walkingFatigue: _walkingFatigue,
          behaviors: behaviors,
        );

        // Save hardware control for ESP32 with elderly behaviors
      await _firebaseService.saveHardwareControl(
          motorEnabled: behaviors['vibrationEnabled'] as bool,
          ultrasonicEnabled: true,
          audioEnabled: behaviors['voiceEnabled'] as bool,
          language: behaviors['language'] as String,
          usageLocation: behaviors['indoorMode'] as bool ? 'indoors' : 'outdoors',
          vibrationIntensity: _mapVibrationModeToIntensity(behaviors['vibrationMode'] as String),
          volume: 'medium', // Default for elderly
          // Elderly specific behaviors
          sensorRange: behaviors['sensorRange'] as double,
          scanningMode: behaviors['scanningMode'] as String,
          vibrationMode: behaviors['vibrationMode'] as String,
          alertCooldown: behaviors['alertCooldown'] as int,
          indoorMode: behaviors['indoorMode'] as bool,
          alertRepetition: behaviors['alertRepetition'] as int,
          voiceDelay: behaviors['voiceDelay'] as int,
        );
      } else if (_category == 'high-risk') {
        // Calculate cane behaviors from high-risk answers
        final behaviors = _calculateHighRiskBehaviors();
        
        // Save high-risk profiling data
        await _firebaseService.saveProfilingData(
          name: _nameController.text.trim(),
          category: 'high-risk',
          headLevelObstacle: _headLevelObstacle,
          preferredWarningType: _preferredWarningType,
          continuousAssistance: _continuousAssistance,
          unevenTerrain: _unevenTerrain,
          terrainVoiceWarning: _terrainVoiceWarning,
          terrainVibrationAlert: _terrainVibrationAlert,
          language: _language ?? 'tagalog',
          volume: _volume ?? 'medium',
        );

        // Save hardware control for ESP32 with high-risk behaviors
        await _firebaseService.saveHardwareControl(
          motorEnabled: behaviors['vibrationEnabled'] as bool,
          ultrasonicEnabled: true,
          audioEnabled: behaviors['voiceEnabled'] as bool,
          language: behaviors['language'] as String,
          usageLocation: 'outdoors', // Default for high-risk
          vibrationIntensity: behaviors['vibrationIntensity'] as String,
          volume: _volume ?? 'medium',
          // High-risk specific behaviors
          sensorAngle: behaviors['sensorAngle'] as String?,
          detectionLevel: behaviors['detectionLevel'] as String?,
          scanningMode: behaviors['scanningMode'] as String?,
          voiceRepeat: behaviors['voiceRepeat'] as bool?,
          depthDetection: behaviors['depthDetection'] as bool?,
          terrainVoiceWarning: behaviors['terrainVoiceWarning'] as bool?, // H5: Terrain voice warning
        );
      }

      setState(() {
        _questionnaireCompleted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profiling data saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Calculate cane behaviors from high-risk answers
  Map<String, dynamic> _calculateHighRiskBehaviors() {
    // Default values
    String sensorAngle = 'forward';
    String? detectionLevel;
    bool voiceEnabled = false;
    bool vibrationEnabled = false;
    String vibrationIntensity = 'medium';
    String scanningMode = 'event-based';
    bool voiceRepeat = false;
    bool depthDetection = false;
    String language = _language ?? 'tagalog';
    
    // H1: Head-Level Obstacle Risk
    if (_headLevelObstacle == true) {
      // Sensor angle: UPWARD, Detection level: Head/chest
      sensorAngle = 'upward';
      detectionLevel = 'head_chest';
      
      // Voice: "002 or 005" (depends on language)
      voiceEnabled = true;
      
      // Vibration: Strong pulse
      vibrationEnabled = true;
      vibrationIntensity = 'high';
      
      // H2: Preferred Warning Type
      if (_preferredWarningType == 'voice_lamang') {
        voiceEnabled = true;
        vibrationEnabled = false;
      } else if (_preferredWarningType == 'vibration_lamang') {
        voiceEnabled = false;
        vibrationEnabled = true;
      } else if (_preferredWarningType == 'pareho') {
        voiceEnabled = true;
        vibrationEnabled = true;
      }
      
      // H3: Continuous Assistance
      if (_continuousAssistance == true) {
        scanningMode = 'continuous';
        voiceRepeat = true;
      } else {
        scanningMode = 'event-based';
        voiceRepeat = false;
      }
    } else {
      // H1 is "Hindi" - Standard forward scanning
      sensorAngle = 'forward';
      
      // H4: Uneven or Deep Terrain Experience
      if (_unevenTerrain == true) {
        // Sensor angle: DOWNWARD, Depth detection: ON
        sensorAngle = 'downward';
        depthDetection = true;
      } else {
        // Standard forward scanning
        sensorAngle = 'forward';
        depthDetection = false;
      }
      
      // H5: Terrain Voice Warning
      if (_terrainVoiceWarning == true) {
        voiceEnabled = true;
      } else {
        voiceEnabled = false;
      }
      
      // H6: Vibration Alert for Terrain
      if (_terrainVibrationAlert == true) {
        vibrationEnabled = true;
        vibrationIntensity = 'medium';
      } else {
        vibrationEnabled = false;
      }
    }
    
    return {
      'sensorAngle': sensorAngle,
      'detectionLevel': detectionLevel,
      'terrainVoiceWarning': _terrainVoiceWarning, // H5: Terrain voice warning
      'voiceEnabled': voiceEnabled,
      'vibrationEnabled': vibrationEnabled,
      'vibrationIntensity': vibrationIntensity,
      'scanningMode': scanningMode,
      'voiceRepeat': voiceRepeat,
      'depthDetection': depthDetection,
      'terrainVoiceWarning': _terrainVoiceWarning, // H5: Terrain voice warning
      'language': language,
    };
  }

  // Helper to map vibration mode to intensity
  String _mapVibrationModeToIntensity(String mode) {
    switch (mode) {
      case 'strong_repeated':
        return 'high';
      case 'normal_pulse':
        return 'medium';
      case 'soft_pulse':
        return 'low';
      default:
        return 'medium';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && _category == null) {
      _showError("Please select a category");
      return;
    }

    // Elderly category validation
    if (_category == 'elderly') {
      if (_currentStep == 1 && _balanceStability == null) {
        _showError("Please answer the balance and stability question");
        return;
      }
      if (_currentStep == 2 && _obstacleCollision == null) {
        _showError("Please answer the obstacle collision question");
        return;
      }
      if (_currentStep == 3 && _indoorDifficulty == null) {
        _showError("Please answer the indoor movement question");
        return;
      }
      if (_currentStep == 4 && _voicePreference == null) {
        _showError("Please answer the voice preference question");
        return;
      }
      if (_currentStep == 5 && _vibrationNeed == null) {
        _showError("Please answer the vibration need question");
        return;
      }
      // Step 6 (walking fatigue) auto-saves, so no validation needed here
    } else if (_category == 'high-risk') {
      // High-risk category validation (H1-H6)
      if (_currentStep == 1 && _headLevelObstacle == null) {
        _showError("Please answer the head-level obstacle question");
        return;
      }
      
      // If H1 is "Oo", validate H2 and H3
      if (_headLevelObstacle == true) {
        if (_currentStep == 2 && _preferredWarningType == null) {
          _showError("Please select preferred warning type");
          return;
        }
        if (_currentStep == 3 && _continuousAssistance == null) {
          _showError("Please answer the continuous assistance question");
          return;
        }
        // H3 auto-saves, so no need to increment step
        if (_currentStep == 3) {
          return; // Will be saved by button click
        }
      }
      
      // If H1 is "Hindi", validate H4, H5, H6
      if (_headLevelObstacle == false) {
        if (_currentStep == 4 && _unevenTerrain == null) {
          _showError("Please answer the uneven terrain question");
          return;
        }
        if (_currentStep == 5 && _terrainVoiceWarning == null) {
          _showError("Please answer the terrain voice warning question");
          return;
        }
        if (_currentStep == 6 && _terrainVibrationAlert == null) {
          _showError("Please answer the terrain vibration alert question");
          return;
        }
        // H6 auto-saves, so no need to increment step
        if (_currentStep == 6) {
          return; // Will be saved by button click
        }
      }
    }

    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        // Handle conditional flow for high-risk category
        if (_category == 'high-risk') {
          // If going back from H4 and H1 was "Oo", skip to H3
          if (_currentStep == 4 && _headLevelObstacle == true) {
            _currentStep = 3;
          } else {
            _currentStep--;
          }
        } else {
          _currentStep--;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Category',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Elderly Category Card
        InkWell(
          onTap: () {
            setState(() => _category = 'elderly');
            _nextStep();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _category == 'elderly' ? Colors.blue : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Image.asset(
                    'assets/images/eldery.jpg',
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 50),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Elderly',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // High-Risk Category Card
        InkWell(
          onTap: () {
            setState(() => _category = 'high-risk');
            _nextStep();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _category == 'high-risk' ? Colors.blue : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Image.asset(
                    'assets/images/highkers.png',
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 50),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'High-risk',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================== ELDERLY CATEGORY QUESTIONS =====================
  
  // E1: Balance and Stability
  // Old widget builders removed - not used anymore (replaced with H1-H6 for high-risk)
  
  // ===================== ELDERLY CATEGORY QUESTIONS =====================
  
  // E1: Balance and Stability
  Widget _buildE1BalanceStability() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nahihirapan ka bang panatilihin ang balanse habang naglalakad?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo, madalas Button
        InkWell(
          onTap: () {
            setState(() => _balanceStability = 'oo_madalas');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _balanceStability == 'oo_madalas'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _balanceStability == 'oo_madalas'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo, madalas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Paminsan-minsan Button
        InkWell(
          onTap: () {
            setState(() => _balanceStability = 'paminsan_minsan');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _balanceStability == 'paminsan_minsan'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _balanceStability == 'paminsan_minsan'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Paminsan-minsan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _balanceStability = 'hindi');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _balanceStability == 'hindi'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _balanceStability == 'hindi'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // E2: Obstacle Collision Experience
  Widget _buildE2ObstacleCollision() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nakararanas ka ba ng banggaan sa mga bagay habang naglalakad?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Madalas Button
        InkWell(
          onTap: () {
            setState(() => _obstacleCollision = 'madalas');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _obstacleCollision == 'madalas'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _obstacleCollision == 'madalas'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Madalas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Paminsan-minsan Button
        InkWell(
          onTap: () {
            setState(() => _obstacleCollision = 'paminsan_minsan');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _obstacleCollision == 'paminsan_minsan'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _obstacleCollision == 'paminsan_minsan'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Paminsan-minsan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Bihira Button
        InkWell(
          onTap: () {
            setState(() => _obstacleCollision = 'bihira');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _obstacleCollision == 'bihira'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _obstacleCollision == 'bihira'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Bihira',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // E3: Indoor Movement Difficulty
  Widget _buildE3IndoorDifficulty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nahihirapan ka bang gumalaw sa loob ng bahay o gusali?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _indoorDifficulty = true);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _indoorDifficulty == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _indoorDifficulty == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _indoorDifficulty = false);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _indoorDifficulty == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _indoorDifficulty == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // E4: Voice Alert Preference
  Widget _buildE4VoicePreference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mas nakakatulong ba sa iyo ang nagsasalitang babala?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() {
              _voicePreference = true;
              // Don't increment step yet - will show language selection next
            });
            // Go to language selection step (inserted dynamically)
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _currentStep = 4.5; // Use 4.5 as language selection step
              });
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _voicePreference == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _voicePreference == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() {
              _voicePreference = false;
              // Skip language selection, go directly to E5
            });
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _voicePreference == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _voicePreference == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Elderly Language Selection (after E4 if voice is enabled)
  Widget _buildElderlyLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ano ang iyong preferred language?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Tagalog Button
        InkWell(
          onTap: () {
            setState(() => _language = 'tagalog');
            // Go to E5 after language selection
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 5);
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _language == 'tagalog'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _language == 'tagalog'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Tagalog',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // English Button
        InkWell(
          onTap: () {
            setState(() => _language = 'english');
            // Go to E5 after language selection
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 5);
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _language == 'english'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _language == 'english'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'English',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // E5: Vibration Feedback Need
  Widget _buildE5VibrationNeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mas ramdam mo ba ang babala kapag may vibration?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _vibrationNeed = true);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _vibrationNeed == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _vibrationNeed == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _vibrationNeed = false);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _vibrationNeed == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _vibrationNeed == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // E7: Walking Fatigue
  Widget _buildE7WalkingFatigue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Madali ka bang mapagod kapag naglalakad?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _walkingFatigue = true);
            // Don't auto-save, let user click Submit button
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _walkingFatigue == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _walkingFatigue == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _walkingFatigue = false);
            // Don't auto-save, let user click Submit button
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _walkingFatigue == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _walkingFatigue == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String title, String value, String? groupValue, Function(String) onChanged) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: RadioListTile<String>(
        title: Text(title),
          value: value,
        groupValue: groupValue,
        onChanged: (val) => onChanged(val!),
      ),
    );
  }

  Widget _buildCurrentStep() {
    // Step 0: Category Selection (always)
    if (_currentStep == 0) {
      return _buildCategorySelection();
    }
    
    // Elderly category flow (steps 1-6)
    if (_category == 'elderly') {
      if (_currentStep == 4.5) {
        // Language selection step (after E4 if voice is enabled)
        return _buildElderlyLanguageSelection();
      }
      switch (_currentStep.toInt()) {
        case 1:
          return _buildE1BalanceStability();
        case 2:
          return _buildE2ObstacleCollision();
        case 3:
          return _buildE3IndoorDifficulty();
        case 4:
          return _buildE4VoicePreference();
        case 5:
          return _buildE5VibrationNeed();
        case 6:
          return _buildE7WalkingFatigue();
        default:
          return const SizedBox();
      }
    }
    
    // High-risk category flow (H1-H6)
    if (_category == 'high-risk') {
      if (_currentStep == 2.5) {
        // Language selection step (after H2 if voice is selected)
        return _buildHighRiskLanguageSelection();
      }
      switch (_currentStep.toInt()) {
        case 1:
          return _buildH1HeadLevelObstacle();
        case 2:
          // H2 only shows if H1 is "Oo"
          if (_headLevelObstacle == true) {
            return _buildH2PreferredWarningType();
          } else {
            // Skip to H4 if H1 is "Hindi"
            return _buildH4UnevenTerrain();
          }
        case 3:
          // H3 only shows if H1 is "Oo"
          if (_headLevelObstacle == true) {
            return _buildH3ContinuousAssistance();
          } else {
            // Should not reach here if H1 is "Hindi"
            return _buildH4UnevenTerrain();
          }
        case 4:
          // H4 shows if H1 is "Hindi" (or as fallback)
          if (_headLevelObstacle == false) {
            return _buildH4UnevenTerrain();
          } else {
            // Should not reach here if H1 is "Oo"
            return const SizedBox();
          }
        case 5:
          // H5 only shows if H1 is "Hindi"
          if (_headLevelObstacle == false) {
            return _buildH5TerrainVoiceWarning();
          } else {
            return const SizedBox();
          }
        case 6:
          // H6 only shows if H1 is "Hindi"
          if (_headLevelObstacle == false) {
            return _buildH6TerrainVibrationAlert();
          } else {
            return const SizedBox();
          }
        default:
          return const SizedBox();
      }
    }
    
    return const SizedBox();
  }

  // High-Risk Language Selection (after H2 if voice is selected)
  Widget _buildHighRiskLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ano ang iyong preferred language?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Tagalog Button
        InkWell(
          onTap: () {
            setState(() => _language = 'tagalog');
            // Go to H3 after language selection
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 3);
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _language == 'tagalog'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _language == 'tagalog'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Tagalog',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // English Button
        InkWell(
          onTap: () {
            setState(() => _language = 'english');
            // Go to H3 after language selection
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 3);
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _language == 'english'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _language == 'english'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'English',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== High-Risk Category Widget Builders (H1-H6) =====================
  
  // H1: Head-Level Obstacle Risk
  Widget _buildH1HeadLevelObstacle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nakararanas ka ba ng banggaan sa mga bagay na nasa antas ng ulo o dibdib?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _headLevelObstacle = true);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _headLevelObstacle == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _headLevelObstacle == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _headLevelObstacle = false);
            // Skip H2 and H3, go directly to H4
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _currentStep = 4; // H4
              });
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _headLevelObstacle == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _headLevelObstacle == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // H2: Preferred Warning Type
  Widget _buildH2PreferredWarningType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Alin ang mas epektibong babala para sa iyo?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Voice lamang Button
        InkWell(
          onTap: () {
            setState(() => _preferredWarningType = 'voice_lamang');
            // Show language selection before H3
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 2.5); // Use 2.5 as language selection step
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _preferredWarningType == 'voice_lamang'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _preferredWarningType == 'voice_lamang'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Voice lamang',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Vibration lamang Button
        InkWell(
          onTap: () {
            setState(() => _preferredWarningType = 'vibration_lamang');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _preferredWarningType == 'vibration_lamang'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _preferredWarningType == 'vibration_lamang'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Vibration lamang',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Pareho Button
        InkWell(
          onTap: () {
            setState(() => _preferredWarningType = 'pareho');
            // Show language selection before H3
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _currentStep = 2.5); // Use 2.5 as language selection step
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _preferredWarningType == 'pareho'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _preferredWarningType == 'pareho'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Pareho',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // H3: Continuous Assistance
  Widget _buildH3ContinuousAssistance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kailangan mo ba ng tuloy-tuloy na babala habang naglalakad?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _continuousAssistance = true);
            // After H3, save data (if H1 was Oo)
            _saveProfilingData();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _continuousAssistance == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _continuousAssistance == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _continuousAssistance = false);
            // After H3, save data (if H1 was Oo)
            _saveProfilingData();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _continuousAssistance == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _continuousAssistance == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // H4: Uneven or Deep Terrain Experience
  Widget _buildH4UnevenTerrain() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nakararanas ka ba ng biglaang pagbaba o hukay sa dinaanan?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _unevenTerrain = true);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _unevenTerrain == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _unevenTerrain == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _unevenTerrain = false);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _unevenTerrain == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _unevenTerrain == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // H5: Terrain Voice Warning
  Widget _buildH5TerrainVoiceWarning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Gusto mo bang may voice alert kapag may lalim o panganib?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _terrainVoiceWarning = true);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _terrainVoiceWarning == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _terrainVoiceWarning == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _terrainVoiceWarning = false);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _terrainVoiceWarning == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _terrainVoiceWarning == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // H6: Vibration Alert for Terrain
  Widget _buildH6TerrainVibrationAlert() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mas gusto mo bang may vibration kasabay ng babala sa terrain?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Oo Button
        InkWell(
          onTap: () {
            setState(() => _terrainVibrationAlert = true);
            // After H6, save data (if H1 was Hindi)
            _saveProfilingData();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _terrainVibrationAlert == true
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _terrainVibrationAlert == true
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Oo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hindi Button
        InkWell(
          onTap: () {
            setState(() => _terrainVibrationAlert = false);
            // After H6, save data (if H1 was Hindi)
            _saveProfilingData();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _terrainVibrationAlert == false
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _terrainVibrationAlert == false
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Hindi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    if (_currentStep == 0) {
      return 'Category Selection';
    }
    
    if (_category == 'elderly') {
      switch (_currentStep) {
        case 1:
          return 'Balance and Stability';
        case 2:
          return 'Obstacle Collision';
        case 3:
          return 'Indoor Movement';
        case 4:
          return 'Voice Preference';
        case 5:
          return 'Vibration Need';
        case 6:
          return 'Walking Fatigue';
        default:
          return '';
      }
    } else {
      // High-risk category
      switch (_currentStep) {
        case 1:
          return 'Usage Location';
        case 2:
          return 'Hand Sensitivity';
        case 3:
          return 'Vibration Intensity';
        case 4:
          return 'Voice Alert Preference';
        case 5:
          return 'Language Selection';
        case 6:
          return 'Volume Preference';
        default:
          return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profiling')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questionnaireCompleted) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A), // Dark gray background
        body: SafeArea(
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: Colors.grey[300],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profiling',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    // GABAY TECH Logo
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.accessible_forward,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'GABAY',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'TECH',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Questionnaire Completed!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Large green circle with checkmark
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(
                            color: Colors.green,
                            width: 4,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'your preferences have been saved',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Edit Preferences link
                      InkWell(
                        onTap: () {
                          setState(() {
                            _questionnaireCompleted = false;
                            _currentStep = 0;
                          });
                        },
                        child: const Text(
                          'Edit Preferences',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Custom header for category selection (step 0)
    if (_currentStep == 0) {
    return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A), // Dark gray background
        body: SafeArea(
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: Colors.grey[300],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            if (_currentStep == 0) {
                              // If on first step, go back to homepage
                              Navigator.pop(context);
                            } else {
                              // Otherwise, go to previous step
                              _previousStep();
                            }
                          },
                        ),
              const Text(
                          'Profiling',
                style: TextStyle(
                            fontSize: 28,
                  fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // GABAY TECH Logo
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.accessible_forward,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'GABAY',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'TECH',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Hamburger menu
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            // Menu functionality if needed
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: Form(
        key: _formKey,
        child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                        // Name field
              TextFormField(
                controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                            labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white70),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white70),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            prefixIcon: const Icon(Icons.person, color: Colors.white70),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
                        const SizedBox(height: 40),
                        // Category selection
                        _buildCurrentStep(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Helper method to build custom header
    Widget _buildCustomHeader() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: Colors.grey[300],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    if (_currentStep == 0) {
                      Navigator.pop(context);
                    } else {
                      _previousStep();
                    }
                  },
                ),
              const Text(
                  'Profiling',
                style: TextStyle(
                    fontSize: 28,
                  fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 2),
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.accessible_forward,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
              const Text(
                  'GABAY',
                style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'TECH',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Custom Scaffold for step 1 (Usage Location)
    if (_currentStep == 1) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCurrentStep(),
                        const SizedBox(height: 40),
                        // Previous Button
                        OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Previous',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Custom Scaffold for steps 2-6
    if (_currentStep >= 2 && _currentStep <= 6) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCurrentStep(),
                        const SizedBox(height: 40),
                        // Navigation buttons - Previous and Submit (for step 6) or just Previous (for steps 2-5)
                        if (_currentStep == 6) ...[
                          // Step 6: Previous and Submit buttons side by side
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _previousStep,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6C5CE7),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfilingData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                      )
                    : const Text(
                                          'Submit',
                        style: TextStyle(
                                            fontSize: 16,
                          fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                        ),
                      ),
              ),
            ],
          ),
                        ] else ...[
                          // Steps 2-5: Just Previous button
                          OutlinedButton(
                            onPressed: _previousStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Previous',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }

    return Scaffold(
      appBar: AppBar(
        title: Text('Profiling - ${_getStepTitle()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 0) {
              // If on first step, go back to homepage
              Navigator.pop(context);
            } else {
              // Otherwise, go to previous step
              _previousStep();
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / 7,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${_currentStep + 1} of 7',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Current step content
              _buildCurrentStep(),
              const SizedBox(height: 32),
              // Navigation buttons
              // Hide Next button if:
              // - Hand Sensitivity is Yes (step 2) - will auto-save
              // - Voice Alert is No (step 4) - will auto-save
              // - Currently saving
              Builder(
                builder: (context) {
                  bool shouldHideNext = _isLoading ||
                      (_category == 'high-risk' && _currentStep == 3 && _headLevelObstacle == true && _continuousAssistance != null) ||
                      (_category == 'high-risk' && _currentStep == 6 && _headLevelObstacle == false && _terrainVibrationAlert != null);
                  
                  if (shouldHideNext && _isLoading) {
                    return const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Saving your preferences...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  } else if (!shouldHideNext) {
                    return Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _previousStep,
                              child: const Text('Previous'),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              if (_currentStep == 6) {
                                _saveProfilingData();
                              } else {
                                _nextStep();
                              }
                            },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                                : Text(_currentStep == 6 ? 'Save' : 'Next'),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
