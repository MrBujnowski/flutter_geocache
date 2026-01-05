import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/models/cache_model.dart';
import 'dart:convert';

class OfflineCacheService {
  static const String _dbName = 'geocache_offline.db';
  static const int _version = 1;

  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError("SQLite is not supported on Web");
    }
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    // ... same as before
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        // Tabulka pro kešky
        await db.execute('''
          CREATE TABLE caches (
            id TEXT PRIMARY KEY,
            latitude REAL,
            longitude REAL,
            code TEXT,
            type TEXT,
            difficulty REAL,
            terrain REAL,
            is_unlocked INTEGER
          )
        ''');

        // Tabulka pro offline logy (čekající na sync)
        await db.execute('''
          CREATE TABLE offline_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cache_id TEXT,
            user_id TEXT,
            found_at TEXT
          )
        ''');
      },
    );
  }

  // --- METHODS FOR CACHES ---

  Future<void> saveCaches(List<CacheModel> caches) async {
    if (kIsWeb) return; // No-op on web
    final db = await database;
    final batch = db.batch();

    for (var cache in caches) {
      batch.insert(
        'caches',
        {
          'id': cache.id,
          'latitude': cache.position.latitude,
          'longitude': cache.position.longitude,
          'code': cache.code,
          'type': cache.type,
          'difficulty': cache.difficulty,
          'terrain': cache.terrain,
          'is_unlocked': cache.isUnlocked ? 1 : 0, 
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CacheModel>> getCachesInBounds(LatLng southWest, LatLng northEast) async {
    if (kIsWeb) return []; // Empty list on web
    final db = await database;
    final result = await db.query(
      'caches',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [southWest.latitude, northEast.latitude, southWest.longitude, northEast.longitude],
      limit: 500, 
    );

    return result.map(_mapRowToCache).toList();
  }

  Future<List<CacheModel>> getAllCaches() async {
    if (kIsWeb) return []; // Empty on web
    final db = await database;
    final result = await db.query('caches');
    return result.map(_mapRowToCache).toList();
  }

  // --- METHODS FOR LOGS ---

  Future<void> saveOfflineLog(String userId, String cacheId) async {
    if (kIsWeb) return; // No-op
    final db = await database;
    await db.insert('offline_logs', {
      'user_id': userId,
      'cache_id': cacheId,
      'found_at': DateTime.now().toIso8601String(),
    });
    
    await db.update(
      'caches',
      {'is_unlocked': 1},
      where: 'id = ?',
      whereArgs: [cacheId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingLogs() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('offline_logs');
  }

  Future<void> clearPendingLogs(List<int> ids) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
        'offline_logs', 
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids
    );
  }

  CacheModel _mapRowToCache(Map<String, dynamic> row) {
    return CacheModel(
      id: row['id'] as String,
      position: LatLng(row['latitude'] as double, row['longitude'] as double),
      code: row['code'] as String,
      type: row['type'] as String,
      difficulty: row['difficulty'] as double,
      terrain: row['terrain'] as double,
      isUnlocked: (row['is_unlocked'] as int) == 1,
    );
  }
}
