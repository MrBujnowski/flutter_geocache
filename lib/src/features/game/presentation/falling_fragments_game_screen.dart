import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

class FallingFragmentsGameScreen extends StatefulWidget {
  final CacheModel cache;

  const FallingFragmentsGameScreen({super.key, required this.cache});

  @override
  State<FallingFragmentsGameScreen> createState() => _FallingFragmentsGameScreenState();
}

class Fragment {
  String id;
  double x; // 0.0 to 1.0 (Screen width)
  double y; // 0.0 to 1.0 (Screen height)
  double speed;
  bool isCaught;

  Fragment({required this.id, required this.x, required this.y, required this.speed, this.isCaught = false});
}

class _FallingFragmentsGameScreenState extends State<FallingFragmentsGameScreen> {
  CameraController? _controller;
  StreamSubscription? _gyroSubscription;
  Timer? _gameTimer;

  // Game State
  double _basketPosition = 0.5; // Center (0.0 - 1.0)
  final List<Fragment> _fragments = [];
  int _score = 0;
  static const int _targetScore = 10;
  int _timeLeft = 60;
  bool _gameOver = false;
  bool _won = false;

  // Constants
  static const double _basketWidth = 0.2; // 20% of screen width
  static const double _gyroSensitivity = 0.02; // Reduced from 0.05 for better control

  @override
  void initState() {
    super.initState();
    _tryInitializeCamera();
    _startGyroTracking();
    _startGameLoop();
  }

  Future<void> _tryInitializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  void _startGyroTracking() {
    _gyroSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (_gameOver) return;
      // Use Y-axis rotation (roll) for horizontal movement
      // Positive Y (tilt right) -> Move Right
      // Negative Y (tilt left) -> Move Left
      setState(() {
        double delta = event.y * _gyroSensitivity;
        _basketPosition = (_basketPosition + delta).clamp(0.0 + _basketWidth / 2, 1.0 - _basketWidth / 2);
      });
    });
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) { // ~30 FPS
      if (_gameOver) return;

      setState(() {
        // 1. Update Timer (Approximate)
        if (timer.tick % 30 == 0) {
           _timeLeft--;
           if (_timeLeft <= 0) _endGame(false);
        }

        // 2. Spawn Fragments (Randomly)
        if (Random().nextDouble() < 0.05) { // 5% chance per frame
           _fragments.add(Fragment(
             id: DateTime.now().millisecondsSinceEpoch.toString(),
             x: Random().nextDouble() * 0.9 + 0.05, // Keep somewhat central
             y: -0.1, // Start just above top
             speed: 0.005 + Random().nextDouble() * 0.01, // Random speed
           ));
        }

        // 3. Move Fragments
        for (var f in _fragments) {
          f.y += f.speed;
        }

        // 4. Check Collisions & Cleanup
        final basketLeft = _basketPosition - _basketWidth / 2;
        final basketRight = _basketPosition + _basketWidth / 2;
        final basketTop = 0.85; // Basket is at bottom 15%

        for (var f in _fragments.toList()) {
           // Caught: Hits basket Y range AND is within X range
           if (!f.isCaught && f.y >= basketTop && f.y <= basketTop + 0.05) {
              if (f.x >= basketLeft && f.x <= basketRight) {
                 f.isCaught = true;
                 _score++;
                 // Haptic feedback could be added here
                 if (_score >= _targetScore) {
                    _endGame(true);
                 }
              }
           }
           
           // Missed: Went off screen
           if (f.y > 1.2) {
             _fragments.remove(f);
           }
        }
        
        _fragments.removeWhere((f) => f.isCaught && f.y > 1.0); // Cleanup caught ones logic visual? No, just remove immediately for now or animate.
        // Simplified: Remove caught immediately for logic, maybe animate visual later.
        _fragments.removeWhere((f) => f.isCaught);
      });
    });
  }

  void _endGame(bool success) {
    _gameOver = true;
    _won = success;
    _gyroSubscription?.cancel();
    _gameTimer?.cancel();
    
    if (success) {
       Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
       });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _gyroSubscription?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Camera Background
          if (_controller != null && _controller!.value.isInitialized)
            SizedBox.expand(
              child: CameraPreview(_controller!),
            )
          else
            Container(color: Colors.black),

          // 2. Fragments
          ..._fragments.map((f) => Positioned(
            left: f.x * size.width - 20, // Center 40px icon
            top: f.y * size.height,
            child: const Icon(Icons.diamond, color: Colors.cyanAccent, size: 40),
          )),

          // 3. Basket
          Positioned(
            left: (_basketPosition - _basketWidth / 2) * size.width,
            top: size.height * 0.85,
            width: _basketWidth * size.width,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30), top: Radius.circular(5)),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(child: Icon(Icons.shopping_basket, color: Colors.white)),
            ),
          ),

          // 4. HUD
          Positioned(
            top: 40, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text("Skóre: $_score / $_targetScore", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text("Čas: $_timeLeft", style: const TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ],
            ),
          ),

          // 5. Game Over / Win Overlay
          if (_gameOver)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_won ? "VÍTĚZSTVÍ!" : "KONEC HRY", style: TextStyle(color: _won ? Colors.greenAccent : Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (!_won) ...[
                      const Text("Nestihli jste nasbírat dostatek krystalů.", style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                           Navigator.pop(context, false);
                        }, 
                        child: const Text("Zkusit znovu")
                      )
                    ] else
                       const Text("Keška se otevírá...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            
            // Back Button
            Positioned(
              bottom: 40, left: 20,
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                mini: true,
                child: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
    );
  }
}
