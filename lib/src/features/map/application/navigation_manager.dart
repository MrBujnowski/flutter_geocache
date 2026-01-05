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

  // Aktualizace během pohybu (volat z MapScreen při změně polohy)
  void updateProgress(LatLng userPosition) {
    if (!isNavigating || _currentRoute == null) return;

    // 1. Zjistit, zda jsme splnili aktuální krok
    // Jednoduchá logika: Pokud jsme blízko konce aktuálního kroku (manévru), posuneme se na další.
    // Nebo: Pokud jsme blízko DALŠÍHO manévru.
    
    // Pro jednoduchost: Najdeme nejbližší "začátek manévru" v budoucnosti?
    // Lepší: OSRM vrací kroky. Každý krok končí manévrem.
    // _currentStep je ten, který právě plníme (např. "Jděte rovně po Main St").
    // Musíme detekovat, že jsme dorazili na konec tohoto segmentu.
    
    // Zatím ultra-simple: Zobrazujeme prostě jen nejbližší manévr podle vzdálenosti.
    // Ale to by skákalo.
    
    // Zkusme toto: Pokud je vzdálenost k 'lokaci dalšího kroku' menší než 20 metrů, přepni na další.
    if (_currentStepIndex < _currentRoute!.steps.length - 1) {
       final nextStep = _currentRoute!.steps[_currentStepIndex + 1];
       final distToNextManeuver = app_dist.DistanceCalculator.calculateDistance(
         userPosition,
         nextStep.location
       );

       if (distToNextManeuver < 20) { // 20 metrů tolerance
         _currentStepIndex++;
         notifyListeners();
       }
    }
  }
}
