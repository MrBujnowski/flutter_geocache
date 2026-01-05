import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/supabase_cache_repository.dart';
import '../domain/cache_repository.dart';
import 'package:intl/intl.dart';

class LogbookScreen extends StatelessWidget {
  static const String routeName = '/logbook';
  final String cacheId;
  final String cacheName;

  const LogbookScreen({super.key, required this.cacheId, required this.cacheName});

  @override
  Widget build(BuildContext context) {
    // Získáme repo. Používám přímý cast nebo provider, záleží na registraci
    // V App.dart je Provider<CacheRepository>, ale zde potřebujeme konkrétní metodu getLogsForCache
    // kterou CacheRepository interface nemá (pokud ji tam nepřidáme).
    // Pro teď přetypujeme.
    final repo = context.read<CacheRepository>() as SupabaseCacheRepository;

    return Scaffold(
      appBar: AppBar(
        title: Text('Logbook: $cacheName'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getLogsForCache(cacheId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Chyba při načítání: ${snapshot.error}'));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
             return const Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.history_edu, size: 60, color: Colors.grey),
                   SizedBox(height: 16),
                   Text("Zatím žádné záznamy. Buďte první!"),
                 ],
               ),
             );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final profile = log['profiles'] ?? {};
              final username = profile['username'] ?? 'Neznámý lovec';
              final foundAtString = log['found_at'] as String;
              final foundAt = DateTime.parse(foundAtString).toLocal();
              final formattedDate = DateFormat('d.M.yyyy H:mm').format(foundAt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?'),
                  ),
                  title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Nalezeno: $formattedDate'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
