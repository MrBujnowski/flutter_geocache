import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart' as lat_long; 
import 'package:geolocator/geolocator.dart'; 
import 'package:permission_handler/permission_handler.dart'; 

import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';
import 'package:flutter_geocache/src/features/cache/data/supabase_cache_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter_geocache/src/core/utils/distance_calculator.dart' as dist_calc;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:provider/provider.dart';
import '../../game/presentation/game_screen.dart'; 
import '../../leaderboard/presentation/leaderboard_screen.dart'; 
import '../../profile/presentation/profile_screen.dart'; 
import 'compass_widget.dart'; 
import 'navigation_overlay.dart';
import '../../map/application/navigation_manager.dart'; 
import '../../cache/presentation/logbook_screen.dart'; 

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const String routeName = '/map';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// ... imports

class _MapScreenState extends State<MapScreen> {
  late final CacheRepository _cacheRepository; 
  
  final MapController _mapController = MapController();
  List<CacheModel> _availableCaches = []; // Restored
  StreamSubscription<Position>? _positionSubscription;
  
  static const lat_long.LatLng _initialPosition = lat_long.LatLng(50.0755, 14.4378);
  lat_long.LatLng _userPosition = _initialPosition;

  bool _isLoading = true;
  String? _activeCacheId; // Zámek pro zabránění vícenásobnému otevření dialogu nebo hry
  bool _isAdmin = false;
  List<Marker> _cachedMarkers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheRepository = context.read<CacheRepository>();
      _checkUserRole(); // Check role on init
      _initializeApp();
    });
  }

  bool _isSimulatingPlayer = false; // Add simulation state

  Future<void> _checkUserRole() async {
      if (_cacheRepository is SupabaseCacheRepository) {
          final repo = _cacheRepository as SupabaseCacheRepository;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
              final isAdmin = await repo.isAdmin(userId);
              if (mounted) {
                 setState(() {
                    _isAdmin = isAdmin;
                    // Critical Fix: Rebuild markers now that we know we are Admin
                    _rebuildMarkers();
                 });
              }
          }
      }
  }

  Future<void> _initializeApp() async {
    try {
      final caches = await _cacheRepository.getAvailableCaches();
      // Pokus o sync logů
       if (_cacheRepository is SupabaseCacheRepository) {
          (_cacheRepository as SupabaseCacheRepository).syncPendingLogs();
       }
       
      setState(() {
        _availableCaches = caches;
        _rebuildMarkers(); 
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



  void _rebuildMarkers() {
      // 1. Filter caches based on role
      List<CacheModel> visibleCaches = _availableCaches;
      
      // Admin sees ALL unless simulating player. Player sees 5 nearest.
      if (!_isAdmin || _isSimulatingPlayer) {
          // Player Logic:
          // 1. Show ALL unlocked (found) caches.
          // 2. Show 5 nearest LOCKED (unfound) caches.
          
          final unlocked = _availableCaches.where((c) => c.isUnlocked).toList();
          final locked = _availableCaches.where((c) => !c.isUnlocked).toList();
          
          // Sort locked by distance
          locked.sort((a, b) {
              final distA = dist_calc.DistanceCalculator.calculateDistance(_userPosition, a.position);
              final distB = dist_calc.DistanceCalculator.calculateDistance(_userPosition, b.position);
              return distA.compareTo(distB);
          });
          
          // Combine: All unlocked + 5 nearest locked
          visibleCaches = [...unlocked, ...locked.take(5)];
      }
      
      // 2. Build markers
      _cachedMarkers = visibleCaches.map((cache) {
          return Marker(
            point: cache.position,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showCacheDetail(cache),
              child: Icon(
                cache.isUnlocked ? Icons.check_circle : Icons.location_on,
                color: cache.isUnlocked ? Colors.green : Colors.red,
                size: 35,
              ),
            ),
          );
       }).toList();
  }
  
 // ... _downloadOfflineData, _startLocationTracking (Remember to call _rebuildMarkers on location update if player!)

  void _startLocationTracking() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      if (!kIsWeb) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && mounted) {
            setState(() {
              _userPosition = lat_long.LatLng(lastKnown.latitude, lastKnown.longitude);
            });
          }
        } catch (_) {
        }
      }

      await _positionSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, 
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        final newPosition = lat_long.LatLng(position.latitude, position.longitude);
        
        if (_userPosition != newPosition) {
          setState(() {
            _userPosition = newPosition;
          });
          
          if (!_isAdmin) {
             _rebuildMarkers(); 
          }
          
          _checkForUnlockableCache(_userPosition);
          if (mounted) {
             context.read<NavigationManager>().updateProgress(_userPosition);
          }
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

  // ... _showCacheDetail
  
  void _showCacheDetail(CacheModel cache) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cache.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... existing content
            Text('Stav: ${cache.isUnlocked ? "NALEZENO ✅" : "Zatím nenalezeno ❌"}'),
            const SizedBox(height: 8),
            Text(cache.displayDescription),
            const SizedBox(height: 8),
            Text('Souřadnice: ${cache.position.latitude}, ${cache.position.longitude}'),
            if (cache.isUnlocked || _isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    LogbookScreen.routeName,
                    arguments: {'cacheId': cache.id, 'cacheName': cache.displayName},
                  );
                },
                child: Text(_isAdmin && !cache.isUnlocked ? 'Zobrazit Logbook (Admin)' : 'Zobrazit Logbook'),
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<NavigationManager>().startNavigation(_userPosition, cache.position);
              },
              icon: const Icon(Icons.navigation),
              label: const Text('Navigovat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
          if (_isAdmin) // Admin Delete Button
             TextButton(
              onPressed: () async {
                  final confirm = await showDialog<bool>(
                      context: context, 
                      builder: (ctx) => AlertDialog(
                          title: const Text("Smazat kešku?"),
                          content: const Text("Opravdu chcete smazat tuto kešku? Tato akce je nevratná."),
                          actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Ne")),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Ano, smazat", style: TextStyle(color: Colors.red))),
                          ],
                      )
                  );
                  
                  if (confirm == true) {
                      Navigator.of(context).pop(); // Close detail
                      await _deleteCache(cache.id);
                  }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('SMAZAT (Admin)'),
            ),
          if (cache.isUnlocked)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetCache(cache);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('RESET (ZAMKNOUT)'),
            ),
        ],
      ),
    );
  }
  
  Future<void> _deleteCache(String cacheId) async {
      try {
           if (_cacheRepository is SupabaseCacheRepository) {
               await (_cacheRepository as SupabaseCacheRepository).deleteCache(cacheId);
               
               setState(() {
                   _availableCaches.removeWhere((c) => c.id == cacheId);
                   _rebuildMarkers();
               });
               
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keška smazána.")));
           }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba při mazání: $e")));
      }
  }

  // ... rest of file

  // Duplicate methods removed

  bool _isDownloading = false; // Background download state

  Future<void> _downloadOfflineData() async {
    if (_isDownloading) return; // Prevent double click

    setState(() => _isDownloading = true);
    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Row(children: [CircularProgressIndicator(), SizedBox(width: 10), Text("Stahuji data na pozadí...")]),
         duration: Duration(days: 1), // Keep visible until dismissed
       ) 
    );
    
    try {
      if (_cacheRepository is! SupabaseCacheRepository) {
         throw Exception("Repository nepodporuje offline stahování");
      }
      final repo = _cacheRepository as SupabaseCacheRepository;

      final count = await repo.downloadAllCaches();
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Hide progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Úspěšně staženo $count kešek pro offline použití!'), backgroundColor: Colors.green),
        );
        _initializeApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba stahování: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
       if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _checkForUnlockableCache(lat_long.LatLng userPosition) {
    if (_activeCacheId != null) return;

    for (final cache in _availableCaches) {
      if (!cache.isUnlocked && dist_calc.DistanceCalculator.isInRange(userPosition, cache.position)) {
        _activeCacheId = cache.id; 
        _showUnlockDialog(cache);
        break; 
      }
    }
  }

  void _showUnlockDialog(CacheModel cache) async {
    final shouldPlay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cache nalezena: ${cache.displayName}'),
        content: Text('Dosah 20m. Odemknout?\n${cache.displayDescription}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Spustit Mini-hru'), 
          ),
        ],
      ),
    );

    if (shouldPlay == true) {
      if (!mounted) return;
      
      final result = await Navigator.of(context).pushNamed(
        GameScreen.routeName,
        arguments: cache,
      );

      if (!mounted) {
        _activeCacheId = null;
        return;
      }

      if (result == true) {
        await _unlockGeocache(cache);
      }
    }
    
    if (mounted) {
       _activeCacheId = null; 
    }
  }


  Future<void> _resetCache(CacheModel cache) async {
    try {
      await _cacheRepository.resetCache(cache.id);
      
       if (!mounted) return;

      final updatedCaches = _availableCaches.map((c) {
        return c.id == cache.id ? c.copyWith(isUnlocked: false) : c;
      }).toList();

      setState(() {
        _availableCaches = updatedCaches;
        _rebuildMarkers();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache byla resetována a znovu zamčena.')),
      );

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba resetu: $e')));
      }
    }
  }

  Future<void> _unlockGeocache(CacheModel cache) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gratulujeme! Cache ${cache.displayName} odemčena!'),
          backgroundColor: Colors.green,
        ),
      );

      final newAchievements = await _cacheRepository.unlockCache(cache.id);
      
      if (!mounted) return;

      if (newAchievements.isNotEmpty) {
        for (final achievementName in newAchievements) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Nový achievement: $achievementName!')),
                  const Icon(Icons.star, color: Colors.amber),
                ],
              ),
              backgroundColor: Colors.purple,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      
      if (mounted) {
         final updatedCaches = _availableCaches.map((c) {
          return c.id == cache.id ? c.copyWith(isUnlocked: true) : c;
        }).toList();
        setState(() {
          _availableCaches = updatedCaches;
          _rebuildMarkers();
        });

        // Automaticky přesměrovat na Logbook
        await Future.delayed(const Duration(seconds: 1)); // Krátká pauza, aby si uživatel všiml snackbaru
        if (mounted) {
             Navigator.of(context).pushNamed(
                LogbookScreen.routeName,
                arguments: {'cacheId': cache.id, 'cacheName': cache.displayName},
             );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při ukládání: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        leading: IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed(ProfileScreen.routeName);
            },
        ),
        actions: [
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
               final isOffline = snapshot.data?.contains(ConnectivityResult.none) ?? false;
               return Tooltip(
                 message: isOffline ? 'Offline' : 'Online',
                 child: Container(
                   margin: const EdgeInsets.symmetric(horizontal: 8),
                   padding: const EdgeInsets.all(6),
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     color: isOffline ? Colors.red : Colors.green,
                     border: Border.all(color: Colors.white, width: 1.5),
                   ),
                   child: Icon(
                     isOffline ? Icons.wifi_off : Icons.wifi,
                     color: Colors.white,
                     size: 16,
                   ),
                 ),
               );
            },
          ),
          if (_isAdmin)
             IconButton(
               icon: Icon(_isSimulatingPlayer ? Icons.visibility_off : Icons.visibility, color: _isSimulatingPlayer ? Colors.orange : Colors.white),
               tooltip: _isSimulatingPlayer ? "Zrušit simulaci hráče" : "Simulovat pohled hráče",
               onPressed: () {
                  setState(() {
                      _isSimulatingPlayer = !_isSimulatingPlayer;
                      _rebuildMarkers();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isSimulatingPlayer ? "Simulace hráče ZAPNUTA (5 nejbližších)" : "Simulace hráče VYPNUTA (Všechny kešky)")));
               },
             ),
          IconButton(
            icon: const Icon(Icons.cloud_download, color: Colors.white),
            tooltip: 'Stáhnout offline data',
            onPressed: _downloadOfflineData,
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amber),
            onPressed: () {
              Navigator.of(context).pushNamed(LeaderboardScreen.routeName);
            },
          ),
        ],
      ),
      
      body: Stack(
        children: [
          FlutterMap(
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
              // Polyline Layer for Navigation
              Consumer<NavigationManager>(
                builder: (context, nav, child) {
                   if (!nav.isNavigating || nav.currentRoute == null) return const SizedBox.shrink();
                   return PolylineLayer(
                     polylines: [
                       Polyline(
                         points: nav.currentRoute!.geometry,
                         strokeWidth: 4.0,
                         color: Colors.blueAccent,
                         borderColor: Colors.blue.shade900,
                         borderStrokeWidth: 1.0,
                       ),
                     ],
                   );
                },
              ),
              CurrentLocationLayer(
                alignPositionOnUpdate: AlignOnUpdate.never,
                alignDirectionOnUpdate: AlignOnUpdate.never,
                style: const LocationMarkerStyle(
                  marker: Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                  markerSize: Size(40, 40),
                ),
              ),
              // CLUSTERING LAYER
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 120,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: _cachedMarkers,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.blue,
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          
          // Kompas vpravo nahoře
          Positioned(
            top: 20, 
            right: 20, 
            child: CompassWidget(
              userPosition: _userPosition, 
              availableCaches: _availableCaches
            ),
          ),
          
          // Navigation Overlay
          Positioned(
             top: 0, left: 0, right: 0,
             bottom: 0,
             child: Consumer<NavigationManager>(
               builder: (context, nav, child) {
                  if (!nav.isNavigating) return const SizedBox.shrink();
                  // Předáváme kliky skrz prázdné místa, aby šlo hýbat s mapou?
                  // NavigationOverlay zabírá celé místo, ale je to Column s MainAxis.spaceBetween.
                  // Musíme zajistit, aby Column neblokoval touch events uprostřed.
                  return IgnorePointer(
                    ignoring: false, // chceme klikat na tlačítko ukončit
                    child: NavigationOverlay(manager: nav),
                  ); 
                  // Problém: Pokud NavigationOverlay je přes celou obrazovku, nepůjde hýbat s mapou.
                  // NavigationOverlay vrací Column. Defaultně zabírá místo.
                  // Musíme widget NavigationOverlay upravit, aby používal Align nebo Positioned.
                  // Zde jen vložíme.
                  // UPDATE: NavigationOverlay už je Column, ale potřebujeme, aby "prázdno" bylo průchozí.
                  // Nejlepší je dát NavigationOverlay do Stacku jako Positioned, ale on sám je Column.
                  // Řešení: NavigationOverlay by měl vracet Stack nebo používat Align,
                  // nebo zde použijeme `PointerInterceptor` pokud by to byl web, 
                  // ale tady stačí, že NavigationOverlay bude mít `HitTestBehavior.translucent`? Ne.
                  
                  // Abychom mohli hýbat s mapou, musí být overlay "děravý".
                  // NavigationOverlay vrací Column s Children.
                  // Obalíme to do `Align`? Ne, jsou tam dva panely (nahoře/dole).
                  // Vložím NavigationOverlay tak jak je, v budoucnu možná budu muset řešit hit testy,
                  // pokud Column s `MainAxisAlignment.spaceBetween` blokuje střed.
                  // Ve Flutteru Column zabírá hit test jen tam, kde má children, POKUD nemá backgroundColor.
                  // NavigationOverlay nemá barvu pozadí, takže by to mělo projít.
               },
             ),
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