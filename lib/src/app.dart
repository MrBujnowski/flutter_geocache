import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'features/splash/presentation/splash_screen.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/compass/presentation/compass_screen.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/main_screen.dart'; // New Main Screen

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
import 'features/settings/application/settings_service.dart';
import 'features/map/application/navigation_manager.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
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
            themeMode: settings.themeMode,
            
            home: const AuthGuard(), 
          
            routes: {
              SplashScreen.routeName: (context) => const SplashScreen(),
              MainScreen.routeName: (context) => const MainScreen(),
              MapScreen.routeName: (context) => const MapScreen(),
              GameScreen.routeName: (context) => const GameScreen(),
              AuthScreen.routeName: (context) => const AuthScreen(),
              LeaderboardScreen.routeName: (context) => const LeaderboardScreen(),
              ProfileScreen.routeName: (context) => const ProfileScreen(),
              CompassScreen.routeName: (context) {
                 final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                 return CompassScreen(
                   targetCache: args['targetCache'],
                   initialUserPosition: args['initialUserPosition'],
                 );
              },
              EditProfileScreen.routeName: (context) => const EditProfileScreen(),
              AchievementsScreen.routeName: (context) => const AchievementsScreen(),
              SettingsScreen.routeName: (context) => const SettingsScreen(),
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

class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key});

  Stream<AuthState> get _authStream => Supabase.instance.client.auth.onAuthStateChange;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                ),
            );
        }

        final bool isSignedIn = snapshot.data?.session?.user != null;

        if (isSignedIn) {
          return const MainScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}