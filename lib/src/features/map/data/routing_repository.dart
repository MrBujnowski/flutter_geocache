import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../map/domain/models/route_model.dart';

class RoutingRepository {
  // OSRM Public Server (Demo usage only - respect usage policy)
  // For production, use your own instance or a commercial provider.
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1';

  Future<RouteModel?> getRoute(LatLng start, LatLng end, {String profile = 'foot'}) async {
    // Použijeme různé servery pro pěší (OSM DE) a auta (OSRM Demo).
    // router.project-osrm.org často ignoruje 'foot' a vrací 'driving'.
    
    String baseUrl;
    String profilePath;

    if (profile == 'foot') {
      baseUrl = 'https://routing.openstreetmap.de/routed-foot/route/v1';
      profilePath = 'foot';
    } else {
      // driving
      baseUrl = 'https://router.project-osrm.org/route/v1';
      profilePath = 'driving';
    }

    final url = Uri.parse(
        '$baseUrl/$profilePath/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&generate_hints=false');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
          return null;
        }

        final route = data['routes'][0];
        final legs = route['legs'][0];
        
        // 1. Geometry (Polyline points)
        final geometry = route['geometry'];
        final List<LatLng> points = [];
        final coordinates = geometry['coordinates'] as List; // GeoJSON [lon, lat]
        
        for (var coord in coordinates) {
          points.add(LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
        }

        // 2. Steps (Instructions)
        final List<RouteStep> steps = [];
        final stepsData = legs['steps'] as List;

        for (var step in stepsData) {
          final maneuver = step['maneuver'];
          final location = maneuver['location'] as List; // [lon, lat]
          
          steps.add(RouteStep(
            instruction: _formatInstruction(step), // Vyrobíme hezkou instrukci
            distance: (step['distance'] as num).toDouble(),
            duration: (step['duration'] as num).toDouble(),
            location: LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble()),
            maneuverType: maneuver['type'],
            modifier: maneuver['modifier'],
          ));
        }

        return RouteModel(
          geometry: points,
          distance: (route['distance'] as num).toDouble(),
          duration: (route['duration'] as num).toDouble(),
          steps: steps,
        );
      } else {
        print('OSRM Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Routing Exception: $e');
      return null;
    }
  }

  String _formatInstruction(Map<String, dynamic> step) {
    // Jednoduchý formatter, OSRM nevrací vždy 'name' v manévru, ale v step['name']
    final maneuver = step['maneuver'];
    final type = maneuver['type'];
    final modifier = maneuver['modifier'];
    final name = step['name'] ?? '';
    
    // Základní překlad (měl by být sofistikovanější)
    String action = type;
    if (type == 'turn') {
      if (modifier == 'left') action = 'Zahněte doleva';
      else if (modifier == 'right') action = 'Zahněte doprava';
      else if (modifier == 'slight left') action = 'Mírně vlevo';
      else if (modifier == 'slight right') action = 'Mírně vpravo';
      else action = 'Zahněte';
    } else if (type == 'depart') {
        action = 'Vyrazte';
    } else if (type == 'arrive') {
        action = 'Cíl';
    } else if (type == 'new name') {
       action = 'Pokračujte';
    }

    if (name.isNotEmpty && type != 'arrive') {
      return '$action na $name';
    }
    return action;
  }
}
