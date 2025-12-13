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

    // If hand sensitivity is Yes, end here
    if (_handSensitivity == true) {
      await _saveToFirebase();
      return;
    }

    if (_vibrationIntensity == null) {
      _showError("Please select vibration intensity preference");
      return;
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
        vibrationIntensity: _vibrationIntensity ?? 'medium',
        voiceAlertEnabled: _voiceAlertEnabled ?? false,
        language: _language ?? 'none',
        volume: _volume ?? 'medium',
      );

      // Save hardware control settings for ESP32
      await _firebaseService.saveHardwareControl(
        motorEnabled: _handSensitivity == false, // Enable motor only if no hand sensitivity
        ultrasonicEnabled: true, // Always enabled
        audioEnabled: _voiceAlertEnabled == true, // Enable only if voice alert is Yes
        language: _language ?? 'none',
        usageLocation: _usageLocation!,
        vibrationIntensity: _vibrationIntensity ?? 'medium',
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
          'Select Your Category',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'Elderly',
          'elderly',
          _category,
          (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'Blind',
          'blind',
          _category,
          (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'High-Risk',
          'high-risk',
          _category,
          (value) => setState(() => _category = value),
        ),
      ],
    );
  }

  Widget _buildUsageLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Where do you often use the cane?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'Indoors',
          'indoors',
          _usageLocation,
          (value) => setState(() => _usageLocation = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'Outdoors',
          'outdoors',
          _usageLocation,
          (value) => setState(() => _usageLocation = value),
        ),
      ],
    );
  }

  Widget _buildHandSensitivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Do you have any sensitivity in your hands that would make vibration uncomfortable?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'Yes',
          'yes',
          _handSensitivity == true ? 'yes' : (_handSensitivity == false ? 'no' : null),
          (value) {
            setState(() => _handSensitivity = value == 'yes');
            // If Yes is selected, automatically save and end questionnaire
            if (value == 'yes') {
              Future.delayed(const Duration(milliseconds: 300), () {
                _saveProfilingData();
              });
            }
          },
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'No',
          'no',
          _handSensitivity == true ? 'yes' : (_handSensitivity == false ? 'no' : null),
          (value) => setState(() => _handSensitivity = value == 'yes'),
        ),
      ],
    );
  }

  Widget _buildVibrationIntensity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vibration Intensity Preference',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'Low',
          'low',
          _vibrationIntensity,
          (value) => setState(() => _vibrationIntensity = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'Medium',
          'medium',
          _vibrationIntensity,
          (value) => setState(() => _vibrationIntensity = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'High',
          'high',
          _vibrationIntensity,
          (value) => setState(() => _vibrationIntensity = value),
        ),
      ],
    );
  }

  Widget _buildVoiceAlertPreference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Do you prefer a voice alert?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'Yes',
          'yes',
          _voiceAlertEnabled == true ? 'yes' : (_voiceAlertEnabled == false ? 'no' : null),
          (value) => setState(() => _voiceAlertEnabled = value == 'yes'),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'No',
          'no',
          _voiceAlertEnabled == true ? 'yes' : (_voiceAlertEnabled == false ? 'no' : null),
          (value) {
            setState(() => _voiceAlertEnabled = value == 'yes');
            // If No is selected, automatically save and end questionnaire
            if (value == 'no') {
              Future.delayed(const Duration(milliseconds: 300), () {
                _saveProfilingData();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Preferred Language for Voice Alert',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'English',
          'english',
          _language,
          (value) => setState(() => _language = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'Filipino',
          'filipino',
          _language,
          (value) => setState(() => _language = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'None',
          'none',
          _language,
          (value) => setState(() => _language = value),
        ),
      ],
    );
  }

  Widget _buildVolumeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Voice Alert Volume Preference',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRadioOption(
          'Low',
          'low',
          _volume,
          (value) => setState(() => _volume = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'Medium',
          'medium',
          _volume,
          (value) => setState(() => _volume = value),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          'High',
          'high',
          _volume,
          (value) => setState(() => _volume = value),
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
        appBar: AppBar(title: const Text('Profiling')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Questionnaire Completed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Your preferences have been saved.'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _questionnaireCompleted = false;
                    _currentStep = 0;
                  });
                },
                child: const Text('Edit Preferences'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Profiling - ${_getStepTitle()}'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name field (only on first step)
              if (_currentStep == 0) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],
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
