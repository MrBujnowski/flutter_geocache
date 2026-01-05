import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/achievement.dart';

class SupabaseAchievementRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Získá seznam všech achievementů a označí ty, které uživatel má
  Future<List<Achievement>> getAchievements() async {
    final userId = _supabase.auth.currentUser?.id;
    
    // 1. Získáme definice achievementů
    final definitions = await _supabase
        .from('achievements')
        .select()
        .order('points');

    Set<String> unlockedIds = {};
    if (userId != null) {
      final userAchievements = await _supabase
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);
      
      unlockedIds = (userAchievements as List)
          .map((e) => e['achievement_id'] as String)
          .toSet();
    }

    return (definitions as List).map((json) {
      final id = json['id'] as String;
      final unlocked = unlockedIds.contains(id);
      final isSecret = json['secret'] ?? false;
      
      // Tajné achievementy vrátíme jen pokud jsou odemčené
      if (isSecret && !unlocked) {
        return null;
      }

      return Achievement.fromJson(json, unlocked: unlocked);
    }).whereType<Achievement>().toList(); // Odstraníme null hodnoty (skryté achievementy)
  }

  /// Zkontroluje podmínky a případně odemkne nové achievementy.
  /// [currentCacheId] je ID právě nalezené cache (pro Deja Vu check).
  Future<List<String>> checkAndUnlockAchievements({String? currentCacheId}) async {
      return _checkInternal(currentCacheId);
  }

  Future<List<String>> _checkInternal(String? currentCacheId) async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      List<String> newUnlocks = [];

      // 1. Načteme statistiky
      final logsResponse = await _supabase
          .from('logs')
          .select('found_at, cache_id')
          .eq('user_id', userId);
      
      final logs = logsResponse as List;
      final findsCount = logs.length;
      
      // LOGIKA ODEMYKÁNÍ
      // 1. POČTY
      if (findsCount >= 1 && await _unlockIfNotExists(userId, 'first_find')) newUnlocks.add('První úlovek');
      if (findsCount >= 5 && await _unlockIfNotExists(userId, 'explorer')) newUnlocks.add('Průzkumník (5 nálezů)');
      if (findsCount >= 10 && await _unlockIfNotExists(userId, 'pro_hunter')) newUnlocks.add('Profi Lovec');
      if (findsCount >= 20 && await _unlockIfNotExists(userId, 'master')) newUnlocks.add('Vládce Kešek');

      // 2. ČAS A DEN
      final now = DateTime.now();
      final hour = now.hour;
      final weekday = now.weekday;

      if ((hour >= 22 || hour < 4) && await _unlockIfNotExists(userId, 'night_owl')) newUnlocks.add('Noční sova');
      if ((hour >= 2 && hour < 4) && await _unlockIfNotExists(userId, 'insomniac')) newUnlocks.add('Nespavec');
      if ((hour >= 5 && hour < 8) && await _unlockIfNotExists(userId, 'early_bird')) newUnlocks.add('Ranní Ptáče');
      if ((hour >= 11 && hour < 13) && await _unlockIfNotExists(userId, 'lunch_break')) newUnlocks.add('Pauza na Oběd');
      if ((weekday == DateTime.saturday || weekday == DateTime.sunday) && await _unlockIfNotExists(userId, 'weekend_warrior')) newUnlocks.add('Víkendový Bojovník');

      // 3. SPECIAL (Deja Vu)
      if (currentCacheId != null) {
          final visits = logs.where((l) => l['cache_id'] == currentCacheId).length;
          // Pokud je to alespoň druhá návštěva (visits >= 2), je to Deja Vu
          if (visits >= 2) {
             if (await _unlockIfNotExists(userId, 'deja_vu')) newUnlocks.add('Déjà Vu');
          }
      }

      return newUnlocks;
  }

  /// Pomocná metoda pro vložení záznamu, pokud neexistuje
  /// Vrací true, pokud bylo odemčeno (vloženo)
  Future<bool> _unlockIfNotExists(String userId, String achievementId) async {
    // Check if already exists
    final exists = await _supabase
        .from('user_achievements')
        .select()
        .eq('user_id', userId)
        .eq('achievement_id', achievementId)
        .maybeSingle();

    if (exists != null) return false;

    // Insert
    try {
      await _supabase.from('user_achievements').insert({
        'user_id': userId,
        'achievement_id': achievementId,
      });
      return true;
    } catch (e) {
      // Race condition nebo chyba
      return false;
    }
  }
}
