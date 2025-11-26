import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
}