import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';
import 'package:latlong2/latlong.dart';

/// Mock implementace CacheRepository.
class MockCacheRepository implements CacheRepository {
  // Statický seznam cache bodů v okolí Prahy
  static const List<CacheModel> _mockCaches = [
    CacheModel(
      id: 'cache_praha_001',
      name: 'Karlův Most',
      hint: 'Hledej u třetí lampy vlevo.',
      position: LatLng(50.0864, 14.4116), // Karlův most
    ),
    CacheModel(
      id: 'cache_praha_002',
      name: 'Staroměstské náměstí',
      hint: 'Pod orlojem',
      position: LatLng(50.0874, 14.4214), // Staroměstské náměstí
    ),
    CacheModel(
      id: 'cache_praha_003',
      name: 'Petřínská věž',
      hint: 'Vysoká, železná konstrukce.',
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
  Future<void> unlockCache(String cacheId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _unlockedCacheIds.add(cacheId);
  }
}