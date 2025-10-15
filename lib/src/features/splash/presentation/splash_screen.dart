<<<<<<< HEAD
import 'package:flutter/material.dart';
=======
// lib/src/features/splash/presentation/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:async'; // pro použití Timer
import '../../map/presentation/map_screen.dart'; // import MapScreenu
>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

<<<<<<< HEAD
=======
  // Konstanty pro routing, které byste měli ideálně definovat v routeru
  static const String routeName = '/splash';
  static const String nextRoute = MapScreen.routeName;

>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

<<<<<<< HEAD
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

=======
class _SplashScreenState extends State<SplashScreen> {
>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404
  @override
  void initState() {
    super.initState();
    
<<<<<<< HEAD
    // Inicializace animací
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    // Spustit animace
    _animationController.forward();

    // Po 3 sekundách přejít na MapScreen
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/map');
      }
=======
    // Spuštění časovače pro navigaci
    Timer(const Duration(seconds: 3), () {
      // Po 3 sekundách přesunout uživatele na MapScreen
      // (Používáme pushReplacement, aby se uživatel nemohl vrátit zpět)
      Navigator.of(context).pushReplacementNamed(SplashScreen.nextRoute);
>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404
    });
  }

  @override
<<<<<<< HEAD
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
=======
  Widget build(BuildContext context) {
    return Scaffold(
      // Použijte barvy z vaší theme, zde je jen placeholder
      backgroundColor: Colors.blueGrey, 
>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
<<<<<<< HEAD
            // Logo/Icon s animací
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.explore,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 30),
            
            // Název aplikace
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'GeoHunt',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 10),
            
            // Podtitul
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Geocaching Adventure',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 50),
            
            // Loading indikátor
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    strokeWidth: 3,
                  ),
                );
              },
=======
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
>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> fe2b19a1174d637a1fd14c65eb9e84077da34404
