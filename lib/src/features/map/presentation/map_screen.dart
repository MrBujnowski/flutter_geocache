import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        backgroundColor: Colors.teal,           
        title: const Text(
          "GeoHunt Map",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const Center(
        child: Text(
          "Hello GeoHunt!",
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
