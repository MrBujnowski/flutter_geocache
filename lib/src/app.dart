import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/map/presentation/map_screen.dart'; // první obrazovka, zatím jen test

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoHunt',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MapScreen(), // zatím jednoduchá testovací obrazovka
    );
  }
}
