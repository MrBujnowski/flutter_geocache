// lib/src/features/map/presentation/map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(50.0755, 14.4378); // Praha jako default
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      // Přidat marker pro aktuální pozici
      _addCurrentLocationMarker();
      
      // Přidat ukázkové geocache markery
      _addSampleGeocacheMarkers();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při získávání polohy: $e')),
        );
      }
    }
  }

  void _addCurrentLocationMarker() {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Vaše pozice',
            snippet: 'Aktuální poloha',
          ),
        ),
      );
    });
  }

  void _addSampleGeocacheMarkers() {
    // Přidat ukázkové geocache markery v okolí
    final sampleCaches = [
      {
        'id': 'cache_1',
        'position': LatLng(_currentLocation.latitude + 0.001, _currentLocation.longitude + 0.001),
        'title': 'Geocache #1',
        'snippet': 'První ukázkový cache',
      },
      {
        'id': 'cache_2',
        'position': LatLng(_currentLocation.latitude - 0.002, _currentLocation.longitude + 0.0015),
        'title': 'Geocache #2',
        'snippet': 'Druhý ukázkový cache',
      },
      {
        'id': 'cache_3',
        'position': LatLng(_currentLocation.latitude + 0.0015, _currentLocation.longitude - 0.002),
        'title': 'Geocache #3',
        'snippet': 'Třetí ukázkový cache',
      },
    ];

    for (final cache in sampleCaches) {
      _markers.add(
        Marker(
          markerId: MarkerId(cache['id'] as String),
          position: cache['position'] as LatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: cache['title'] as String,
            snippet: cache['snippet'] as String,
          ),
          onTap: () => _onGeocacheTapped(cache['id'] as String),
        ),
      );
    }
  }

  void _onGeocacheTapped(String cacheId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geocache nalezen!'),
        content: Text('Chcete odemknout cache: $cacheId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unlockGeocache(cacheId);
            },
            child: const Text('Odemknout'),
          ),
        ],
      ),
    );
  }

  void _unlockGeocache(String cacheId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cache $cacheId byl odemknut!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Používáme tmavě šedou pro pozadí
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          "GeoHunt Map",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            )
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 15.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // Používáme vlastní tlačítko v AppBar
              mapType: MapType.normal,
              onTap: (LatLng position) {
                // Můžeme přidat funkcionalitu pro přidání nového cache
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentLocation,
                zoom: 15.0,
              ),
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
