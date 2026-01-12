import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// Represents a virtual object in the AR world
class ArObject {
  final String id;
  // Live coordinates
  double azimuth; 
  double elevation; 
  double distance; 
  
  // Base coordinates for animation anchored reference
  final double initialAzimuth;
  final double initialElevation;
  
  // Visual properties
  bool isCaught;

  ArObject({
    required this.id,
    required this.azimuth, 
    required this.elevation,
    this.distance = 2.0,
    this.isCaught = false,
  }) : initialAzimuth = azimuth, initialElevation = elevation;
}

class ArService extends ChangeNotifier {
  List<ArObject> _objects = [];
// ... (existing fields)

  void _update(double dt) {
    // 1. Smooth Sensors (Low Pass Filter)
    const double smoothFactor = 0.05; // Even smoother (0.1 -> 0.05)
    
    _yaw += (_targetYaw - _yaw) * smoothFactor;
    _pitch += (_targetPitch - _pitch) * smoothFactor;
    _roll += (_targetRoll - _roll) * smoothFactor;
    
    // Normalize Yaw visual
    if (_yaw > 360) _yaw -= 360;
    if (_yaw < 0) _yaw += 360;

    // 2. Animate Coins (Float/Fly)
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    for (int i = 0; i < _objects.length; i++) {
        final obj = _objects[i];
        if (obj.isCaught) continue;
        
        final seed = i * 100;
        
        // Calculate offsets from INITIAL position
        // Amplitude: 5 degrees azimuth, 2 degrees elevation
        // Speed: Slower frequency
        
        // Horizontal flight (drifting around) - DISABLED (Static)
        // double azOffset = math.sin(time * 0.05 + seed) * 5.0; 
        
        // Vertical bobbing - DISABLED (Static)
        // double elOffset = math.cos(time * 0.08 + seed) * 2.0;
        
        obj.azimuth = obj.initialAzimuth; // + azOffset;
        obj.elevation = obj.initialElevation; // + elOffset;
    }
    
    notifyListeners();
  }
// ...
  List<ArObject> get objects => _objects;

  // Device Orientation (Smoothed)
  double _yaw = 0.0;   // Compass heading (degrees)
  double _pitch = 0.0; // Device tilt up/down (radians)
  double _roll = 0.0;  // Device tilt left/right (radians)
  
  // Raw targets for smoothing
  double _targetYaw = 0.0;
  double _targetPitch = 0.0;
  double _targetRoll = 0.0;

  StreamSubscription? _accelSubscription;
  StreamSubscription? _compassSubscription;
  Timer? _animationTimer;

  void startSensorTracking() {
    // 1. Compass for Yaw (Azimuth)
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        // Handle 360 wrap-around for smoothing
        double d = event.heading! - _targetYaw;
        while (d < -180) d += 360;
        while (d > 180) d -= 360;
        _targetYaw += d;
      }
    });

    // 2. Accelerometer for Pitch/Roll (Gravity vector)
    _accelSubscription = accelerometerEventStream().listen((event) {
      final double x = event.x;
      final double y = event.y;
      final double z = event.z;
      
      _targetPitch = math.atan2(y, z); // Radians
      _targetRoll = math.atan2(-x, math.sqrt(y*y + z*z)); // Radians
      
      // We don't notify here anymore, loop handles it
    });
    
    // 3. Animation Loop (60 FPS)
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _update(0.016);
    });
  }
  


  void stopSensorTracking() {
    _accelSubscription?.cancel();
    _compassSubscription?.cancel();
    _animationTimer?.cancel();
  }

  int _totalCaught = 0;
  int _targetCoinCount = 10;
  int _spawnedCount = 0;

  void generateCoins(int targetCount) {
    _objects.clear();
    _totalCaught = 0;
    _spawnedCount = targetCount;
    _targetCoinCount = targetCount;
    
    final random = math.Random();
    
    for (int i = 0; i < targetCount; i++) {
       _objects.add(ArObject(
          id: 'coin_$i', 
          azimuth: random.nextDouble() * 360, 
          elevation: (random.nextDouble() * 60) - 30, 
          distance: 3.0 + (random.nextDouble() * 2.0), // Random distance 3-5m
       ));
    }
    notifyListeners();
  }

  // _maintainPoolSize removed - generating all at once

  void markCaught(String id) {
    final index = _objects.indexWhere((o) => o.id == id);
    if (index != -1) {
       if (_objects[index].isCaught) return;

       _objects[index].isCaught = true;
       _totalCaught++;
       notifyListeners();

       // Remove visual object after delay
       Future.delayed(const Duration(milliseconds: 200), () {
          // We don't remove from list to keep index stable? 
          // Or we can remove. With static list, removing is fine.
          // But if we remove, we need to handle index issues in render loop?
          // Since we iterate by object, it's fine.
          _objects.removeWhere((o) => o.id == id);
          notifyListeners(); 
       });
    }
  }
  
  int get caughtCount => _totalCaught;

  /// Calculates the screen position (Offset) for a given AR Object.
  /// Returns null if object is behind the camera.
  Offset? projectObject(ArObject obj, Size screenSize, double fovYRadians) {
    if (obj.isCaught) return null;

    // Relative Yaw (Delta Azimuth)
    double deltaYaw = (obj.azimuth - _yaw);
    // Normalize to -180..180
    if (deltaYaw > 180) deltaYaw -= 360;
    if (deltaYaw < -180) deltaYaw += 360;
    
    // Convert to radians
    // Use smoothed _yaw and _pitch
    
    // ... rest of Math logic remains mostly same but uses smoothed variables
    // Simple projection (Small angle approximation works well enough for "just flying coins")
    
    // Visual Pitch (deg):
    // _pitch is radians.
    double devicePitchDeg = (_pitch * vector.radians2Degrees) - 90;
    
    // Apply Roll (rotation of screen plane around center)
    double relPitch = obj.elevation - devicePitchDeg;
    double relYaw = deltaYaw; 
    
    double cR = math.cos(_roll);
    double sR = math.sin(_roll);
    
    // 2D Rotation to compensate for roll
    double rotX = relYaw * cR - relPitch * sR;
    double rotY = relYaw * sR + relPitch * cR;
    
    // FOV Check
    if (rotX.abs() > 45 || rotY.abs() > 60) return null;
    
    // Map to Screen Coordinates
    double pxPerDegX = (screenSize.width / 2) / 30.0; // 30 deg half-fov-x
    double pxPerDegY = (screenSize.height / 2) / 40.0; // 40 deg half-fov-y
    
    double screenX = (screenSize.width / 2) + (rotX * pxPerDegX);
    double screenY = (screenSize.height / 2) - (rotY * pxPerDegY); 
    
    return Offset(screenX, screenY);
  }
}
