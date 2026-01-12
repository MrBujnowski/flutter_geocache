import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_geocache/src/core/utils/distance_calculator.dart' as dist_calc;
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';
import 'package:flutter_geocache/src/features/compass/presentation/compass_screen.dart';

class CompassWidget extends StatelessWidget {
  final LatLng userPosition;
  final List<CacheModel> availableCaches;

  const CompassWidget({
    super.key,
    required this.userPosition,
    required this.availableCaches,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Najít nejbližší neodemčenou kešku
    CacheModel? targetCache;
    double minDistance = double.infinity;

    for (final cache in availableCaches) {
      if (!cache.isUnlocked) {
        final dist = dist_calc.DistanceCalculator.calculateDistance(userPosition, cache.position);
        if (dist < minDistance) {
          minDistance = dist;
          targetCache = cache;
        }
      }
    }

    if (targetCache == null) {
      return const SizedBox.shrink(); // Žádný cíl -> nezobrazovat kompas
    }

    // 2. Stream kompasu
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.heading == null) {
          // Na Windows/simulatoru může být null -> zobrazíme jen vzdálenost bez rotace
          return _buildCompassCard(context, 0, minDistance, targetCache, isError: true);
        }

        final heading = snapshot.data!.heading!; // 0-360 stupňů (sever)
        final targetBearing = dist_calc.DistanceCalculator.calculateBearing(userPosition, targetCache!.position);
        
        // Vypočítat rozdíl, o kolik se má šipka otočit, aby ukazovala k cíli.
        // Kompas ukazuje sever. My chceme, aby 0° (nahoru) na widgetu ukazovalo k cíli.
        // Takže rotace šipky = (Bearing k cíli) - (Heading zařízení).
        double diff = targetBearing - heading;
        // Normalizace na -180 až 180 pro nejkratší rotaci
        diff = (diff + 180) % 360 - 180;

        return _buildCompassCard(context, diff, minDistance, targetCache);
      },
    );
  }

  Widget _buildCompassCard(
    BuildContext context, 
    double rotationDeg, 
    double distance, 
    CacheModel? targetCache,
    {bool isError = false}
  ) {
    return GestureDetector(
      onTap: () {
        if (targetCache != null) {
          Navigator.of(context).pushNamed(
            CompassScreen.routeName,
            // Předáme argumenty pro CompassScreen (mohli bychom je brát z Provideru, ale statické předání je zde jednodušší)
            arguments: {
              'targetCache': targetCache,
              'initialDistance': distance,
              'initialUserPosition': userPosition, // Pass current position
            }
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rotující šipka
            Transform.rotate(
              angle: isError ? 0 : (rotationDeg * (math.pi / 180)), // Pouze jedna angle definice
              child: Icon(
                isError ? Icons.location_disabled : Icons.navigation,
                color: isError ? Colors.grey : _getColorForDeviation(rotationDeg),
                size: 32,
              ),
            ),
            const SizedBox(height: 4),
                Text(
                  distance > 1000 
                      ? '${(distance / 1000).toStringAsFixed(1)} km' 
                      : '${distance.toStringAsFixed(0)} m',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
          ],
        ),
      ),
    );
  }

  Color _getColorForDeviation(double deviation) {
    if (deviation.abs() < 20) return Colors.greenAccent;
    if (deviation.abs() < 45) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }
}
