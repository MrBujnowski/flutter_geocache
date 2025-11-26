import 'package:latlong2/latlong.dart';

/// Reprezentuje jeden geocache bod ve hře.
/// Obsahuje jeho polohu, název, nápovědu a stav odemčení.
class CacheModel {
  final String id;
  final LatLng position; // Přesná GPS poloha cache
  final String name;
  final String hint;
  final bool isUnlocked; // Je cache odemčena uživatelem?

  const CacheModel({
    required this.id,
    required this.position,
    required this.name,
    required this.hint,
    this.isUnlocked = false,
  });

  /// Vytvoří novou instanci modelu s aktualizovaným stavem.
  /// (Používáno pro neměnnost dat v Flutter/Dart)
  CacheModel copyWith({
    bool? isUnlocked,
  }) {
    return CacheModel(
      id: id,
      position: position,
      name: name,
      hint: hint,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}