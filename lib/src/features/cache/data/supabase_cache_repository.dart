import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

class SupabaseCacheRepository implements CacheRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<List<CacheModel>> getAvailableCaches() async {
    final userId = _supabase.auth.currentUser?.id;

    // 1. Stáhneme všechny kešky
    final List<dynamic> cachesData = await _supabase
        .from('geocaches')
        .select();

    // 2. Stáhneme seznam ID kešek, které už tento uživatel našel (z tabulky logs)
    final List<dynamic> myLogs = userId != null 
        ? await _supabase.from('logs').select('cache_id').eq('user_id', userId)
        : [];
    
    final Set<String> foundCacheIds = myLogs.map((log) => log['cache_id'] as String).toSet();

    // 3. Mapování JSONu na naše modely
    return cachesData.map((data) {
      return CacheModel(
        id: data['id'],
        name: data['name'],
        hint: data['hint'] ?? 'Žádná nápověda',
        // Supabase vrací čísla, LatLng potřebuje double
        position: LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        ),
        // Zkontrolujeme, zda je ID v seznamu nalezených
        isUnlocked: foundCacheIds.contains(data['id']),
      );
    }).toList();
  }

  @override
  Future<void> unlockCache(String cacheId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return; // Nemůžeme logovat, pokud není uživatel přihlášen

    // Vložíme záznam do tabulky logs
    // Díky unique(user_id, cache_id) v SQL se nemůže stát, že by ji našel 2x
    await _supabase.from('logs').insert({
      'user_id': userId,
      'cache_id': cacheId,
      // found_at se doplní automaticky díky defaultu v SQL
    });
  }
}