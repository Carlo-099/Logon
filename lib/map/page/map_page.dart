import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logon/services/firebase_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _firebaseService = FirebaseService();
  GoogleMapController? _mapController;
  
  LatLng _currentLocation = const LatLng(14.5995, 120.9842); // Default: Manila, Philippines
  bool _isLoading = true;
  String _statusMessage = "Loading GPS data...";
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _loadGPSData();
    _listenToGPSUpdates();
  }

  Future<void> _loadGPSData() async {
    try {
      // Add timeout to prevent infinite loading
      final data = await _firebaseService.getGPSData()
          .timeout(const Duration(seconds: 5));
      
      if (data != null && data['latitude'] != null && data['longitude'] != null) {
        setState(() {
          _currentLocation = LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );
          _statusMessage = "GPS Location Updated";
          _isLoading = false;
        });
        _updateCameraPosition();
      } else {
        setState(() {
          _statusMessage = "No GPS data available. Waiting for ESP32...";
          _isLoading = false;
        });
      }
    } catch (e) {
      // Even if GPS data fails to load, show the map with default location
      setState(() {
        _statusMessage = "No GPS data from ESP32. Showing default location.";
        _isLoading = false;
      });
    }
  }

  void _listenToGPSUpdates() {
    _firebaseService.streamGPSData().listen((data) {
      if (data != null && data['latitude'] != null && data['longitude'] != null) {
        final newLocation = LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        );
        
        if (mounted) {
          setState(() {
            _currentLocation = newLocation;
            _statusMessage = "GPS Location Updated (Real-time)";
          });
          _updateCameraPosition();
        }
      }
    });
  }

  void _updateCameraPosition() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation, 15.0),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGPSData,
            tooltip: 'Refresh GPS',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Show error message if map fails to load
          if (_mapError != null)
            Center(
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Map Error',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mapError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _mapError = null;
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              print('✅ Google Map created successfully');
              print('📍 Initial location: ${_currentLocation.latitude}, ${_currentLocation.longitude}');
              setState(() {
                _mapError = null; // Clear any previous errors
              });
              _updateCameraPosition();
              // Check if map tiles are loading after a delay
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  print('🔍 Checking map tile loading status...');
                  // If map is still blank, there might be an API key issue
                  print('⚠️ If map is still blank, check Logcat for Google Maps API errors');
                }
              });
            },
            onTap: (LatLng location) {
              print('🗺️ Map tapped at: ${location.latitude}, ${location.longitude}');
            },
            onCameraMoveStarted: () {
              print('📷 Camera move started');
            },
            onCameraIdle: () {
              print('📷 Camera idle');
            },
            onCameraMove: (CameraPosition position) {
              print('📷 Camera moved to: ${position.target.latitude}, ${position.target.longitude}');
            },
            markers: {
              Marker(
                markerId: const MarkerId('esp32_location'),
                position: _currentLocation,
                infoWindow: InfoWindow(
                  title: 'ESP32 Location',
                  snippet: 'Lat: ${_currentLocation.latitude.toStringAsFixed(6)}, Lon: ${_currentLocation.longitude.toStringAsFixed(6)}',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
            // Avoid blank/permission issues: we don't request runtime location permission here.
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            compassEnabled: true,
            trafficEnabled: false,
            buildingsEnabled: true,
            liteModeEnabled: false, // Make sure lite mode is disabled
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latitude: ${_currentLocation.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Longitude: ${_currentLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

