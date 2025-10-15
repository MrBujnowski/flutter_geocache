// lib/src/app.dart

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/map/presentation/map_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoHunt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),

      initialRoute: SplashScreen.routeName,
      routes: {
        // Při startu aplikace uvidí Splash Screen
        SplashScreen.routeName: (context) => const SplashScreen(), 
        // Po 3 sekundách se aplikace přepne sem
        MapScreen.routeName: (context) => const MapScreen(), 
        // Další trasy (např. LoginScreen) budou následovat...
      },
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(), // začínáme se splash screen
      routes: {
        '/map': (context) => const MapScreen(),
      },
    );
  }
}
