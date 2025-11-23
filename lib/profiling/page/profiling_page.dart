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

  // Hardware component states
  bool _dcMotor = false;
  bool _ultrasonic = false;
  bool _dfPlayer = false;
  bool _oled = false;

  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadProfilingData();
  }

  Future<void> _loadProfilingData() async {
    try {
      // Add timeout to prevent infinite loading
      final data = await _firebaseService.getProfilingData()
          .timeout(const Duration(seconds: 10));
      
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _dcMotor = data['dcMotor'] ?? false;
          _ultrasonic = data['ultrasonic'] ?? false;
          _dfPlayer = data['dfPlayer'] ?? false;
          _oled = data['oled'] ?? false;
        });
      }
    } catch (e) {
      // If error occurs (including timeout), just show the form empty
      // This allows user to create new profile even if database read fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Note: Could not load existing data. You can create a new profile. Error: $e"),
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseService.saveProfilingData(
        name: _nameController.text.trim(),
        dcMotor: _dcMotor,
        ultrasonic: _ultrasonic,
        dfPlayer: _dfPlayer,
        oled: _oled,
      );

      // Also save hardware control based on profiling settings
      await _firebaseService.saveHardwareControl(
        motorEnabled: _dcMotor,
        ultrasonicEnabled: _ultrasonic,
        audioEnabled: _dfPlayer,
      );

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildYesNoSwitch(String label, bool value, Function(bool) onChanged) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profiling'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiling'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'User Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 32),
              const Text(
                'Hardware Components',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enable or disable hardware components:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              _buildYesNoSwitch(
                'DC Motor',
                _dcMotor,
                (value) => setState(() => _dcMotor = value),
              ),
              _buildYesNoSwitch(
                'Ultrasonic Sensor',
                _ultrasonic,
                (value) => setState(() => _ultrasonic = value),
              ),
              _buildYesNoSwitch(
                'DFPlayer (Audio)',
                _dfPlayer,
                (value) => setState(() => _dfPlayer = value),
              ),
              _buildYesNoSwitch(
                'OLED Display',
                _oled,
                (value) => setState(() => _oled = value),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfilingData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save Profiling',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

