import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/leaderboard_repository.dart';
import '../domain/models/leaderboard_entry.dart';

class SupabaseLeaderboardRepository implements LeaderboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<List<LeaderboardEntry>> getDailyLeaderboard() async {
    final response = await _supabase
        .from('leaderboard_daily')
        .select()
        .order('caches_found', ascending: false)
        .limit(50);
    
    return (response as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
  }

  @override
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard() async {
    final response = await _supabase
        .from('leaderboard_monthly')
        .select()
        .order('caches_found', ascending: false)
        .limit(50);

    return (response as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
  }

  @override
  Future<List<LeaderboardEntry>> getAllTimeLeaderboard() async {
    final response = await _supabase
        .from('leaderboard_all_time')
        .select()
        .order('caches_found', ascending: false)
        .limit(50);

    return (response as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
  }
}
