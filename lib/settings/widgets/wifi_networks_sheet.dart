import 'package:flutter/material.dart';
import 'package:logon/services/firebase_service.dart';

/// Bottom sheet to manage ESP32 WiFi list (same behavior as former Your Cane WiFi UI).
Future<void> showWifiNetworksSheet(
  BuildContext context,
  FirebaseService firebase,
  List<Map<String, dynamic>> wifiConfigs, {
  required void Function(List<Map<String, dynamic>> updated) onLocalChanged,
}) async {
  final list = List<Map<String, dynamic>>.from(
    wifiConfigs.map((e) => Map<String, dynamic>.from(e)),
  );

  final ssidController = TextEditingController();
  final passController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF2A2A2A),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
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
                  'Manage ESP32 WiFi list',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The cane tries WiFi #1 first, then #2, then the next.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ...list.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Text('#${i + 1}', style: const TextStyle(color: Colors.cyanAccent)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['ssid']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                (item['password']?.toString().isNotEmpty ?? false)
                                    ? '••••••••'
                                    : '(Open network)',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            list.removeAt(i);
                            onLocalChanged(List<Map<String, dynamic>>.from(
                              list.map((e) => Map<String, dynamic>.from(e)),
                            ));
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: ssidController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'WiFi name (SSID)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: passController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'WiFi password',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final ssid = ssidController.text.trim();
                          final pass = passController.text;
                          if (ssid.isEmpty) return;
                          list.add({
                            'ssid': ssid,
                            'password': pass,
                            'priority': list.length + 1,
                          });
                          onLocalChanged(List<Map<String, dynamic>>.from(
                            list.map((e) => Map<String, dynamic>.from(e)),
                          ));
                          ssidController.clear();
                          passController.clear();
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await firebase.saveUserWifiConfigsAndMirror(list);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'WiFi list saved. ESP32 restart requested to apply.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Save failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save to Firebase'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  ssidController.dispose();
  passController.dispose();
}
