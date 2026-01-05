import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';
import 'package:latlong2/latlong.dart';

/// Mock implementace CacheRepository.
class MockCacheRepository implements CacheRepository {
  // Statický seznam cache bodů v okolí Prahy
  static const List<CacheModel> _mockCaches = [
    CacheModel(
      id: 'cache_praha_001',
      code: 'CZ-001',
      type: 'Tradiční',
      difficulty: 1.5,
      terrain: 1.5,
      position: LatLng(50.0864, 14.4116), // Karlův most
    ),
    CacheModel(
      id: 'cache_praha_002',
      code: 'CZ-002',
      type: 'Mystery',
      difficulty: 3.0,
      terrain: 2.0,
      position: LatLng(50.0874, 14.4214), // Staroměstské náměstí
    ),
    CacheModel(
      id: 'cache_praha_003',
      code: 'CZ-003',
      type: 'Multi',
      difficulty: 2.5,
      terrain: 3.5,
      position: LatLng(50.0817, 14.3946), // Petřínská rozhledna
    ),
  ];

  final Set<String> _unlockedCacheIds = {};

  @override
  Future<List<CacheModel>> getAvailableCaches() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockCaches.map((cache) {
      return cache.copyWith(isUnlocked: _unlockedCacheIds.contains(cache.id));
    }).toList();
  }

  @override
  Future<List<String>> unlockCache(String cacheId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _unlockedCacheIds.add(cacheId);
    return []; // Mock achievementy
  }

  @override
  Future<void> resetCache(String cacheId) async {
    _unlockedCacheIds.remove(cacheId);
  }
}