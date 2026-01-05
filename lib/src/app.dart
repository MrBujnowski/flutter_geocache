import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importy tvých vlastních souborů
import 'features/splash/presentation/splash_screen.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/compass/presentation/compass_screen.dart'; // Import nového screenu
import 'features/auth/presentation/auth_screen.dart';

import 'package:provider/provider.dart';
import 'features/cache/domain/cache_repository.dart';
import 'features/cache/data/supabase_cache_repository.dart';
import 'features/cache/presentation/logbook_screen.dart';
import 'features/leaderboard/domain/leaderboard_repository.dart';
import 'features/leaderboard/data/supabase_leaderboard_repository.dart';
import 'features/leaderboard/presentation/leaderboard_screen.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/achievements/presentation/achievements_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/application/settings_service.dart';
import 'features/map/application/navigation_manager.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // POZNÁMKA: AppTheme musela být vytvořena samostatně
    // Používáme zde jen placeholder pro Theme, pokud není definován AppTheme.
    final lightTheme = ThemeData.light(useMaterial3: true);
    final darkTheme = ThemeData.dark(useMaterial3: true);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        Provider<CacheRepository>(
          create: (_) => SupabaseCacheRepository(),
        ),
        Provider<LeaderboardRepository>(
          create: (_) => SupabaseLeaderboardRepository(),
        ),
        Provider<ProfileRepository>(
          create: (_) => ProfileRepository(),
        ),
        ChangeNotifierProvider(create: (_) => NavigationManager()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'GeoHunt',
            debugShowCheckedModeBanner: false,
            
            theme: lightTheme, 
            darkTheme: darkTheme, 
            themeMode: settings.themeMode, // Dynamický režim
            
            home: const AuthGuard(), 
          
            routes: {
              SplashScreen.routeName: (context) => const SplashScreen(),
              MapScreen.routeName: (context) => const MapScreen(),
              GameScreen.routeName: (context) => const GameScreen(),
              AuthScreen.routeName: (context) => const AuthScreen(),
              LeaderboardScreen.routeName: (context) => const LeaderboardScreen(),
              ProfileScreen.routeName: (context) => const ProfileScreen(),
              CompassScreen.routeName: (context) {
                 final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                 return CompassScreen(
                   targetCache: args['targetCache'],
                 );
              },
              EditProfileScreen.routeName: (context) => const EditProfileScreen(),
              AchievementsScreen.routeName: (context) => const AchievementsScreen(),
              SettingsScreen.routeName: (context) => const SettingsScreen(),
              // Logbook Route s argumenty
              LogbookScreen.routeName: (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return LogbookScreen(
                  cacheId: args['cacheId'], 
                  cacheName: args['cacheName']
                );
              },
            },
          );
        },
      ),
    );
  }
}

// Speciální widget pro kontrolu autentizace
class AuthGuard extends StatelessWidget {
const AuthGuard({super.key});

// Stream, který sleduje, zda se uživatel přihlásil/odhlásil
Stream<AuthState> get _authStream => Supabase.instance.client.auth.onAuthStateChange;

@override
Widget build(BuildContext context) {
// Sledujeme stav Supabase
return StreamBuilder<AuthState>(
stream: _authStream,
builder: (context, snapshot) {

    // Stav 1: Čekání na první stav Auth po inicializaci
    if (snapshot.connectionState == ConnectionState.waiting) {
        // Místo SplashScreenu (který má časovač) zobrazíme jen loading
        return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Colors.teal),
            ),
        );
    }

    // Stav 2: Kontrola, zda je uživatel přihlášen (session je platná)
    final bool isSignedIn = snapshot.data?.session?.user != null;

    if (isSignedIn) {
      // Pokud je přihlášen, jdeme rovnou na Mapu
      return const MapScreen();
    } else {
      // Pokud není přihlášen, jdeme na Login obrazovku
      return const AuthScreen();
    }
  },
);


}
}