import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

/// Abstraktní rozhraní pro práci s daty geocache.
/// Definuje metody, které musí implementovat jakákoliv datová vrstva (Supabase/Mock).
abstract class CacheRepository {
  /// Získá všechny geocache, které jsou aktuálně dostupné.
  Future<List<CacheModel>> getAvailableCaches();

  /// Loguje, že uživatel úspěšně odemkl cache s daným ID.
  /// (Později se propojí se Supabase)
  Future<void> unlockCache(String cacheId);
}