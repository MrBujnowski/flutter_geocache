import 'package:flutter/material.dart';
import '../../achievements/data/supabase_achievement_repository.dart';
import '../../achievements/domain/models/achievement.dart';

class AchievementsScreen extends StatelessWidget {
  static const String routeName = '/achievements';

  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Pro jednoduchost instancujeme repository tady, 
    // ideálně bychom to měli v Provideru, ale to už je detail.
    final repo = SupabaseAchievementRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Úspěchy'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Achievement>>(
        future: repo.getAchievements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Chyba načítání: ${snapshot.error}'));
          }

          final achievements = snapshot.data ?? [];
          if (achievements.isEmpty) {
            return const Center(child: Text('Žádné achievementy k dispozici.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final ach = achievements[index];
              return Card(
                color: ach.isUnlocked ? Colors.teal.shade50 : Colors.grey.shade200,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ach.isUnlocked ? Colors.amber : Colors.grey,
                    child: Icon(
                      _getIcon(ach.iconName),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    ach.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: ach.isUnlocked ? null : TextDecoration.none, // Případně přeškrtnutí?
                      color: ach.isUnlocked ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Text(ach.description),
                  trailing: ach.isUnlocked
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.lock, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'star': return Icons.star;
      case 'explore': return Icons.explore;
      case 'dark_mode': return Icons.dark_mode;
      case 'terrain': return Icons.terrain;
      // Nové ikony
      case 'wb_sunny': return Icons.wb_sunny;
      case 'restaurant': return Icons.restaurant;
      case 'replay': return Icons.replay;
      case 'weekend': return Icons.weekend;
      case 'bedtime': return Icons.bedtime;
      default: return Icons.emoji_events;
    }
  }
}
