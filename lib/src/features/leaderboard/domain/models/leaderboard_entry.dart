class LeaderboardEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int findsCount;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.findsCount,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id']?.toString() ?? '', 
      username: json['username']?.toString() ?? 'Neznámý lovec',
      avatarUrl: json['avatar_url']?.toString(),
      findsCount: (json['caches_found'] as num?)?.toInt() ?? 0,
    );
  }
}
