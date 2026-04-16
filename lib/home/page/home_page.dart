import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logon/login/page/login_page.dart';
import 'package:logon/cane/page/your_cane_page.dart';
import 'package:logon/map/page/map_page.dart';
import 'package:logon/services/firebase_service.dart';
import 'package:logon/settings/page/settings_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _firebaseService = FirebaseService();
  Map<String, dynamic>? _profilingData;
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(14.5995, 120.9842); // Default: Manila
  // Set to true if you want to use an image instead of Google Maps
  final bool _useMapImage = true; // Using GM.jpg image from assets/images/

  @override
  void initState() {
    super.initState();
    _loadProfilingData();
    _loadGPSData();
  }

  Future<void> _loadProfilingData() async {
    try {
      final data = await _firebaseService.getProfilingData();
      if (mounted) {
        setState(() {
          _profilingData = data;
        });
      }
    } catch (e) {
      // Handle error silently for UI-only update
    }
  }

  Future<void> _loadGPSData() async {
    try {
      final data = await _firebaseService.getGPSData();
      if (data != null && data['latitude'] != null && data['longitude'] != null) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(
              (data['latitude'] as num).toDouble(),
              (data['longitude'] as num).toDouble(),
            );
          });
          _updateCameraPosition();
        }
      }
    } catch (e) {
      // Handle error silently for UI-only update
    }
  }

  void _updateCameraPosition() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation, 15),
    );
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error signing out. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'HOME',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
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
                          const Text(
                            'TECH',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Hamburger menu
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () {
                          // Show menu options
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A1A),
                              title: const Text(
                                'Menu',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.settings, color: Colors.white),
                                    title: const Text(
                                      'Settings',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SettingsPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(color: Colors.grey),
                                  ListTile(
                                    leading: const Icon(Icons.logout, color: Colors.white),
                                    title: const Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      logout();
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Set Up Your Cane Section (replaces profiling)
                    const Text(
                      'Set Up Your Cane',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Clickable Cane Setup Container
                    InkWell(
                      onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const YourCanePage()),
                );
              },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Cane Settings',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Language: ${_profilingData?['language'] ?? 'Not set'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Volume: ${_profilingData?['volume'] ?? 'Not set'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to customize the cane',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Profile image
                            ClipOval(
                              child: Image.asset(
                                'assets/images/pf.jpg',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to placeholder if image not found
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[300],
                                    ),
                                    child: const Icon(
                                      Icons.settings,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
                    const SizedBox(height: 8),
                    const Text(
                      "Configure your cane and save settings to Firebase.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // OLED quick view buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await _firebaseService.setOledMode('battery');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('OLED set to Battery screen'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.battery_full),
                            label: const Text('Battery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await _firebaseService.setOledMode('sensor');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('OLED set to Sensor distance'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.straighten),
                            label: const Text('Sensor'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await _firebaseService.setOledMode('connections');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('OLED set to Connections'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.wifi_tethering),
                            label: const Text('Links'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Map Section
                    const Text(
                      'Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
              ),
            ),
                    const SizedBox(height: 16),
                    // Clickable Map Container
                    InkWell(
                      onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapPage()),
                );
              },
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _useMapImage
                              ? // Show image if _useMapImage is true
                              Image.asset(
                                  'assets/images/GM.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to Google Maps if image not found
                                    return GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: _currentLocation,
                                        zoom: 15,
                                      ),
                                      onMapCreated: (GoogleMapController controller) {
                                        _mapController = controller;
                                      },
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('current_location'),
                                          position: _currentLocation,
                                          icon: BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueBlue,
                                          ),
                                        ),
                                      },
                                      circles: {
                                        Circle(
                                          circleId: const CircleId('location_radius'),
                                          center: _currentLocation,
                                          radius: 100,
                                          fillColor: Colors.blue.withOpacity(0.2),
                                          strokeColor: Colors.blue,
                                          strokeWidth: 2,
                                        ),
                                      },
                                      // Avoid blank/permission issues: we don't request runtime location permission here.
                                      myLocationEnabled: false,
                                      myLocationButtonEnabled: false,
                                    );
                                  },
                                )
                              : // Show Google Maps by default
                              GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: _currentLocation,
                                    zoom: 15,
                                  ),
                                  onMapCreated: (GoogleMapController controller) {
                                    _mapController = controller;
                                  },
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('current_location'),
                                      position: _currentLocation,
                                      icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueBlue,
                                      ),
                                    ),
                                  },
                                  circles: {
                                    Circle(
                                      circleId: const CircleId('location_radius'),
                                      center: _currentLocation,
                                      radius: 100,
                                      fillColor: Colors.blue.withOpacity(0.2),
                                      strokeColor: Colors.blue,
                                      strokeWidth: 2,
                                    ),
                                  },
                                  // Avoid blank/permission issues: we don't request runtime location permission here.
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                ),
                        ),
                ),
              ),
                    const SizedBox(height: 8),
                    const Text(
                      "Maps show the current location of the users to track where the user go.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}