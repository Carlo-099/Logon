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
  String? _category; // 'elderly', 'blind', 'high-risk'
  String? _usageLocation; // 'indoors', 'outdoors'
  bool? _handSensitivity; // true = Yes, false = No
  String? _vibrationIntensity; // 'low', 'medium', 'high'
  bool? _voiceAlertEnabled; // true = Yes, false = No
  String? _language; // 'english', 'filipino', 'none'
  String? _volume; // 'low', 'medium', 'high'

  int _currentStep = 0;
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
          _usageLocation = data['usageLocation'];
          _handSensitivity = data['handSensitivity'];
          _vibrationIntensity = data['vibrationIntensity'];
          _voiceAlertEnabled = data['voiceAlertEnabled'];
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

  Future<void> _saveProfilingData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate required fields based on flow
    if (_category == null) {
      _showError("Please select a category");
      return;
    }

    if (_usageLocation == null) {
      _showError("Please select where you often use the cane");
      return;
    }

    if (_handSensitivity == null) {
      _showError("Please answer the hand sensitivity question");
      return;
    }

    // If hand sensitivity is Yes, skip vibration intensity validation
    // But still need voice alert, language, and volume
    if (_handSensitivity == false) {
      // Only check vibration intensity if hand sensitivity is No
      if (_vibrationIntensity == null) {
        _showError("Please select vibration intensity preference");
        return;
      }
    }

    if (_voiceAlertEnabled == null) {
      _showError("Please answer the voice alert preference question");
      return;
    }

    // If voice alert is No, end here
    if (_voiceAlertEnabled == false) {
      await _saveToFirebase();
      return;
    }

    if (_language == null) {
      _showError("Please select preferred language");
      return;
    }

    if (_volume == null) {
      _showError("Please select voice alert volume preference");
      return;
    }

    await _saveToFirebase();
  }

  Future<void> _saveToFirebase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Save profiling data
      await _firebaseService.saveProfilingData(
        name: _nameController.text.trim(),
        category: _category!,
        usageLocation: _usageLocation!,
        handSensitivity: _handSensitivity ?? false,
        vibrationIntensity: _handSensitivity == true ? 'none' : (_vibrationIntensity ?? 'medium'),
        voiceAlertEnabled: _voiceAlertEnabled ?? false,
        language: _language ?? 'tagalog',
        volume: _volume ?? 'medium',
      );

      // Save hardware control settings for ESP32
      await _firebaseService.saveHardwareControl(
        motorEnabled: _handSensitivity == false, // Enable motor only if no hand sensitivity
        ultrasonicEnabled: true, // Always enabled
        audioEnabled: _voiceAlertEnabled == true, // Enable only if voice alert is Yes
        language: _language ?? 'tagalog',
        usageLocation: _usageLocation!,
        vibrationIntensity: _handSensitivity == true ? 'none' : (_vibrationIntensity ?? 'medium'),
        volume: _volume ?? 'medium',
      );

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
    if (_currentStep == 1 && _usageLocation == null) {
      _showError("Please select where you often use the cane");
      return;
    }
    if (_currentStep == 2 && _handSensitivity == null) {
      _showError("Please answer the hand sensitivity question");
      return;
    }
    // If hand sensitivity is Yes, should have already saved and ended
    if (_currentStep == 2 && _handSensitivity == true) {
      // This should not happen as it auto-saves, but just in case
      _saveProfilingData();
      return;
    }
    if (_currentStep == 3 && _vibrationIntensity == null) {
      _showError("Please select vibration intensity");
      return;
    }
    if (_currentStep == 4 && _voiceAlertEnabled == null) {
      _showError("Please answer the voice alert question");
      return;
    }
    // If voice alert is No, should have already saved and ended
    if (_currentStep == 4 && _voiceAlertEnabled == false) {
      // This should not happen as it auto-saves, but just in case
      _saveProfilingData();
      return;
    }
    if (_currentStep == 5 && _language == null) {
      _showError("Please select preferred language");
      return;
    }
    if (_currentStep == 6 && _volume == null) {
      _showError("Please select volume preference");
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
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
        // Blind Category Card
        InkWell(
          onTap: () {
            setState(() => _category = 'blind');
            _nextStep();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _category == 'blind' ? Colors.blue : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Image.asset(
                    'assets/images/blind.jpg',
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
                    'Blind',
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

  Widget _buildUsageLocation() {
    // Category-specific question wording
    String questionText;
    if (_category == 'blind') {
      questionText = 'Where does the user often use the cane?';
    } else if (_category == 'elderly') {
      questionText = 'Where do you often use the cane?';
    } else {
      // high-risk
      questionText = 'Where do you often use the cane?';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Indoors Button
        InkWell(
          onTap: () {
            setState(() => _usageLocation = 'indoors');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _usageLocation == 'indoors'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _usageLocation == 'indoors'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Indoors',
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
        // Outdoors Button
        InkWell(
          onTap: () {
            setState(() => _usageLocation = 'outdoors');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _usageLocation == 'outdoors'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _usageLocation == 'outdoors'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Outdoors',
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

  Widget _buildHandSensitivity() {
    // Category-specific question wording
    String questionText;
    if (_category == 'blind') {
      questionText = 'Does the user have any sensitivity in their hands that would make vibration uncomfortable?';
    } else if (_category == 'elderly') {
      questionText = 'Do you have any sensitivity in your hands that would make vibration uncomfortable?';
    } else {
      // high-risk
      questionText = 'Do you have any sensitivity in your hands that would make vibration uncomfortable?';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Yes Button
        InkWell(
          onTap: () {
            setState(() => _handSensitivity = true);
            // If Yes is selected, skip vibration intensity and go to voice alert
            // Vibration is not applicable, but voice alert can still be used
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _currentStep = 4; // Go directly to Voice Alert Preference (skip Vibration Intensity)
              });
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF5A4FCF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Yes',
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
        // No Button
        InkWell(
          onTap: () {
            setState(() => _handSensitivity = false);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF5A4FCF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No',
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

  Widget _buildVibrationIntensity() {
    // Category-specific question wording
    String questionText;
    if (_category == 'blind') {
      questionText = 'What is the user\'s preferred vibration intensity?';
    } else if (_category == 'elderly') {
      questionText = 'Vibration Intensity Preference';
    } else {
      // high-risk
      questionText = 'Vibration Intensity Preference';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Low Button
        InkWell(
          onTap: () {
            setState(() => _vibrationIntensity = 'low');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _vibrationIntensity == 'low'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _vibrationIntensity == 'low'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Low',
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
        // Medium Button
        InkWell(
          onTap: () {
            setState(() => _vibrationIntensity = 'medium');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _vibrationIntensity == 'medium'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _vibrationIntensity == 'medium'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Medium',
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
        // High Button
        InkWell(
          onTap: () {
            setState(() => _vibrationIntensity = 'high');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _vibrationIntensity == 'high'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _vibrationIntensity == 'high'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'High',
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

  Widget _buildVoiceAlertPreference() {
    // Category-specific question wording
    String questionText;
    if (_category == 'blind') {
      questionText = 'Does the user prefer voice alert?';
    } else if (_category == 'elderly') {
      questionText = 'Do you prefer voice alert?';
    } else {
      // high-risk
      questionText = 'Do you prefer voice alert?';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Yes Button
        InkWell(
          onTap: () {
            setState(() => _voiceAlertEnabled = true);
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF5A4FCF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Yes',
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
        // No Button
        InkWell(
          onTap: () {
            setState(() => _voiceAlertEnabled = false);
            // If No is selected, automatically save and end questionnaire
            Future.delayed(const Duration(milliseconds: 300), () {
              _saveProfilingData();
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              _saveProfilingData();
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF5A4FCF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No',
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

  Widget _buildLanguageSelection() {
    // Category-specific question wording
    String questionText;
    if (_category == 'blind') {
      questionText = 'What is the user\'s preferred language for voice alert?';
    } else if (_category == 'elderly') {
      questionText = 'Preferred Language for Voice Alert';
    } else {
      // high-risk
      questionText = 'Preferred Language for Voice Alert';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // English Button
        InkWell(
          onTap: () {
            setState(() => _language = 'english');
            _nextStep();
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
        const SizedBox(height: 24),
        // Filipino Button
        InkWell(
          onTap: () {
            setState(() => _language = 'filipino');
            _nextStep();
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _language == 'filipino'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _language == 'filipino'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Filipino',
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

  Widget _buildVolumeSelection() {
    // Category-specific question wording
    String questionText;
    if (_category == 'blind') {
      questionText = 'What is the user\'s preferred voice alert volume?';
    } else if (_category == 'elderly') {
      questionText = 'Voice Alert Volume Preference';
    } else {
      // high-risk
      questionText = 'Voice Alert Volume Preference';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Low Button
        InkWell(
          onTap: () {
            setState(() => _volume = 'low');
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _volume == 'low'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _volume == 'low'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Low',
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
        // Medium Button
        InkWell(
          onTap: () {
            setState(() => _volume = 'medium');
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _volume == 'medium'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _volume == 'medium'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'Medium',
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
        // High Button
        InkWell(
          onTap: () {
            setState(() => _volume = 'high');
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _volume == 'high'
                    ? [const Color(0xFF6C5CE7), const Color(0xFF5A4FCF)]
                    : [const Color(0xFF6C5CE7).withOpacity(0.7), const Color(0xFF5A4FCF).withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: _volume == 'high'
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: const Center(
              child: Text(
                'High',
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
    switch (_currentStep) {
      case 0:
        return _buildCategorySelection();
      case 1:
        return _buildUsageLocation();
      case 2:
        return _buildHandSensitivity();
      case 3:
        return _buildVibrationIntensity();
      case 4:
        return _buildVoiceAlertPreference();
      case 5:
        return _buildLanguageSelection();
      case 6:
        return _buildVolumeSelection();
      default:
        return const SizedBox();
    }
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Category Selection';
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
                  labelText: _category == 'blind' ? 'User\'s Name' : 'Name',
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
                    if (_category == 'blind') {
                      return 'Please enter the user\'s name';
                    } else {
                      return 'Please enter your name';
                    }
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
                      (_currentStep == 2 && _handSensitivity == true) ||
                      (_currentStep == 4 && _voiceAlertEnabled == false);
                  
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
