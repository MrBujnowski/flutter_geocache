import 'package:flutter/material.dart';
import '../application/navigation_manager.dart';

class NavigationOverlay extends StatelessWidget {
  final NavigationManager manager;

  const NavigationOverlay({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    final step = manager.currentStep;
    final route = manager.currentRoute;
    if (step == null || route == null) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Horní panel - Instrukce
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              _getManeuverIcon(step.maneuverType, step.modifier),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${step.distance.toInt()} m',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Spodní panel - Ukončení
        Container(
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Statistiky
               Container(
                 margin: const EdgeInsets.only(bottom: 12),
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: Colors.white, // Fully opaque for better contrast
                   borderRadius: BorderRadius.circular(20),
                   boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      const Icon(Icons.timer, size: 20, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(manager.remainingDurationFormatted, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 20),
                      const Icon(Icons.straighten, size: 20, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(manager.remainingDistanceFormatted, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900)),
                   ],
                 ),
               ),
               
               FloatingActionButton.extended(
                onPressed: manager.stopNavigation,
                backgroundColor: Colors.red,
                icon: const Icon(Icons.close),
                label: const Text("Ukončit navigaci"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Icon _getManeuverIcon(String type, String? modifier) {
    IconData icon = Icons.straight;
    
    if (type == 'turn') {
      if (modifier == 'left' || modifier == 'slight left') icon = Icons.turn_left;
      else if (modifier == 'right' || modifier == 'slight right') icon = Icons.turn_right;
    } else if (type == 'arrive') {
      icon = Icons.flag;
    }
    
    return Icon(icon, color: Colors.white, size: 40);
  }
}
