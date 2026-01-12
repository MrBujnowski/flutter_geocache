import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedCacheMarker extends StatefulWidget {
  final bool isUnlocked;
  final VoidCallback onTap;

  const AnimatedCacheMarker({
    super.key,
    required this.isUnlocked,
    required this.onTap,
  });

  @override
  State<AnimatedCacheMarker> createState() => _AnimatedCacheMarkerState();
}

class _AnimatedCacheMarkerState extends State<AnimatedCacheMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  Timer? _timer;

  // Stagger start times slightly so not all markers shake in unison
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Shake animation: Rotate slightly left and right
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.15), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.15), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start periodic timer
    _startTimer();
  }

  void _startTimer() {
    // Random delay for the first shake to desync markers
    final initialDelay = _random.nextInt(3000);
    Future.delayed(Duration(milliseconds: initialDelay), () {
      if (!mounted) return;
      _scheduleShake();
    });
  }

  void _scheduleShake() {
    if (!mounted) return;
    
    // Shake!
    _controller.forward(from: 0);

    // Schedule next shake in 4-6 seconds
    _timer = Timer(Duration(seconds: 4 + _random.nextInt(3)), _scheduleShake);
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sizing logic
    // Unlocked
    final double containerSize = widget.isUnlocked ? 40.0 : 48.0; 
    // Icon fills the container (0 padding)
    final double iconSize = containerSize; 

    final Color borderColor = widget.isUnlocked ? Colors.green : Colors.orange;
    final String assetPath = widget.isUnlocked
        ? 'assets/images/chest_unlocked.png'
        : 'assets/images/chest_locked.png';

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _shakeAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: containerSize,
          height: containerSize,
          clipBehavior: Clip.hardEdge, // Clip zoomed image to circle
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Transform.scale(
              scale: 1.75, // Zoom in by 25% to eat up PNG padding
              child: Image.asset(
                assetPath,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
