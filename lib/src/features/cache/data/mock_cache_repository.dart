import 'package:flutter_geocache/src/features/cache/domain/cache_repository.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

class MockCacheRepository implements CacheRepository {
  @override
  Future<List<CacheModel>> getAvailableCaches() async {
    return [];
  }

  @override
  Future<List<String>> unlockCache(String cacheId) async {
    return [];
  }

  @override
  Future<void> resetCache(String cacheId) async {}
  
  @override
  Future<double> getAverageRating(String cacheId) async => 4.5; // Mock rating

  @override
  Future<List<Map<String, dynamic>>> getReviews(String cacheId) async => [];

  @override
  Future<void> addReview(String cacheId, int rating, String comment) async {}
}