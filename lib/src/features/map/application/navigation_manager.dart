import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../data/routing_repository.dart';
import '../domain/models/route_model.dart';
import '../../../core/utils/distance_calculator.dart' as app_dist;

class NavigationManager extends ChangeNotifier {
  final RoutingRepository _repository = RoutingRepository();
  
  bool isNavigating = false;
  RouteModel? _currentRoute;
  int _currentStepIndex = 0;
  
  RouteModel? get currentRoute => _currentRoute;
  RouteStep? get currentStep => _currentRoute != null && _currentStepIndex < _currentRoute!.steps.length 
      ? _currentRoute!.steps[_currentStepIndex] 
      : null;

  // Spustí navigaci
  Future<void> startNavigation(LatLng start, LatLng end, {String profile = 'foot'}) async {
    isNavigating = true;
    notifyListeners(); 

    final route = await _repository.getRoute(start, end, profile: profile);
    if (route != null) {
      _currentRoute = route;
      _currentStepIndex = 0;
    } else {
      isNavigating = false;
    }
    notifyListeners();
  }

  String get remainingDistanceFormatted {
    if (_currentRoute == null) return "0 m";
    // Hrubý odhad: Celková dálka mínus co jsme ušli?
    // Nebo součet zbývajících kroků.
    // Pro zjednodušení vezmeme celkovou dálku a odečteme poměrnou část :D 
    // To je nepřesné.
    // Lepší: Součet distance všech kroků od _currentStepIndex nahoru.
    
    double dist = 0;
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      dist += _currentRoute!.steps[i].distance;
    }
    
    if (dist > 1000) {
      return "${(dist / 1000).toStringAsFixed(1)} km";
    }
    return "${dist.toInt()} m";
  }

  String get remainingDurationFormatted {
    if (_currentRoute == null) return "0 min";
    double dur = 0;
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
        dur += _currentRoute!.steps[i].duration;
    }
    
    // OSRM duration je v sekundách
    if (dur > 3600) {
       int h = dur ~/ 3600;
       int m = (dur % 3600) ~/ 60;
       return "${h}h ${m}m";
    }
    int m = dur ~/ 60;
    return "$m min";
  }

  void stopNavigation() {
    isNavigating = false;
    _currentRoute = null;
    _currentStepIndex = 0;
    notifyListeners();
  }

  int _lastClosestIndex = 0;

  // Aktualizace během pohybu (volat z MapScreen při změně polohy)
  void updateProgress(LatLng userPosition) {
    if (!isNavigating || _currentRoute == null || _currentRoute!.geometry.isEmpty) return;

    // 1. Update Geometry (Visual - Disappearing line)
    // Find closest point index starting from last known index (optimization)
    int closestIndex = _lastClosestIndex;
    double minDistance = double.infinity;
    
    // Search window: Look ahead 50 points (or to end)
    int searchEnd = (_lastClosestIndex + 50).clamp(0, _currentRoute!.geometry.length);
    
    // Also look back a bit in case of jitter
    int searchStart = (_lastClosestIndex - 5).clamp(0, _currentRoute!.geometry.length);
    
    // Fallback: If we are very far, search whole list (re-route scenario?)
    // For now, simple search.
    
    for (int i = searchStart; i < searchEnd; i++) {
        final d = app_dist.DistanceCalculator.calculateDistance(userPosition, _currentRoute!.geometry[i]);
        if (d < minDistance) {
            minDistance = d;
            closestIndex = i;
        }
    }
    
    // If we moved forward significantly
    if (closestIndex > _lastClosestIndex) {
        // Remove points behind us
        // Efficiently updating the list might be slow if standard List.
        // We can just keep an index offset? 
        // But PolylineLayer needs a list.
        // Let's modify the list directly for now as simple solution.
        _currentRoute!.geometry.removeRange(0, closestIndex - _lastClosestIndex);
        _lastClosestIndex = 0; // Since we removed elements, index 0 is now the closest
    } 
    // Wait, modifying the list resets indices.
    // Correct approach:
    // If we found new closest index 'i' in the *current* list.
    // Remove 0..i.
    
    // Fix logic:
    // 'closestIndex' is index in the CURRENT geometry list.
    if (closestIndex > 0) {
        // Only slice if we are comfortably close (e.g. within 50m of the line)
        // If we are far, maybe we shouldn't slice? 
        if (minDistance < 50) {
           _currentRoute!.geometry.removeRange(0, closestIndex);
        }
    }


    // 2. Update Instructions (Step Logic)
    if (_currentStepIndex < _currentRoute!.steps.length - 1) {
       final nextStep = _currentRoute!.steps[_currentStepIndex + 1];
       final distToNextManeuver = app_dist.DistanceCalculator.calculateDistance(
         userPosition,
         nextStep.location
       );

       // Distance to switch triggers
       if (distToNextManeuver < 30) { // 30 meters tolerance
         _currentStepIndex++;
         notifyListeners();
       }
    }
    
    notifyListeners();
  }
}
