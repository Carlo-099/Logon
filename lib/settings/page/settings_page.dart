import 'package:flutter/material.dart';
import 'package:logon/services/firebase_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _firebaseService = FirebaseService();
  Map<String, dynamic>? _profilingData;
  bool _isLoading = false;
  bool _isSaving = false;

  // Settings state
  String _selectedLanguage = 'tagalog';
  String _selectedTextSize = 'medium'; // medium or large
  String _vibrationIntensity = 'medium'; // low, medium, high
  String _volume = 'medium'; // low, medium, high
  String _usageLocation = 'outdoors'; // indoors or outdoors
  bool _audioEnabled = false; // audio/voice alert enabled
  bool _isHoveringSave = false; // For hover effect on save button
  bool _isHoveringLanguage = false; // For hover effect on language dropdown
  bool _isHoveringTextSizeMedium = false; // For hover effect on text size medium
  bool _isHoveringTextSizeLarge = false; // For hover effect on text size large

  @override
  void initState() {
    super.initState();
    _loadProfilingData();
  }

  Future<void> _loadProfilingData() async {
    setState(() => _isLoading = true);
    try {
      // Load profiling data
      final data = await _firebaseService.getProfilingData();
      if (data != null) {
        setState(() {
          _profilingData = data;
          _selectedLanguage = data['language'] ?? 'tagalog';
          _vibrationIntensity = data['vibrationIntensity'] ?? 'medium';
          _volume = data['volume'] ?? 'medium';
          _usageLocation = data['usageLocation'] ?? 'outdoors';
          _audioEnabled = data['voiceAlertEnabled'] ?? false;
        });
      }
      
      // Load text size preference
      final textSize = await _firebaseService.getTextSize();
      if (textSize != null) {
        setState(() => _selectedTextSize = textSize);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_profilingData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No profiling data found. Please complete profiling first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Get current profiling data to preserve values not changed in settings
      final handSensitivity = _profilingData!['handSensitivity'] ?? false;
      final category = _profilingData!['category'] ?? 'elderly';
      final name = _profilingData!['name'] ?? '';

      // Calculate hardware control flags based on profiling logic
      // Motor is disabled if user has hand sensitivity
      final motorEnabled = !handSensitivity;
      // Ultrasonic is always enabled
      const ultrasonicEnabled = true;
      // Audio is enabled based on user's setting
      final audioEnabled = _audioEnabled;

      // Update profiling data with new settings
      await _firebaseService.saveProfilingData(
        name: name,
        category: category,
        usageLocation: _usageLocation,
        handSensitivity: handSensitivity,
        vibrationIntensity: _vibrationIntensity,
        voiceAlertEnabled: _audioEnabled, // Use the toggle value
        language: _selectedLanguage,
        volume: _volume,
      );

      // Save to hardware_control for ESP32 (this is what ESP32 reads)
      await _firebaseService.saveHardwareControl(
        motorEnabled: motorEnabled,
        ultrasonicEnabled: ultrasonicEnabled,
        audioEnabled: audioEnabled,
        language: _selectedLanguage,
        usageLocation: _usageLocation,
        vibrationIntensity: _vibrationIntensity,
        volume: _volume,
      );

      // Save text size to user settings (new field)
      final userId = _firebaseService.getCurrentUserId();
      if (userId != null) {
        await _firebaseService.saveTextSize(_selectedTextSize);
      }

      // Reload profiling data to reflect changes
      await _loadProfilingData();

      if (mounted) {
        // Show detailed success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Settings Saved Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Language: ${_selectedLanguage == 'english' ? 'English' : 'Tagalog'}\n'
                  'Vibration: ${_vibrationIntensity.toUpperCase()}\n'
                  'Volume: ${_volume.toUpperCase()}\n'
                  'Location: ${_usageLocation == 'indoors' ? 'Indoors' : 'Outdoors'}\n'
                  'Audio: ${_audioEnabled ? 'Enabled' : 'Disabled'}\n\n'
                  '✅ Updated in Firebase\n'
                  '✅ ESP32 will read new settings',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.grey[300],
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Spacer(),
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
    );
  }

  Widget _buildLanguagePreference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Language Preference',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        // Language dropdown button with hover effect
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringLanguage = true),
          onExit: (_) => setState(() => _isHoveringLanguage = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(_isHoveringLanguage ? 1.02 : 1.0),
            child: InkWell(
              onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF2A2A2A),
              builder: (context) => Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: _selectedLanguage == 'english'
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      title: const Text(
                        'English',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedLanguage = 'english';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: _selectedLanguage == 'tagalog' || _selectedLanguage == 'filipino'
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      title: const Text(
                        'Tagalog',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedLanguage = 'tagalog';
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _isHoveringLanguage ? Colors.grey[200] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isHoveringLanguage
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedLanguage == 'english' ? 'English' : 'Tagalog',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextSize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Size',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoveringTextSizeMedium = true),
                onExit: (_) => setState(() => _isHoveringTextSizeMedium = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  transform: Matrix4.identity()..scale(_isHoveringTextSizeMedium ? 1.05 : 1.0),
                  child: InkWell(
                    onTap: () => setState(() => _selectedTextSize = 'medium'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTextSize == 'medium'
                            ? Colors.grey[300]
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedTextSize == 'medium'
                              ? Colors.blue
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Medium',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedTextSize == 'medium'
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoveringTextSizeLarge = true),
                onExit: (_) => setState(() => _isHoveringTextSizeLarge = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  transform: Matrix4.identity()..scale(_isHoveringTextSizeLarge ? 1.05 : 1.0),
                  child: InkWell(
                    onTap: () => setState(() => _selectedTextSize = 'large'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTextSize == 'large'
                            ? Colors.grey[300]
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedTextSize == 'large'
                              ? Colors.blue
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Large',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedTextSize == 'large'
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHardwareComponent(String title, String value, List<String> options, Function(String) onChanged) {
    String displayValue = value.substring(0, 1).toUpperCase() + value.substring(1);
    bool isHovering = false; // Local state for hover effect
    
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovering = true),
          onExit: (_) => setState(() => isHovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(isHovering ? 1.02 : 1.0),
            child: InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF2A2A2A),
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.map((option) {
                        String displayOption = option.substring(0, 1).toUpperCase() + option.substring(1);
                        return ListTile(
                          leading: value == option
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          title: Text(
                            displayOption,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            onChanged(option);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: isHovering ? Colors.grey[200] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isHovering
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayValue,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHardwareComponents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.grey, thickness: 1),
        const SizedBox(height: 20),
        const Text(
          'Hardware Components',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enable or disable hardware components.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        // DC Motor (Vibration Intensity)
        _buildHardwareComponent(
          'DC Motor',
          _vibrationIntensity,
          ['low', 'medium', 'high'],
          (value) => setState(() => _vibrationIntensity = value),
        ),
        const SizedBox(height: 12),
        // Ultrasonic Sensor (Usage Location)
        _buildHardwareComponent(
          'Ultrasonic Sensor',
          _usageLocation,
          ['indoors', 'outdoors'],
          (value) => setState(() => _usageLocation = value),
        ),
        const SizedBox(height: 12),
        // Audio Enabled Toggle
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Voice Alert / Audio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Switch(
                value: _audioEnabled,
                onChanged: (value) => setState(() => _audioEnabled = value),
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // DFPlayer (Audio Volume)
        _buildHardwareComponent(
          'DFPlayer (Audio Volume)',
          _volume,
          ['low', 'medium', 'high'],
          (value) => setState(() => _volume = value),
        ),
        const SizedBox(height: 12),
        // OLED Display (always enabled, no setting needed)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OLED Display',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Text(
                'Enabled',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Check if profiling data exists
    final hasProfilingData = _profilingData != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!hasProfilingData) ...[
                      // Show message if no profiling data
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'No Profiling Data Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please complete the profiling questionnaire first to access settings.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Show settings if profiling data exists
                      _buildLanguagePreference(),
                      const SizedBox(height: 32),
                      _buildTextSize(),
                      const SizedBox(height: 32),
                      _buildHardwareComponents(),
                      const SizedBox(height: 60), // Extra space before save button
                    ],
                  ],
                ),
              ),
            ),
            // Sticky Save Button at Bottom - Always Visible
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _buildAnimatedSaveButton(hasProfilingData),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Animated Save Button with Hover Effect
  Widget _buildAnimatedSaveButton(bool hasProfilingData) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringSave = true),
      onExit: (_) => setState(() => _isHoveringSave = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHoveringSave && hasProfilingData && !_isSaving ? 1.02 : 1.0),
        child: InkWell(
          onTap: (_isSaving || !hasProfilingData) ? null : _saveSettings,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: hasProfilingData && !_isSaving
                  ? const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF45A049)], // Green gradient
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: (!hasProfilingData || _isSaving) ? Colors.grey : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: hasProfilingData && !_isSaving
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(_isHoveringSave ? 0.5 : 0.3),
                        blurRadius: _isHoveringSave ? 12 : 8,
                        offset: Offset(0, _isHoveringSave ? 6 : 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Setting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

