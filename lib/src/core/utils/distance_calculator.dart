import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as Math;

/// Třída pro výpočet a ověření geocachingové vzdálenosti.
/// Nachází se v 'core/utils/', protože je to obecná utility pro celou aplikaci.
class DistanceCalculator {
  // Maximální povolená vzdálenost pro odemknutí cache (v metrech).
  // Podle zadání je to 20 metrů.
  static const double unlockRadiusMeters = 20.0;

  /// Vypočítá přesnou vzdálenost (v metrech) mezi dvěma LatLng body
  /// pomocí vestavěného, přesného algoritmu (Haversine/Vincenty) z balíčku geolocator.
  /// 
  /// @param start Počáteční pozice (např. pozice uživatele)
  /// @param end Koncová pozice (např. pozice cache)
  /// @returns Vzdálenost v metrech (double)
  static double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Ověří, zda je vzdálenost mezi polohou uživatele a cache menší
  /// nebo rovna definovanému poloměru pro odemknutí (20m).
  /// 
  /// @param userPosition Aktuální pozice uživatele
  /// @param cachePosition Pozice cache
  /// @returns true, pokud je uživatel v dosahu pro odemčení
  static bool isInRange(LatLng userPosition, LatLng cachePosition) {
    final distance = calculateDistance(userPosition, cachePosition);
    return distance <= unlockRadiusMeters;
  }

  /// Vypočítá azimut (bearing) ze startovní pozice k cíli (ve stupních 0-360).
  /// 0 = Sever, 90 = Východ, 180 = Jih, 270 = Západ.
  static double calculateBearing(LatLng start, LatLng end) {
    // Převod na radiány
    final startLat = _degToRad(start.latitude);
    final startLng = _degToRad(start.longitude);
    final endLat = _degToRad(end.latitude);
    final endLng = _degToRad(end.longitude);

    final dLng = endLng - startLng;

    // Vzorec pro výpočet azimutu
    final y = Math.sin(dLng) * Math.cos(endLat);
    final x = Math.cos(startLat) * Math.sin(endLat) -
        Math.sin(startLat) * Math.cos(endLat) * Math.cos(dLng);

    final bearingRad = Math.atan2(y, x);

    // Převod zpět na stupně a normalizace na 0-360
    final bearingDeg = _radToDeg(bearingRad);
    return (bearingDeg + 360) % 360;
  }

  static double _degToRad(double deg) => deg * (Math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / Math.pi);
}