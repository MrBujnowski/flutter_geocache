import 'package:latlong2/latlong.dart';

class RouteModel {
  final List<LatLng> geometry;
  final double distance; // v metrech
  final double duration; // v sekundách
  final List<RouteStep> steps;

  RouteModel({
    required this.geometry,
    required this.distance,
    required this.duration,
    required this.steps,
  });
}

class RouteStep {
  final String instruction; // např. "Zahněte doprava na Main Street"
  final double distance;
  final double duration;
  final LatLng location; // Kde manévr začíná
  final String maneuverType; // turn, new name, depart, arrive...
  final String? modifier; // right, left, sharp right...

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.location,
    required this.maneuverType,
    this.modifier,
  });
}
