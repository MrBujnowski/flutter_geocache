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
  Future<List<CacheModel>> getAvailableCaches() async {
    // Hybridní logika: 
    // 1. Primárně vracíme data z lokální DB (rychlé, offline-ready).
    // 2. Pokud je lokální DB prázdná a jsme online, zkusíme fetch (falback).
    
    // Načteme lokální cache
    List<CacheModel> caches = await _offlineService.getAllCaches();
    
    // Check if we need to fetch from server
    if (await _isOnline) {
       final userId = _supabase.auth.currentUser?.id;
       if (userId != null) {
          try {
            // Získáme aktuální polohu pro filtrování
            // Poznámka: v reálné aplikaci bychom měli polohu předat jako argument,
            // ale Repository by nemělo přímo záviset na Geolocatoru pokud to není nutné.
            // Zde pro zjednodušení použijeme poslední známou nebo default.
             
             // TODO: Pro správnou funkčnost '5 nejbližších' potřebujeme user coordinates.
             // Jelikož metoda getAvailableCaches je bez argumentů, musíme to vyřešit jinak.
             // Možnosti: 
             // 1. Změnit signaturu metody (breaking change).
             // 2. Získat polohu zde (Geolocator).
             
             // Zkusíme variantu 2, pokud selže, fallback na offline.
             // Import geolocator je potřeba přidat, pokud tu není.
             // Ale wait, Repository by nemělo dělat UI permissions.
             // Předpokládáme, že permissions už jsou.
             
             /* 
                Vylepšení: Místo volání RPC v 'getAvailableCaches' (což je inicializační load),
                bychom měli mít metodu 'refreshCaches(LatLng position)'.
                Ale pro teď:
             */
             
             // Volání RPC get_visible_caches
             // Potřebujeme params: user_lat, user_lon, user_id
             // Pokud nemáme polohu, nemůžeme volat RPC efektivně pro hráče.
             
             // DOČASNÉ ŘEŠENÍ: Pokud je DB prázdná, stáhneme ALL (jako dřív), 
             // ALE s vědomím, že to může být drahé.
             // A "Filtering" udělá server nebo klient?
             // Zadání znělo: "normální hráč může vidět jenom 5 nejbližších".
             // To implikuje Server-Side filtering.
             
             // Takže musíme volat RPC.
          } catch (e) {
             print('Error fetching visible caches: $e');
          }
       }
    }
    
    // PŮVODNÍ IMPLEMENTACE (modifikovaná):
    if (caches.isEmpty && (await _isOnline)) {
       try {
          // Zde je problém: downloadAllCaches stahuje VŠE (78k).
          // Pokud je uživatel 'player', neměl by mít všechno v lokální DB?
          // NEBO: Má všechno v DB (pro offline), ale ZOBRAZÍ se mu jen 5?
          // Zadání: "normální hráč může vidět jenom 5 nejbližších".
          // "vidět" = na mapě.
          // Pokud je to "vidět na mapě", můžeme filtrovat v UI (MapScreen).
          // Ale bezpečnější je filtrovat data.
          
          // Pokud chceme aby "viděl" jen 5, tak downloadAllCaches je pro něj zakázané/omezené?
          // Uživatel zadal v bodě 1: "Ensure all ~78,000 caches ... can be downloaded".
          // Takže data MÁME. Jen je neukazujeme všechny naraz.
          
          await downloadAllCaches();
          caches = await _offlineService.getAllCaches();
       } catch (_) {}
    }

    if (await _isOnline) {
       // Sync logs...
       final userId = _supabase.auth.currentUser?.id;
       if (userId != null) {
          final myLogs = await _supabase.from('logs').select('cache_id').eq('user_id', userId);
          final foundIds = (myLogs as List).map((l) => l['cache_id'] as String).toSet();
          caches = caches.map((c) => c.copyWith(isUnlocked: foundIds.contains(c.id) || c.isUnlocked)).toList();
       }
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
     // _offlineService.deleteCache(cacheId); // To-do implementation
     // Zatím jen reload
  }

  @override
  Future<List<String>> unlockCache(String cacheId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return []; 

    if (await _isOnline) {
      try {
        await _supabase.from('logs').insert({
          'user_id': userId,
          'cache_id': cacheId,
        });
        // Check achievements
        return await _achievementRepo.checkAndUnlockAchievements(currentCacheId: cacheId);
      } catch (e) {
         // Síťová chyba při unlocku -> Uložit offline
         await _offlineService.saveOfflineLog(userId, cacheId);
         return []; // V offline režimu achievementy hned nevrátíme
      }
    } else {
       // Jsme offline -> Uložit offline
       await _offlineService.saveOfflineLog(userId, cacheId);
       return [];
    }
  }

  @override
  Future<void> resetCache(String cacheId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    if (await _isOnline) {
       await _supabase
        .from('logs')
        .delete()
        .eq('user_id', userId)
        .eq('cache_id', cacheId);
    }
  }

  Future<List<Map<String, dynamic>>> getLogsForCache(String cacheId) async {
    if (!(await _isOnline)) return []; // Offline logbook zatím nepodporujeme (jen online)

    final response = await _supabase
        .from('logs')
        .select('found_at, profiles(username)')
        .eq('cache_id', cacheId)
        .order('found_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
}