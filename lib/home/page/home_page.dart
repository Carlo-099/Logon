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
    const darkGreen = Color(0xFF0B5D3B);
    final languageRaw = (_profilingData?['language'] ?? 'english').toString();
    final volumeRaw = (_profilingData?['volume'] ?? 'medium').toString();
    final languageLabel =
        languageRaw.toLowerCase().contains('tagalog') ? 'Tagalog' : 'English';
    final volumeLabel = volumeRaw.toLowerCase() == 'high'
        ? 'High'
        : volumeRaw.toLowerCase() == 'low'
            ? 'Low'
            : 'Medium';
    const trailModeLabel = 'Active';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/highkers.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.black);
                },
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            Column(
              children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      // UI-only: back action follows app flow.
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: darkGreen,
                        size: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFFF7FBF8),
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: darkGreen.withOpacity(0.15)),
                          ),
                          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          title: const Text(
                            'Menu',
                            style: TextStyle(
                              color: darkGreen,
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                color: const Color(0xFFEAF4EE),
                                borderRadius: BorderRadius.circular(18),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: const Icon(Icons.settings, color: darkGreen),
                                  title: const Text(
                                    'Settings',
                                    style: TextStyle(
                                      color: darkGreen,
                                      fontFamily: 'Georgia',
                                      fontWeight: FontWeight.w700,
                                    ),
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
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: const Color(0xFFFFF4F4),
                                borderRadius: BorderRadius.circular(18),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: const Icon(Icons.logout, color: Color(0xFFB23A3A)),
                                  title: const Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Color(0xFF7A2E2E),
                                      fontFamily: 'Georgia',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    logout();
                                  },
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: darkGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Good Day, Elderly and Hikers',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set up Your Cane',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Cane Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Clickable Cane Setup Container
                    InkWell(
                      onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const YourCanePage()),
                );
              },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: const BoxDecoration(
                                color: darkGreen,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Your Cane Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Georgia',
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: darkGreen, width: 2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'Language:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Georgia',
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                languageLabel,
                                                style: const TextStyle(
                                                  fontFamily: 'Georgia',
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Text(
                                                'Volume:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Georgia',
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                volumeLabel,
                                                style: const TextStyle(
                                                  fontFamily: 'Georgia',
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Text(
                                                'Trail Mode:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Georgia',
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                trailModeLabel,
                                                style: const TextStyle(
                                                  fontFamily: 'Georgia',
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      children: [
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: darkGreen, width: 3),
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Tap Card to Customize',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Georgia',
                                            color: darkGreen,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
                    const SizedBox(height: 20),
                    Text(
                      'Google Maps',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MapPage()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: darkGreen,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Show the current location of user',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Georgia',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 165,
                                width: double.infinity,
                                child: Image.asset(
                                  'assets/images/GM.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Screen Button Display',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            label: const Text(
                              'Battery',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
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
                            icon: const Icon(Icons.sensors),
                            label: const Text(
                              'Sensor',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
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
                            label: const Text(
                              'Links',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 0),
                    // Map Section
                    const SizedBox.shrink(),
                    const SizedBox(height: 0),
                    // Clickable Map Container
                    InkWell(
                      onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapPage()),
                );
              },
                      child: Container(
                        height: 0,
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
                    const SizedBox(height: 0),
                    const SizedBox.shrink(),
                    const SizedBox(height: 0),
                  ],
                ),
              ),
            ),
              ],
            ),
            ],
        ),
      ),
    );
  }
}