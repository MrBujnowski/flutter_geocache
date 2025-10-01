// lib/src/features/splash/presentation/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:async'; // pro použití Timer
import '../../map/presentation/map_screen.dart'; // import MapScreenu

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  // Konstanty pro routing, které byste měli ideálně definovat v routeru
  static const String routeName = '/splash';
  static const String nextRoute = MapScreen.routeName;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Spuštění časovače pro navigaci
    Timer(const Duration(seconds: 3), () {
      // Po 3 sekundách přesunout uživatele na MapScreen
      // (Používáme pushReplacement, aby se uživatel nemohl vrátit zpět)
      Navigator.of(context).pushReplacementNamed(SplashScreen.nextRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Použijte barvy z vaší theme, zde je jen placeholder
      backgroundColor: Colors.blueGrey, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Zde bude ideálně vaše logo
            // Např.: Image.asset('assets/logo.png', height: 100), 
            Icon(
              Icons.map, 
              size: 100, 
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'GeoHunt',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}