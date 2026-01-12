import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/leaderboard_repository.dart';
import '../domain/models/leaderboard_entry.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const String routeName = '/leaderboard';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Žebříčky"),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Dnes"),
              Tab(text: "Měsíc"),
              Tab(text: "Celkově"),
            ],
            indicatorColor: Colors.amber,
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaderboardTab(period: _LeaderboardPeriod.daily),
            _LeaderboardTab(period: _LeaderboardPeriod.monthly),
            _LeaderboardTab(period: _LeaderboardPeriod.allTime),
          ],
        ),
      ),
    );
  }
}

enum _LeaderboardPeriod { daily, monthly, allTime }

class _LeaderboardTab extends StatelessWidget {
  final _LeaderboardPeriod period;

  const _LeaderboardTab({required this.period});

  Future<List<LeaderboardEntry>> _fetchData(BuildContext context) {
    final repo = context.read<LeaderboardRepository>();
    switch (period) {
      case _LeaderboardPeriod.daily:
        return repo.getDailyLeaderboard();
      case _LeaderboardPeriod.monthly:
        return repo.getMonthlyLeaderboard();
      case _LeaderboardPeriod.allTime:
        return repo.getAllTimeLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _fetchData(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Chyba: ${snapshot.error}"));
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return const Center(child: Text("Zatím žádní lovci!"));
        }

        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isTop3 = index < 3;
            
            // Custom Trophies
            Widget trailingWidget;
            if (index == 0) {
              trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${entry.findsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 5),
                const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28), // Gold
              ]);
            } else if (index == 1) {
              trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${entry.findsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 5),
                const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 26), // Silver
              ]);
            } else if (index == 2) {
              trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${entry.findsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 5),
                const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 24), // Bronze
              ]);
            } else {
              trailingWidget = Text(
                '${entry.findsCount} 📦', // Just Box/Cache icon or nothing
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              );
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isTop3 ? Colors.teal.shade100 : Colors.grey[200],
                backgroundImage: entry.avatarUrl != null ? NetworkImage(entry.avatarUrl!) : null,
                child: entry.avatarUrl == null
                    ? Text('${index + 1}', style: TextStyle(color: Colors.teal.shade900))
                    : null,
              ),
              title: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: trailingWidget,
            );
          },
        );
      },
    );
  }
}
