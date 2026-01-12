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
import 'package:flutter_geocache/src/features/map/presentation/widgets/animated_cache_marker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../cache/presentation/logbook_screen.dart'; 
import '../../game/presentation/ar_coin_game_screen.dart';
import '../../game/presentation/falling_fragments_game_screen.dart';
import 'dart:math' as math; // Ensure math is available for Random

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
  lat_long.LatLng _userPosition = _initialPosition; // Back to non-nullable
  bool _isLocationLoaded = false; // Flag to control loading screen

  bool _isLoading = true;
  bool _hasInitialLocation = false; // Legacy, maybe remove? Keep for now.
  String? _activeCacheId;
  bool _isAdmin = false;
  List<Marker> _cachedMarkers = [];

  bool _isSimulatingPlayer = false; // Add simulation state
  bool _isPlayingGame = false; // Track if user is currently in mini-game

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheRepository = context.read<CacheRepository>();
      _checkUserRole(); // Check role on init
      _initializeApp();
    });
  }

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
      // Start location tracking FIRST to avoid delays
      _startLocationTracking();
      
      final caches = await _cacheRepository.getAvailableCaches();
      
      // Sync logs in background
      if (_cacheRepository is SupabaseCacheRepository) {
        (_cacheRepository as SupabaseCacheRepository).syncPendingLogs().catchError((e) {
          print("Sync logs error: $e");
        });
      }
       
      if (mounted) {
        setState(() {
          _availableCaches = caches;
          _isLoading = false;
        });
        // Always rebuild markers after caches load
        _rebuildMarkers();
      }
    } catch (e) {
      print("Init error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba dat: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }



  Future<void> _refreshCaches() async {
      await _initializeApp();
  }

  void _rebuildMarkers() {
      // 1. Filter caches based on role
      List<CacheModel> visibleCaches = _availableCaches;
      
      // Admin sees ALL unless simulating player. Player sees 5 nearest.
      if (!_isAdmin || _isSimulatingPlayer) {
          // Player Logic:
          // 1. Show ALL unlocked (found) caches.
          // 2. Show 15 nearest LOCKED (unfound) caches.
          
          final unlocked = _availableCaches.where((c) => c.isUnlocked).toList();
          final locked = _availableCaches.where((c) => !c.isUnlocked).toList();
          
          // Sort locked by distance
          locked.sort((a, b) {
              final distA = dist_calc.DistanceCalculator.calculateDistance(_userPosition, a.position);
              final distB = dist_calc.DistanceCalculator.calculateDistance(_userPosition, b.position);
              return distA.compareTo(distB);
          });
          
          // Combine: All unlocked + 15 nearest locked
          visibleCaches = [...unlocked, ...locked.take(15)];
      }
      
      // 2. Build markers
    // 2. Build markers
    _cachedMarkers = visibleCaches.map((cache) {
        return Marker(
          point: cache.position,
          width: 56, // Adjusted to match container 52 + shadow
          height: 56,
          child: AnimatedCacheMarker(
            isUnlocked: cache.isUnlocked,
            onTap: () => _showCacheDetail(cache),
          ),
        );
     }).toList();
  }
  
 // ... _downloadOfflineData, _startLocationTracking (Remember to call _rebuildMarkers on location update if player!)

  void _startLocationTracking() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      if (!kIsWeb) {
        // Try last known position first (instant)
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && mounted) {
            setState(() {
              _userPosition = lat_long.LatLng(lastKnown.latitude, lastKnown.longitude);
              _hasInitialLocation = true; 
              _isLocationLoaded = true;
            });
            _mapController.move(_userPosition, 16.0);
            _rebuildMarkers();
          }
        } catch (_) {}

        // If no last known position, try getting current position with timeout
        if (!_hasInitialLocation) {
          try {
            final currentPos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            );
            if (mounted) {
              setState(() {
                _userPosition = lat_long.LatLng(currentPos.latitude, currentPos.longitude);
                _hasInitialLocation = true;
                _isLocationLoaded = true;
              });
              _mapController.move(_userPosition, 16.0);
              _rebuildMarkers();
            }
          } catch (e) {
            print("getCurrentPosition timeout/error: $e");
            // Will fall back to stream below
          }
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
        bool positionChanged = _userPosition != newPosition;
        
        // Handling first fix
        if (!_hasInitialLocation && mounted) {
            setState(() {
                _userPosition = newPosition;
                _hasInitialLocation = true; 
                _isLocationLoaded = true; // Show map
            });
            // Center map on first fix
            _mapController.move(newPosition, 16.0);
            
            // Force rebuild markers on first fix
            if (!_isAdmin) {
                _rebuildMarkers();
            }
        } else if (positionChanged) {
             // Regular update
             setState(() {
                _userPosition = newPosition;
                _isLocationLoaded = true;
             });
             
             if (!_isAdmin) {
                _rebuildMarkers(); 
             }
             
             _checkForUnlockableCache(newPosition);
             if (mounted) {
                context.read<NavigationManager>().updateProgress(newPosition);
             }
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odmítnuto oprávnění k poloze.')),
        );
        // Allow user to proceed without location (default to Prague)
        setState(() {
            _hasInitialLocation = true;
            _isLocationLoaded = true;
        });
      }
    }
  }

  // ... _showCacheDetail
  

  
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
    // Don't show unlock dialog if user is playing a game
    if (_isPlayingGame) return;
    
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
    // Show bottom sheet instead of dialog for better UX
    _showCacheDetail(cache);
    // Don't reset _activeCacheId here - only reset when sheet closes or cache unlocked
  }


  void _showVictoryDialog(CacheModel cache) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 2)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
               const SizedBox(height: 10),
               const Text("GRATULUJEME!", style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               Text("Našli jste kešku\n${cache.displayName}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
               const SizedBox(height: 20),
               const Text("Keška byla odemčena a zapsána do vašeho profilu.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
             TextButton(
               onPressed: () {
                 Navigator.pop(ctx);
               },
               child: const Text("Zavřít", style: TextStyle(color: Colors.grey)),
             ),
             ElevatedButton.icon(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
               icon: const Icon(Icons.book, color: Colors.white),
               label: const Text("Otevřít Logbook", style: TextStyle(color: Colors.white)),
               onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(
                     LogbookScreen.routeName,
                     arguments: {'cacheId': cache.id, 'cacheName': cache.displayName},
                  );
               },
             )
          ],
        ),
      );
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
      
      // Update UI IMMEDIATELY - don't wait for server
      final updatedCaches = _availableCaches.map((c) {
        return c.id == cache.id ? c.copyWith(isUnlocked: true) : c;
      }).toList();
      setState(() {
        _availableCaches = updatedCaches;
        _rebuildMarkers();
      });
      
      // Show Victory Dialog IMMEDIATELY
      _showVictoryDialog(cache);

      // Then unlock in background (don't await - let it run async)
      _cacheRepository.unlockCache(cache.id).then((newAchievements) {
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
      }).catchError((e) {
        print("Background unlock error: $e");
      });
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

  Future<void> _launchMapsUrl(double lat, double lon) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
         throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nelze otevřít mapy: $e')));
      }
    }
  }

  void _showRateDialog(CacheModel cache) {
     if (!cache.isUnlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hodnotit lze pouze nalezené kešky!"), backgroundColor: Colors.orange)
        );
        return;
     }

     int selectedRating = 5;
     final commentController = TextEditingController();
     
     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setState) {
           return AlertDialog(
             backgroundColor: Colors.grey[900],
             title: Text("Hodnocení: ${cache.displayName}", style: const TextStyle(color: Colors.white)),
             content: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: List.generate(5, (index) {
                     return IconButton(
                       icon: Icon(
                         index < selectedRating ? Icons.star : Icons.star_border,
                         color: Colors.amber,
                         size: 32,
                       ),
                       onPressed: () {
                         setState(() => selectedRating = index + 1);
                       },
                     );
                   }),
                 ),
                 TextField(
                   controller: commentController,
                   style: const TextStyle(color: Colors.white),
                   decoration: const InputDecoration(
                     labelText: "Komentář (volitelné)",
                     labelStyle: TextStyle(color: Colors.grey),
                     hintText: "Jak se vám keška líbila?",
                     hintStyle: TextStyle(color: Colors.grey),
                     enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                   ),
                   maxLines: 3,
                 ),
               ],
             ),
             actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Zrušit")),
               ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                 onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                       await _cacheRepository.addReview(cache.id, selectedRating, commentController.text);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hodnocení odesláno!"), backgroundColor: Colors.green));
                       setState(() {}); 
                    } catch (e) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba: $e")));
                    }
                 },
                 child: const Text("Odeslat", style: TextStyle(color: Colors.white)),
               )
             ],
           );
         }
       ),
     );
  }

  void _startNavigation(CacheModel cache) {
     if (_userPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Neznám vaši polohu.")));
        return;
     }
     context.read<NavigationManager>().startNavigation(_userPosition!, cache.position);
  }

  void _showCacheDetail(CacheModel cache) async {
    // Pre-fetch data if likely to show immediately, or use FutureBuilder
    // We'll use FutureBuilder inside the sheet.
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Image/Gradient
                    Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                           colors: [Colors.teal, Colors.tealAccent],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Stack(
                        children: [

                             Positioned(
                               left: 20, bottom: 20,
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(cache.displayName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                   Text(cache.code, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                 ],
                               ),
                             ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Stats Row
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceAround,
                             children: [
                               _buildDetailBadge(Icons.terrain, "Terén: ${cache.terrain}"),
                               _buildDetailBadge(Icons.psychology, "Obtížnost: ${cache.difficulty}"),
                               if (_userPosition != null)
                                  _buildDetailBadge(Icons.directions_walk, _formatDistance(_userPosition!, cache.position)),
                             ],
                           ),
                           const SizedBox(height: 20),
                           
                           // Actions
                           Row(
                             children: [
                                Expanded(
                                 child: ElevatedButton.icon(
                                   icon: const Icon(Icons.directions_car, color: Colors.white), 
                                   label: const Text("Autem", style: TextStyle(color: Colors.white)),
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                   onPressed: () => _launchMapsUrl(cache.position.latitude, cache.position.longitude),
                                 ),
                               ),
                               const SizedBox(width: 10),
                                Expanded(
                                 child: ElevatedButton.icon(
                                   icon: const Icon(Icons.explore, color: Colors.white), 
                                   label: const Text("Pěšky", style: TextStyle(color: Colors.white)),
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                   onPressed: () {
                                      Navigator.pop(context);
                                      _startNavigation(cache);
                                   },
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 10),
                           SizedBox(
                             width: double.infinity,
                             child: ElevatedButton.icon(
                               icon: Icon(cache.isUnlocked ? Icons.book : Icons.play_arrow, color: Colors.black),
                               label: Text(cache.isUnlocked ? "Zobrazit Logbook" : "HLEDAT KEŠKU", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: (_userPosition != null && dist_calc.DistanceCalculator.isInRange(_userPosition!, cache.position)) || cache.isUnlocked 
                                    ? Colors.amber 
                                    : Colors.grey,
                               ),
                               onPressed: () async {
                                  // 1. Check Range if locked
                                  if (!cache.isUnlocked) {
                                      if (_userPosition == null || !dist_calc.DistanceCalculator.isInRange(_userPosition!, cache.position)) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jste příliš daleko! (Musíte být do 20m)")));
                                          return;
                                      }
                                  }

                                  Navigator.pop(context);
                                  if (cache.isUnlocked) {
                                      Navigator.of(context).pushNamed(
                                         LogbookScreen.routeName,
                                         arguments: {'cacheId': cache.id, 'cacheName': cache.displayName},
                                      );
                                  } else {
                                      // Launch Random Mini-Game
                                      _isPlayingGame = true;
                                      final isCoinHunt = math.Random().nextBool();
                                      final dynamic result;
                                      
                                      if (isCoinHunt) {
                                         result = await Navigator.of(context).push(
                                            MaterialPageRoute(builder: (ctx) => ARCoinGameScreen(cache: cache))
                                         );
                                      } else {
                                         result = await Navigator.of(context).push(
                                            MaterialPageRoute(builder: (ctx) => FallingFragmentsGameScreen(cache: cache))
                                         );
                                      }
                                      
                                      _isPlayingGame = false;
                                      
                                      if (result == true) {
                                          _unlockGeocache(cache); 
                                      }
                                  }
                               },
                             ),
                           ),
                           
                           const Divider(color: Colors.white24, height: 30),
                           
                           // Ratings & Reviews
                           const Text("Recenze", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 10),
                           
                           FutureBuilder<double>(
                              future: _cacheRepository.getAverageRating(cache.id),
                              builder: (context, snapshot) {
                                 final rating = snapshot.data ?? 0.0;
                                 return Row(
                                   children: [
                                      Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold)),
                                      const Icon(Icons.star, color: Colors.amber, size: 32),
                                      const Spacer(),
                                      if (cache.isUnlocked)
                                        TextButton.icon(
                                          icon: const Icon(Icons.rate_review, color: Colors.tealAccent),
                                          label: const Text("Přidat recenzi", style: TextStyle(color: Colors.tealAccent)),
                                          onPressed: () {
                                             Navigator.pop(context);
                                             _showRateDialog(cache);
                                          },
                                        ),
                                   ],
                                 );
                              },
                           ),

                           // Reviews List
                           FutureBuilder<List<Map<String, dynamic>>>(
                             future: _cacheRepository.getReviews(cache.id),
                             builder: (context, snapshot) {
                               print("📱 UI: FutureBuilder state - hasData: ${snapshot.hasData}, data: ${snapshot.data}");
                               if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                 return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("Zatím žádné recenze.", style: TextStyle(color: Colors.white54)));
                               }
                               return Column(
                                 children: snapshot.data!.take(3).map((r) {
                                    print("💬 Displaying review: $r");
                                    final username = r['profiles']?['username'] ?? 'Neznámý';
                                    final rating = r['rating'] as int;
                                    final comment = r['comment'] ?? '';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(backgroundColor: Colors.teal, child: Text(username[0].toUpperCase())),
                                      title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, size: 14, color: Colors.amber))),
                                          if (comment.isNotEmpty) Text(comment, style: const TextStyle(color: Colors.white70)),
                                        ],
                                      ),
                                    );
                                 }).toList(),
                               );
                             },
                           ),

                           // Admin Tools
                           if (_isAdmin) ...[
                               const Divider(color: Colors.redAccent, height: 40),
                               const Text("Administrace", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                               Row(
                                 children: [
                                   Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.refresh, color: Colors.orange),
                                        label: const Text("Resetovat", style: TextStyle(color: Colors.orange)),
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showResetDialog(cache);
                                        },
                                      ),
                                   ),
                                   const SizedBox(width: 10),
                                   Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        label: const Text("Smazat", style: TextStyle(color: Colors.red)),
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showDeleteDialog(cache);
                                        },
                                      ),
                                   ),
                                 ],
                               )
                           ],

                           
                           const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Reset _activeCacheId when sheet is closed
      if (mounted) {
        setState(() {
          _activeCacheId = null;
        });
      }
    });
  }

  Widget _buildDetailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  String _formatDistance(lat_long.LatLng start, lat_long.LatLng end) {
      final meters = dist_calc.DistanceCalculator.calculateDistance(start, end).toInt();
      if (meters > 999) {
         return "${(meters / 1000).toStringAsFixed(1)} km";
      }
      return "$meters m";
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
    if (!_isLocationLoaded) {
       return Scaffold(
         backgroundColor: Colors.teal,
         body: Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.map, size: 80, color: Colors.white),
               const SizedBox(height: 20),
               const Text("Načítám polohu...", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 20),
               const CircularProgressIndicator(color: Colors.white),
               const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                      // Try to get current position one more time with shorter timeout
                      try {
                        final pos = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.medium,
                          timeLimit: const Duration(seconds: 3),
                        );
                        if (mounted) {
                          setState(() {
                            _userPosition = lat_long.LatLng(pos.latitude, pos.longitude);
                            _isLocationLoaded = true;
                            _hasInitialLocation = true;
                          });
                          _mapController.move(_userPosition, 16.0);
                          _rebuildMarkers();
                        }
                      } catch (e) {
                        // Last resort: use Prague default
                        if (mounted) {
                          setState(() {
                            _userPosition = lat_long.LatLng(50.0755, 14.4378);
                            _isLocationLoaded = true;
                            _hasInitialLocation = true;
                          });
                          _mapController.move(_userPosition, 16.0);
                          _rebuildMarkers();
                        }
                      }
                  },
                  child: const Text("Přeskočit (Praha)", style: TextStyle(color: Colors.white70)),
                )
              ],
            ),
          ),
        );
     }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text("GeoHunt Mapa", style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false, 
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isSimulatingPlayer ? "Simulace hráče ZAPNUTA (15 nejbližších)" : "Simulace hráče VYPNUTA (Všechny kešky)")));
               },
             ),
          IconButton(
            icon: const Icon(Icons.cloud_download, color: Colors.white),
            tooltip: 'Stáhnout offline data',
            onPressed: _downloadOfflineData,
          ),
        ],
      ),
      
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition,
              initialZoom: 16.0,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            // nonRotatedChildren removed - no attribution watermark
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
            ], // Removed duplicate attribution
          ),
          
          // Kompas vlevo dole (nad FAB nebo vedle)
          Positioned(
            bottom: 40,
            left: 20,
            child: Consumer<NavigationManager>(
              builder: (context, nav, child) {
                 if (nav.isNavigating) return const SizedBox.shrink();
                 return CompassWidget(
                    userPosition: _userPosition,
                    availableCaches: _availableCaches
                 );
              },
            ),
          ),
          
          // Loading Overlay - Show when caches are loading
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.teal),
                      SizedBox(height: 20),
                      Text("Načítání kešek...", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
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

  void _showResetDialog(CacheModel cache) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resetovat kešku", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        content: Text("Opravdu chcete resetovat stav kešky '${cache.displayName}'? Bude opět uzamčena.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Zrušit")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx); // Close Dialog
              
              try {
                await _cacheRepository.resetCache(cache.id);
                
                // Immediately update local state for instant UI refresh
                if (mounted) {
                  setState(() {
                    // Find and update the cache in the list
                    final index = _availableCaches.indexWhere((c) => c.id == cache.id);
                    if (index != -1) {
                      _availableCaches[index] = _availableCaches[index].copyWith(isUnlocked: false);
                    }
                    // Rebuild markers to show locked icon
                    _rebuildMarkers();
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Keška byla resetována."),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Chyba při resetování: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Resetovat"),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(CacheModel cache) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Smazat kešku", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        content: Text("Opravdu chcete smazat kešku '${cache.displayName}'? Tato akce je nevratná.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Zrušit")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Implement delete in repository
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mazání zatím není implementováno.")));
            },
            child: const Text("Smazat"),
          ),
        ],
      ),
    );
  }
}