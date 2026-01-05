import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_repository.dart';
import '../../auth/presentation/auth_screen.dart';
import 'edit_profile_screen.dart';
import '../../achievements/presentation/achievements_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProfileRepository>();
    final User? user = repo.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Uživatel není přihlášen")));
    }

    // Místo přímého čtení z Auth, budeme data načítat z DB přes FutureBuilder
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil hráče"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // Navigace na editaci
              await Navigator.of(context).pushNamed(EditProfileScreen.routeName);
            },
          ),
        ],
      ),
      body: ProfileContent(repo: repo, user: user),
    );
  }
}

class ProfileContent extends StatefulWidget {
  final ProfileRepository repo;
  final User user;

  const ProfileContent({super.key, required this.repo, required this.user});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  late Future<Map<String, dynamic>?> _profileFuture;
  late Future<int> _findsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _profileFuture = widget.repo.getProfile();
      _findsFuture = widget.repo.getUserFindsCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        // Pokud data ještě nejsou (loading), ale máme uživatele z Auth, můžeme ukázat fallback
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }

        final profileData = snapshot.data;
        // Fallback na Auth metadata, pokud DB profil neexistuje
        final metadata = widget.user.userMetadata ?? {};
        
        final String username = profileData?['username'] 
            ?? metadata['full_name'] 
            ?? metadata['name'] 
            ?? widget.user.email 
            ?? 'Neznámý lovec';
            
        final String? avatarUrl = profileData?['avatar_url'] 
            ?? metadata['avatar_url'] 
            ?? metadata['picture'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Sekce Editace (tlačítko je v AppBaru, ale pro jistotu refresh voláme po návratu)
              
              const SizedBox(height: 10),
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.teal.shade100,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 40, color: Colors.teal),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              
              // Uživatelské jméno
              Text(
                username,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              
              const SizedBox(height: 8),
              Text(
                widget.user.email ?? '',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
              ),

              const SizedBox(height: 12),
              
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (profileData?['role'] == 'admin') ? Colors.redAccent : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (profileData?['role'] == 'admin') ? "ADMINISTRÁTOR" : "HRÁČ",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),

              const SizedBox(height: 40),

              // Statistiky Card
              FutureBuilder<int>(
                future: _findsFuture,
                builder: (context, countSnapshot) {
                  final count = countSnapshot.data ?? 0;
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                      child: Column(
                        children: [
                          const Text("Počet nálezů", style: TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                              const SizedBox(width: 10),
                              Text(
                                "$count",
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 30),
              
              // Sekce Achievementy
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Moje Úspěchy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).pushNamed(AchievementsScreen.routeName);
                },
              ),
              const Divider(),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings, color: Colors.teal),
                title: const Text("Nastavení", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).pushNamed(SettingsScreen.routeName);
                },
              ),
              const Divider(),
              
              const SizedBox(height: 60),

              // Tlačítko odhlásit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                     await widget.repo.signOut();
                     if (context.mounted) {
                       Navigator.of(context).pushNamedAndRemoveUntil(
                         AuthScreen.routeName, 
                         (route) => false
                       );
                     }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text("Odhlásit se"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
