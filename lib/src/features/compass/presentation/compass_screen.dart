import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_geocache/src/core/utils/distance_calculator.dart' as dist_calc;
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

class CompassScreen extends StatefulWidget {
  static const String routeName = '/compass';

  final CacheModel targetCache;

  const CompassScreen({super.key, required this.targetCache});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
     const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    
    // Posloucháme změny polohy pro přesný výpočet vzdálenosti
    Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) {
      if (mounted) {
        setState(() {
          _userPosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pokud nemáme polohu, nemůžeme počítat
    if (_userPosition == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        double heading = 0;
        bool hasCompass = false;

        if (snapshot.hasData && snapshot.data?.heading != null) {
          heading = snapshot.data!.heading!;
          hasCompass = true;
        }

        // Výpočty
        final targetBearing = dist_calc.DistanceCalculator.calculateBearing(_userPosition!, widget.targetCache.position);
        double diff = targetBearing - heading;
        // Normalizace na -180 až +180
        diff = (diff + 180) % 360 - 180;
        
        final distance = dist_calc.DistanceCalculator.calculateDistance(_userPosition!, widget.targetCache.position);

        // Dynamická barva pozadí podle odchylky (0 = sytě zelená, 180 = černá)
        final backgroundColor = _getDynamicBackgroundColor(diff.abs());

        return Scaffold(
          backgroundColor: backgroundColor, 
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(widget.targetCache.displayName, style: const TextStyle(color: Colors.white)),
          ),
          extendBodyBehindAppBar: true,
          body: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand, // Zajistí, že Stack zabere celou obrazovku
            children: [
              // 1. Kruhy / Radar efekt (dekorace) - vždy uprostřed
              if (hasCompass) ...[
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12, width: 2),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                ),
              ],

              // 2. Hlavní šipka nebo Chybová hláška - vždy uprostřed
              Center(
                child: hasCompass
                    ? Transform.rotate(
                        angle: diff * (math.pi / 180), // Rotace k cíli
                        child: const Icon(
                          Icons.navigation, // Nebo custom SVG šipka
                          size: 150,
                          color: Colors.white,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_disabled, size: 80, color: Colors.white54),
                          const SizedBox(height: 16),
                          const Text(
                            'Kompas nedostupný',
                            style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Vaše zařízení nemá magnetometr\nnebo je vypnutý.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white30, fontSize: 14),
                          ),
                        ],
                      ),
              ),

              // 3. Informační texty (vzdálenost) - dole
              Positioned(
                bottom: 80, 
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      distance > 1000
                          ? '${(distance / 1000).toStringAsFixed(1)} km'
                          : '${distance.toStringAsFixed(0)} m',
                      style: const TextStyle(
                        fontSize: 64, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                      ),
                    ),
                    const Text('VZDÁLENOST K CÍLI', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getDynamicBackgroundColor(double deviation) {
    // deviation je 0 až 180.
    // 0 -> Green
    // 180 -> Black/DarkBlue

    // Interpolace: 
    // ratio 0.0 (přesně) -> 1.0 (úplně mimo)
    final ratio = deviation / 180.0; // 0.0 až 1.0

    // Mícháme zelenou (cílovou) a černou (mimo)
    // Použijeme Color.lerp
    return Color.lerp(Colors.green[800]!, const Color(0xFF101010), ratio) ?? Colors.black;
  }
}
