import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';
import 'package:flutter_geocache/src/features/achievements/data/supabase_achievement_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_cache_service.dart';

class SupabaseCacheRepository implements CacheRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _achievementRepo = SupabaseAchievementRepository();
  final _offlineService = OfflineCacheService();

  Future<bool> get _isOnline async {
     final connectivityResult = await (Connectivity().checkConnectivity());
     return !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Synchronizuje čekající offline logy se serverem
  Future<void> syncPendingLogs() async {
     if (!(await _isOnline)) return;

     final pendingLogs = await _offlineService.getPendingLogs();
     if (pendingLogs.isEmpty) return;

     final List<int> processedIds = [];

     for (var log in pendingLogs) {
       try {
         await _supabase.from('logs').insert({
           'user_id': log['user_id'],
           'cache_id': log['cache_id'],
           'found_at': log['found_at'], // Supabase akceptuje ISO string
         });
         
         // Pokud úspěšně, odemkneme i achievementy (zpětně)
         await _achievementRepo.checkAndUnlockAchievements(currentCacheId: log['cache_id'] as String);
         
         processedIds.add(log['id'] as int);
       } catch (e) {
         print("Chyba při syncu logu ${log['id']}: $e");
         // Pokud je to duplicate key error, taky označíme jako processed
         if (e.toString().contains('duplicate key')) {
            processedIds.add(log['id'] as int);
         }
       }
     }

     if (processedIds.isNotEmpty) {
       await _offlineService.clearPendingLogs(processedIds);
     }
  }

  /// Stáhne všechny kešky (nebo velký blok) do offline DB.
  /// Toto volá uživatel stiskem tlačítka "Stáhnout data".
  Future<int> downloadAllCaches() async {
    if (!(await _isOnline)) throw Exception("Bez internetu nelze stahovat data.");

    // 1. Zjistíme celkový počet kešek
    final countResponse = await _supabase
        .from('geocaches')
        .count(CountOption.exact);
    
    final int totalCount = countResponse;

    // 2. Stahujeme po dávkách (stránkování)
    const int batchSize = 1000;
    int downloaded = 0;

    // Progres bar bychom ideálně reportovali přes Stream, ale zatím jen čekáme
    
    for (int i = 0; i < totalCount; i += batchSize) {
      final response = await _supabase
          .from('geocaches')
          .select()
          .range(i, i + batchSize - 1);
      
      final List<CacheModel> caches = (response as List).map((data) => _mapJsonToCache(data)).toList();
      await _offlineService.saveCaches(caches);
      downloaded += caches.length;
    }
    
    return downloaded;
  }

  CacheModel _mapJsonToCache(Map<String, dynamic> data) {
      return CacheModel(
        id: data['id'],
        code: data['code'] ?? 'N/A',
        type: data['type'] ?? 'Unknown',
        difficulty: (data['difficulty'] as num?)?.toDouble() ?? 1.0,
        terrain: (data['terrain'] as num?)?.toDouble() ?? 1.0,
        position: LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        ),
        isUnlocked: false, // Default false, unlock stav se řeší jinde
      );
  }

  @override
  // Ratings
  Future<double> getAverageRating(String cacheId) async {
    try {
      final response = await _supabase
          .from('cache_reviews')
          .select('rating')
          .eq('cache_id', cacheId);
          
      if (response == null || (response as List).isEmpty) return 0.0;
      
      final list = response as List;
      final sum = list.fold<int>(0, (prev, elem) => prev + (elem['rating'] as int));
      return sum / list.length;
    } catch (e) {
      // Table might not exist yet
      return 0.0;
    }
  }
  
  Future<List<Map<String, dynamic>>> getReviews(String cacheId) async {
      print("🔍 getReviews called for cache: $cacheId");
      try {
          // Remove created_at from select AND order to avoid ambiguous column error
          // (both cache_reviews and profiles have created_at)
          final response = await _supabase
             .from('cache_reviews')
             .select('rating, comment, profiles(username)')
             .eq('cache_id', cacheId)
             .limit(10);  // Removed .order() - it was causing ambiguous column error
          
          print("✅ Reviews response: $response");
          print("📊 Reviews count: ${(response as List).length}");
          
          final reviewsList = List<Map<String, dynamic>>.from(response);
          print("📝 Parsed reviews: $reviewsList");
          
          return reviewsList;
      } catch (e) {
          print("❌ Error fetching reviews: $e");
          return [];
      }
  }

  Future<void> addReview(String cacheId, int rating, String comment) async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in");
      
      // Check if review exists (handle inconsistent state with limit(1))
      final existingResponse = await _supabase
          .from('cache_reviews')
          .select('id')
          .eq('user_id', userId)
          .eq('cache_id', cacheId)
          .limit(1)
          .maybeSingle();

      if (existingResponse != null) {
         // Update existing
         await _supabase.from('cache_reviews').update({
            'rating': rating,
            'comment': comment,
         }).eq('id', existingResponse['id']);
      } else {
         // Insert new
         await _supabase.from('cache_reviews').insert({
            'cache_id': cacheId,
            'user_id': userId,
            'rating': rating,
            'comment': comment,
         });
      }
  }

  bool _initialSyncDone = false;

  Future<void> _syncWithServer() async {
      if (_initialSyncDone || !(await _isOnline)) return;
      
      try {
          // 1. Fetch all server IDs
          final response = await _supabase.from('geocaches').select('id');
          final serverIds = (response as List).map((e) => e['id'] as String).toSet();
          
          // 2. Fetch all local IDs
          final localCaches = await _offlineService.getAllCaches();
          final localIds = localCaches.map((c) => c.id).toSet();
          
          // 3. Find deleted (in Local but not Server)
          final deletedIds = localIds.difference(serverIds);
          for (final id in deletedIds) {
              await _offlineService.deleteCache(id);
          }
          
          // 4. Find new (in Server but not Local) - Optional: Auto-download?
          // For now, we rely on manual "Download" for bulk data, 
          // but if we want to be consistent, we should perhaps download them.
          // Given 78k scale, we skip auto-download of huge data here 
          // to avoid "Freezing" on start. User can press "Download Data".
          
          _initialSyncDone = true;
      } catch (e) {
          print("Sync error: $e");
      }
  }

  @override
  Future<List<CacheModel>> getAvailableCaches() async {
    // Load Local data FIRST - NO BLOCKING OPERATIONS!
    List<CacheModel> caches = await _offlineService.getAllCaches();
    
    print("📦 Loaded ${caches.length} caches from local DB");
    
    // No sync, no auto-download - keep it FAST!
    // User can manually download via "Download" button if needed
    
    // Apply Logs (Unlock State) - this is fast
    if (await _isOnline) {
       final userId = _supabase.auth.currentUser?.id;
       if (userId != null) {
          try {
            // Fetch Server Logs
            final myLogs = await _supabase.from('logs').select('cache_id').eq('user_id', userId);
            final foundIds = (myLogs as List).map((l) => l['cache_id'] as String).toSet();
            
            // Fetch Offline Pending Logs
            final pendingLogs = await _offlineService.getPendingLogs();
            final pendingIds = pendingLogs.map((l) => l['cache_id'] as String).toSet();
            
            final allFoundIds = foundIds.union(pendingIds);

            // Update cache state
            caches = caches.map((c) => c.copyWith(isUnlocked: allFoundIds.contains(c.id))).toList();
          } catch (e) {
            print("Error fetching logs: $e");
          }
       }
    } else {
        // Offline: Trust Local DB + Pending Logs
        final pendingLogs = await _offlineService.getPendingLogs();
        final pendingIds = pendingLogs.map((l) => l['cache_id'] as String).toSet();
        caches = caches.map((c) => c.copyWith(isUnlocked: c.isUnlocked || pendingIds.contains(c.id))).toList();
    }

    return caches;
  }
  
  // Přidáme novou metodu pro filtrování podle role
  Future<bool> isAdmin(String userId) async {
      final data = await _supabase.from('profiles').select('role').eq('id', userId).maybeSingle();
      return data?['role'] == 'admin';
  }
  
  Future<void> deleteCache(String cacheId) async {
     // Smazat z DB (lokální i server)
     if (await _isOnline) {
        await _supabase.from('geocaches').delete().eq('id', cacheId);
     }
     // Smazat lokálně
     await _offlineService.deleteCache(cacheId);
  }

  @override
  Future<List<String>> unlockCache(String cacheId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return []; 
    // ... logic remains ...
    if (await _isOnline) {
      try {
        await _supabase.from('logs').insert({
          'user_id': userId,
          'cache_id': cacheId,
        });
        return await _achievementRepo.checkAndUnlockAchievements(currentCacheId: cacheId);
      } catch (e) {
         await _offlineService.saveOfflineLog(userId, cacheId);
         return []; 
      }
    } else {
       await _offlineService.saveOfflineLog(userId, cacheId);
       return [];
    }
  }

  @override
  Future<void> resetCache(String cacheId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print("Reset failed: No user logged in");
      return;
    }
    
    print("Resetting cache $cacheId for user $userId");
    
    // 1. Reset Local
    await _offlineService.lockCache(cacheId);
    print("Local cache locked");

    // 2. Reset Server
    if (await _isOnline) {
       try {
         await _supabase
          .from('logs')
          .delete()
          .eq('user_id', userId)
          .eq('cache_id', cacheId);
         print("Server log deleted successfully");
       } catch (e) {
         print("Reset error: $e");
         rethrow;
       }
    } else {
      print("Offline - skipping server reset");
    }
  }

  Future<List<Map<String, dynamic>>> getLogsForCache(String cacheId) async {
    if (!(await _isOnline)) return []; 

    final response = await _supabase
        .from('logs')
        .select('found_at, profiles(username)')
        .eq('cache_id', cacheId)
        .order('found_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
}