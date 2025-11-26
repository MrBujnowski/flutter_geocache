import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart' as LatLong; 
import 'package:geolocator/geolocator.dart'; 
import 'package:permission_handler/permission_handler.dart'; 

// 1. ČISTÝ IMPORT DOMÉNY (Modely a Rozhraní)
// Zde bereme CacheRepository a CacheModel.
import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

// 2. IMPORT DAT S PREFIXEM (Aby se to nehádalo)
// Všechno z tohoto souboru budeme volat jako "DataLayer.Něco"
import 'package:flutter_geocache/src/features/cache/data/supabase_cache_repository.dart' as DataLayer;

import 'package:flutter_geocache/src/core/utils/distance_calculator.dart' as DistCalc;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart'; 

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const String routeName = '/map';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // OPAVA: Používáme prefix 'DataLayer' pro vytvoření instance.
  // Tím Dart přesně ví, že chceme tu třídu z mock souboru.
  final CacheRepository _cacheRepository = DataLayer.SupabaseCacheRepository(); 
  
  final MapController _mapController = MapController();
  List<CacheModel> _availableCaches = [];
  StreamSubscription<Position>? _positionSubscription;
  
  static const LatLong.LatLng _initialPosition = LatLong.LatLng(50.0755, 14.4378);
  LatLong.LatLng _userPosition = _initialPosition;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final caches = await _cacheRepository.getAvailableCaches();
      setState(() {
        _availableCaches = caches;
        _isLoading = false;
      });
      _startLocationTracking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba dat: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _startLocationTracking() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _positionSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, 
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        final newPosition = LatLong.LatLng(position.latitude, position.longitude);
        
        if (_userPosition != newPosition) {
          setState(() {
            _userPosition = newPosition;
          });
          _checkForUnlockableCache(_userPosition);
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odmítnuto oprávnění k poloze.')),
        );
      }
    }
  }

  void _checkForUnlockableCache(LatLong.LatLng userPosition) {
    for (final cache in _availableCaches) {
      // Kontrola vzdálenosti
      if (!cache.isUnlocked && DistCalc.DistanceCalculator.isInRange(userPosition, cache.position)) {
        _showUnlockDialog(cache);
        break; 
      }
    }
  }

  void _showUnlockDialog(CacheModel cache) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cache nalezena: ${cache.name}'),
        content: Text('Dosah 20m. Odemknout? Nápověda: ${cache.hint}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unlockGeocache(cache);
            },
            child: const Text('Spustit Mini-hru'), 
          ),
        ],
      ),
    );
  }

  void _unlockGeocache(CacheModel cache) async {
    await _cacheRepository.unlockCache(cache.id);

    final updatedCaches = _availableCaches.map((c) {
      return c.id == cache.id ? c.copyWith(isUnlocked: true) : c;
    }).toList();

    setState(() {
      _availableCaches = updatedCaches;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gratulujeme! Cache ${cache.name} odemčena!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _centerMapOnUser() async {
    _mapController.move(_userPosition, 16.0);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  List<Marker> _buildCacheMarkers() {
    return _availableCaches.map((cache) {
      return Marker(
        point: cache.position,
        width: 40,
        height: 40,
        child: Icon(
          cache.isUnlocked ? Icons.check_circle : Icons.location_on,
          color: cache.isUnlocked ? Colors.green : Colors.red,
          size: 35,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text("GeoHunt Mapa", style: TextStyle(color: Colors.white)),
      ),
      
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: _initialPosition,
          initialZoom: 13.0,
          minZoom: 2.0,
          maxZoom: 18.0,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'cz.geohunt.app',
          ),
          CurrentLocationLayer(
            alignPositionOnUpdate: AlignOnUpdate.never,
            alignDirectionOnUpdate: AlignOnUpdate.never,
            style: const LocationMarkerStyle(
              marker: Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
              markerSize: Size(40, 40),
            ),
          ),
          MarkerLayer(markers: _buildCacheMarkers()),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerMapOnUser,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}