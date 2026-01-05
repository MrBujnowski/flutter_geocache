import 'models/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> getDailyLeaderboard();
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard();
  Future<List<LeaderboardEntry>> getAllTimeLeaderboard();
}
