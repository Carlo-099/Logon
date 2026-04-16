import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logon/services/firebase_service.dart';

class YourCanePage extends StatefulWidget {
  const YourCanePage({super.key});

  @override
  State<YourCanePage> createState() => _YourCanePageState();
}

class _YourCanePageState extends State<YourCanePage> {
  final _firebaseService = FirebaseService();
  StreamSubscription<Map<String, dynamic>?>? _sub;

  bool _loading = true;
  bool _saving = false;

  // Mirror of cane settings (per-user)
  bool _motorEnabled = true;
  bool _ultrasonicEnabled = true;
  bool _audioEnabled = false;

  String _language = 'tagalog'; // tagalog | english | none
  String _volume = 'medium'; // low | medium | high
  String _vibrationIntensity = 'medium'; // low | medium | high
  String _usageLocation = 'outdoors'; // indoors | outdoors
  int _emergencyEmailCount = 0;
  String _senderEmail = '';

  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _statusText = '';
    });

    try {
      final existing = await _firebaseService.getUserCaneControl();
      if (existing != null) _applyFromMap(existing);
      final emergency = await _firebaseService.getEmergencyContactEmails();
      final sender = await _firebaseService.getGpsEmailSenderCredentials();
      _emergencyEmailCount = emergency.length;
      _senderEmail = sender?['gmail'] ?? '';

      _sub = _firebaseService.streamUserCaneControl().listen((data) {
        if (!mounted) return;
        if (data != null) {
          setState(() {
            _applyFromMap(data);
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Could not load cane settings: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFromMap(Map<String, dynamic> m) {
    _motorEnabled = (m['motorEnabled'] as bool?) ?? _motorEnabled;
    _ultrasonicEnabled = (m['ultrasonicEnabled'] as bool?) ?? _ultrasonicEnabled;
    _audioEnabled = (m['audioEnabled'] as bool?) ?? _audioEnabled;

    final lang = (m['language'] as String?)?.toLowerCase();
    if (lang == 'english' || lang == 'tagalog' || lang == 'none') {
      _language = lang!;
    }

    final vol = (m['volume'] as String?)?.toLowerCase();
    if (vol == 'low' || vol == 'medium' || vol == 'high') {
      _volume = vol!;
    }

    final vib = (m['vibrationIntensity'] as String?)?.toLowerCase();
    if (vib == 'low' || vib == 'medium' || vib == 'high') {
      _vibrationIntensity = vib!;
    }

    final loc = (m['usageLocation'] as String?)?.toLowerCase();
    if (loc == 'indoors' || loc == 'outdoors') {
      _usageLocation = loc!;
    }
  }

  Future<void> _save({required bool restartRequested}) async {
    setState(() {
      _saving = true;
      _statusText = '';
    });

    try {
      await _firebaseService.saveUserCaneControlAndMirror(
        motorEnabled: _motorEnabled,
        ultrasonicEnabled: _ultrasonicEnabled,
        audioEnabled: _audioEnabled,
        language: _language,
        usageLocation: _usageLocation,
        vibrationIntensity: _vibrationIntensity,
        volume: _volume,
        restartRequested: restartRequested,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved! Your cane will update in real-time.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Save failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manageEmergencyContacts() async {
    final rootContext = context;
    final existing = await _firebaseService.getEmergencyContactEmails();
    final controllers = List<TextEditingController>.generate(
      existing.isEmpty ? 1 : existing.length,
      (i) => TextEditingController(text: existing.isEmpty ? '' : existing[i]),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emergency contact emails',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(controllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers[index],
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email ${index + 1}',
                                labelStyle: const TextStyle(color: Colors.white70),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (controllers.length == 1) {
                                controllers.first.clear();
                              } else {
                                // Don't dispose controllers while TextFields are mounted.
                                // We'll dispose all controllers after the sheet closes.
                                controllers.removeAt(index);
                              }
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (controllers.length < 3)
                    TextButton.icon(
                      onPressed: () {
                        controllers.add(TextEditingController());
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.add, color: Colors.greenAccent),
                      label: const Text('Add another email', style: TextStyle(color: Colors.greenAccent)),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final emails = controllers
                            .map((c) => c.text.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        try {
                          await _firebaseService.saveEmergencyContactEmails(emails);
                          if (!mounted) return;
                          setState(() => _emergencyEmailCount = emails.length);
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(
                              content: Text('Emergency contacts saved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    for (final c in controllers) {
      c.dispose();
    }
  }

  Future<void> _manageGpsSender() async {
    final rootContext = context;
    final existing = await _firebaseService.getGpsEmailSenderCredentials();
    final gmailController = TextEditingController(text: existing?['gmail'] ?? '');
    final pwController = TextEditingController(text: existing?['appPassword'] ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GPS alert sender account',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gmailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sender Gmail',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pwController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Gmail App Password',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await _firebaseService.clearGpsEmailSenderCredentials();
                          if (!mounted) return;
                          setState(() => _senderEmail = '');
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(content: Text('Sender cleared')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(content: Text('Clear failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _firebaseService.saveGpsEmailSenderCredentials(
                            gmail: gmailController.text.trim(),
                            appPassword: pwController.text.trim(),
                          );
                          if (!mounted) return;
                          setState(() => _senderEmail = gmailController.text.trim());
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(content: Text('Sender saved'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    gmailController.dispose();
    pwController.dispose();
  }

  Future<void> _pickOption({
    required String title,
    required List<_Option> options,
    required _Option selected,
    required void Function(_Option) onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((o) {
                final isSel = o.id == selected.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: isSel ? const Icon(Icons.check, color: Colors.green) : null,
                  title: Text(o.label, style: const TextStyle(color: Colors.white)),
                  subtitle: o.subtitle == null
                      ? null
                      : Text(o.subtitle!, style: const TextStyle(color: Colors.white60)),
                  onTap: () {
                    onSelected(o);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaneCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _saving ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: borderColor),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white60),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Your Cane'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _saving ? null : _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232323),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _saving
                                  ? 'Saving…'
                                  : 'Adjust your cane settings. Changes update Firebase and the ESP32 in real-time.',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_statusText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _statusText,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                        children: [
                          _buildCaneCard(
                            title: 'Ultrasonic',
                            subtitle: _ultrasonicEnabled ? 'Enabled' : 'Disabled',
                            icon: Icons.sensors,
                            borderColor: Colors.cyan,
                            onTap: () async {
                              setState(() => _ultrasonicEnabled = !_ultrasonicEnabled);
                              await _save(restartRequested: false);
                            },
                          ),
                          _buildCaneCard(
                            title: 'Vibration',
                            subtitle: _motorEnabled ? 'Enabled • ${_vibrationIntensity.toUpperCase()}' : 'Disabled',
                            icon: Icons.vibration,
                            borderColor: Colors.purpleAccent,
                            onTap: () async {
                              // Open options: toggle + intensity
                              await _pickOption(
                                title: 'Vibration',
                                selected: _Option(
                                  id: _motorEnabled ? 'on' : 'off',
                                  label: _motorEnabled ? 'Enabled' : 'Disabled',
                                ),
                                options: const [
                                  _Option(id: 'on', label: 'Enabled'),
                                  _Option(id: 'off', label: 'Disabled'),
                                ],
                                onSelected: (o) => setState(() => _motorEnabled = o.id == 'on'),
                              );

                              if (_motorEnabled) {
                                await _pickOption(
                                  title: 'Vibration Intensity',
                                  selected: _Option(id: _vibrationIntensity, label: _vibrationIntensity.toUpperCase()),
                                  options: const [
                                    _Option(id: 'low', label: 'LOW'),
                                    _Option(id: 'medium', label: 'MEDIUM'),
                                    _Option(id: 'high', label: 'HIGH'),
                                  ],
                                  onSelected: (o) => setState(() => _vibrationIntensity = o.id),
                                );
                              }

                              await _save(restartRequested: false);
                            },
                          ),
                          _buildCaneCard(
                            title: 'Voice Alert',
                            subtitle: _audioEnabled ? 'Enabled' : 'Disabled',
                            icon: Icons.record_voice_over,
                            borderColor: Colors.greenAccent,
                            onTap: () async {
                              setState(() => _audioEnabled = !_audioEnabled);
                              // audio changes can be treated as critical if you want
                              await _save(restartRequested: false);
                            },
                          ),
                          _buildCaneCard(
                            title: 'Volume',
                            subtitle: _volume.toUpperCase(),
                            icon: Icons.volume_up,
                            borderColor: Colors.orangeAccent,
                            onTap: () async {
                              await _pickOption(
                                title: 'Volume',
                                selected: _Option(id: _volume, label: _volume.toUpperCase()),
                                options: const [
                                  _Option(id: 'low', label: 'LOW'),
                                  _Option(id: 'medium', label: 'MEDIUM'),
                                  _Option(id: 'high', label: 'HIGH'),
                                ],
                                onSelected: (o) => setState(() => _volume = o.id),
                              );
                              await _save(restartRequested: false);
                            },
                          ),
                          _buildCaneCard(
                            title: 'Language',
                            subtitle: _language == 'none' ? 'NONE (Display only)' : _language.toUpperCase(),
                            icon: Icons.language,
                            borderColor: Colors.lightBlueAccent,
                            onTap: () async {
                              await _pickOption(
                                title: 'Language',
                                selected: _Option(
                                  id: _language,
                                  label: _language.toUpperCase(),
                                  subtitle: _language == 'none'
                                      ? 'No audio. OLED will still show status.'
                                      : null,
                                ),
                                options: const [
                                  _Option(id: 'tagalog', label: 'TAGALOG'),
                                  _Option(id: 'english', label: 'ENGLISH'),
                                  _Option(id: 'none', label: 'NONE', subtitle: 'No audio prompts'),
                                ],
                                onSelected: (o) => setState(() => _language = o.id),
                              );
                              await _save(restartRequested: false);
                            },
                          ),
                          _buildCaneCard(
                            title: 'Location',
                            subtitle: _usageLocation.toUpperCase(),
                            icon: Icons.place,
                            borderColor: Colors.tealAccent,
                            onTap: () async {
                              await _pickOption(
                                title: 'Usage Location',
                                selected: _Option(id: _usageLocation, label: _usageLocation.toUpperCase()),
                                options: const [
                                  _Option(id: 'indoors', label: 'INDOORS'),
                                  _Option(id: 'outdoors', label: 'OUTDOORS'),
                                ],
                                onSelected: (o) => setState(() => _usageLocation = o.id),
                              );
                              await _save(restartRequested: false);
                            },
                          ),
                          _buildCaneCard(
                            title: 'Emergency Contacts',
                            subtitle: _emergencyEmailCount == 0
                                ? 'No emails set'
                                : '$_emergencyEmailCount email(s)',
                            icon: Icons.emergency_share_outlined,
                            borderColor: Colors.amberAccent,
                            onTap: _manageEmergencyContacts,
                          ),
                          _buildCaneCard(
                            title: 'GPS Sender',
                            subtitle: _senderEmail.isEmpty ? 'Not configured' : _senderEmail,
                            icon: Icons.mail_outline,
                            borderColor: Colors.pinkAccent,
                            onTap: _manageGpsSender,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              await _save(restartRequested: true);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.restart_alt, color: Colors.white),
                      label: const Text(
                        'Apply & Restart Cane',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Option {
  final String id;
  final String label;
  final String? subtitle;
  const _Option({required this.id, required this.label, this.subtitle});
}

