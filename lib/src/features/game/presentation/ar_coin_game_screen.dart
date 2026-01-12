import 'dart:async';
import 'package:camera/camera.dart';
import 'package:o3d/o3d.dart';
import 'package:flutter_geocache/src/features/game/presentation/widgets/coin_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_geocache/src/features/game/application/ar_service.dart';
import 'package:flutter_geocache/src/features/cache/domain/models/cache_model.dart';

class ARCoinGameScreen extends StatefulWidget {
  final CacheModel cache;

  const ARCoinGameScreen({super.key, required this.cache});

  static const String routeName = '/game_ar';

  @override
  State<ARCoinGameScreen> createState() => _ARCoinGameScreenState();
}

class _ARCoinGameScreenState extends State<ARCoinGameScreen> {
  CameraController? _controller;
  // Controller for 3D view (LOD: Only for the closest coin)
  O3DController? _o3dController;
  
  late ArService _arService;
  Timer? _gameTimer;
  int _remainingTime = 60; // 60 seconds to find 10 coins
  static const int _targetCoins = 10;
  bool _gameOver = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _o3dController = O3DController();
    _arService = ArService();
    _tryInitializeCamera();
    _startGame();
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
      print("Camera init error: $e");
    }
  }

  void _startGame() {
    _arService.startSensorTracking();
    _arService.generateCoins(_targetCoins); // Generate 10 coins
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _endGame(false);
        }
      });
    });
  }

  void _endGame(bool success) {
    _gameTimer?.cancel();
    _arService.stopSensorTracking();
    setState(() {
      _gameOver = true;
      _won = success;
    });

    if (success) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _arService.stopSensorTracking();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          CameraPreview(_controller!),

          // 2. AR Overlay (Coins)
          AnimatedBuilder(
            animation: _arService,
            builder: (context, child) {
              if (_gameOver) return const SizedBox.shrink();

              // Get all coins and project them
              final coins = _arService.objects;
              final visibleWidgets = <Widget>[];

              // Render all active coins using O3D (Pool size is small ~3, so safe)
              for (var coin in coins) {
                if (coin.isCaught) continue; 
                
                final Offset? pos = _arService.projectObject(coin, size, 1.0);
                
                if (pos != null) {
                   const double margin = 150.0;
                   if (pos.dx >= -margin && pos.dx <= size.width + margin &&
                       pos.dy >= -margin && pos.dy <= size.height + margin) {
                     
                      visibleWidgets.add(
                        Positioned(
                          left: pos.dx - 80, 
                          top: pos.dy - 80,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _arService.markCaught(coin.id);
                              if (_arService.caughtCount >= _targetCoins) {
                                _endGame(true);
                              }
                            },
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: IgnorePointer(
                                child: O3D(
                                  src: 'assets/coin/Coin.glb',
                                  controller: null, 
                                  autoPlay: false, 
                                  autoRotate: true, 
                                  cameraControls: false,
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                   }
                }
              }

              return Stack(children: visibleWidgets);
            },
          ),

          // 3. HUD
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedBuilder(
                          animation: _arService,
                          builder: (context, _) {
                            return Text(
                              "Mince: ${_arService.caughtCount} / $_targetCoins",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _remainingTime < 10 ? Colors.red.withOpacity(0.7) : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                             Text(
                               "Čas: $_remainingTime s",
                               style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                             ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                
                // Instructions or Game Over screen
                if (_gameOver)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _won ? Icons.emoji_events : Icons.cancel,
                            color: _won ? Colors.amber : Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _won ? "VÍTĚZSTVÍ!" : "ČAS VYPRŠEL!",
                            style: TextStyle(
                              color: _won ? Colors.amber : Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!_won)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _gameOver = false;
                                  _remainingTime = 60;
                                  _arService.startSensorTracking();
                                  _startGame();
                                });
                              },
                              child: const Text("Zkusit znovu"),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Tutorial hint
                if (!_gameOver && _remainingTime > 55)
                   const Padding(
                     padding: EdgeInsets.only(bottom: 50.0),
                     child: Text(
                       "Otáčej se a hledej mince!",
                       style: TextStyle(color: Colors.white, fontSize: 18, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
                     ),
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
