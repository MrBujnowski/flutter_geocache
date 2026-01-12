import 'package:flutter/material.dart';
import 'dart:math' as math;

class CoinWidget extends StatefulWidget {
  final double size;

  const CoinWidget({super.key, this.size = 100.0});

  @override
  State<CoinWidget> createState() => _CoinWidgetState();
}

class _CoinWidgetState extends State<CoinWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), 
    ); // No repeat() = Static
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Full rotation from 0 to 2*pi
        return Transform(
          transform: Matrix4.rotationY(_controller.value * 2 * math.pi),
          alignment: Alignment.center,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFA500), // Orange-Gold
                  Color(0xFFFFD700), // Gold
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(0.3),
                   blurRadius: 10,
                   spreadRadius: 2,
                   offset: const Offset(4, 4),
                 )
              ],
              border: Border.all(
                color: const Color(0xFFDAA520), // Goldenrod border
                width: 4,
              ),
            ),
            // Front face logic:
            // When rotation is between 90 and 270 degrees (pi/2 to 3pi/2), we are seeing the "back".
            // But since it's symmetric, we just want to avoid the "mirrored" text effect if we had text.
            // For a simple ID/Icon, we might not care, but let's make it consistent.
            child: Center(
              child: Container(
                width: widget.size * 0.7,
                height: widget.size * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB8860B), width: 2),
                ),
                child: Center(
                  child: Text(
                    "\$",
                    style: TextStyle(
                      fontSize: widget.size * 0.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB8860B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
