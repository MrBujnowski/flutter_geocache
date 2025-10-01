// lib/src/features/map/presentation/map_screen.dart

import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  /// Statická konstanta pro navigaci (routing) v aplikaci.
  static const String routeName = '/map'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Používáme tmavě šedou pro pozadí
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        // Světlejší tyrkysová barva pro AppBar, bílý text
        backgroundColor: Colors.teal,           
        title: const Text(
          "GeoHunt Map",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const Center(
        child: Text(
          "Hello GeoHunt! (Map Screen)", // Upravený text pro lepší odlišení
          style: TextStyle(
            fontSize: 28,
            color: Colors.amber,             
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
