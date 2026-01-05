import 'package:latlong2/latlong.dart';

/// Reprezentuje jeden geocache bod ve hře.
/// Obsahuje jeho polohu, kód, typ a stav odemčení.
class CacheModel {
  final String id;
  final LatLng position; // Přesná GPS poloha cache
  final String code; // Např. CZ-12345
  final String type; // Tradiční, Multi...
  final double difficulty;
  final double terrain;
  
  // Name a description už nejsou v DB pro 78k kešek. 
  // Budeme je generovat dynamicky nebo zobrazovat 'Keška CZ-...'
  
  final bool isUnlocked; // Je cache odemčena uživatelem?

  String get displayName => "Keška $code";
  String get displayDescription => "Typ: $type\nObtížnost: $difficulty / Terén: $terrain";

  const CacheModel({
    required this.id,
    required this.position,
    required this.code,
    required this.type,
    required this.difficulty,
    required this.terrain,
    this.isUnlocked = false,
  });

  /// Vytvoří novou instanci modelu s aktualizovaným stavem.
  CacheModel copyWith({
    bool? isUnlocked,
  }) {
    return CacheModel(
      id: id,
      position: position,
      code: code,
      type: type,
      difficulty: difficulty,
      terrain: terrain,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}