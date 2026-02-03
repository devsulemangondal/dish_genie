import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/colors.dart';

class FloatingSparkles extends StatefulWidget {
  const FloatingSparkles({super.key});

  @override
  State<FloatingSparkles> createState() => _FloatingSparklesState();
}

class _FloatingSparklesState extends State<FloatingSparkles>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  final List<Map<String, dynamic>> _sparkles = [
    {'top': 0.1, 'left': 0.05, 'size': 8.0, 'delay': 0, 'duration': 3.0},
    {'top': 0.2, 'right': 0.1, 'size': 12.0, 'delay': 0.5, 'duration': 4.0},
    {'top': 0.6, 'left': 0.08, 'size': 10.0, 'delay': 1.0, 'duration': 3.5},
    {'top': 0.75, 'right': 0.15, 'size': 8.0, 'delay': 1.5, 'duration': 4.0},
    {'top': 0.4, 'left': 0.03, 'size': 6.0, 'delay': 2.0, 'duration': 3.0},
    {'top': 0.85, 'left': 0.2, 'size': 8.0, 'delay': 0.8, 'duration': 4.5},
    {'top': 0.15, 'right': 0.05, 'size': 6.0, 'delay': 1.2, 'duration': 3.8},
    {'top': 0.5, 'right': 0.03, 'size': 8.0, 'delay': 0.3, 'duration': 4.2},
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _sparkles.length,
      (index) => AnimationController(
        duration: Duration(
          milliseconds: (_sparkles[index]['duration'] * 1000).round(),
        ),
        vsync: this,
      )..repeat(),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Color _getColor(int index) {
    if (index % 3 == 0) return AppColors.geniePink;
    if (index % 3 == 1) return AppColors.geniePurple;
    return AppColors.genieGold;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: Stack(
        children: [
          // Large gradient orbs
          Positioned(
            top: size.height * 0.2 - 192,
            left: -128,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                color: AppColors.genieLavender.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.2 - 160,
            right: -128,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: AppColors.geniePink.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Sparkles
          ...List.generate(_sparkles.length, (index) {
            final sparkle = _sparkles[index];
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                final opacity = (math.sin(
                          _controllers[index].value * 2 * math.pi,
                        ) +
                        1) /
                    2;
                final scale = 0.8 + (opacity * 0.4);
                return Positioned(
                  top: sparkle['top'] != null
                      ? size.height * sparkle['top']
                      : null,
                  bottom: sparkle['bottom'] != null
                      ? size.height * sparkle['bottom']
                      : null,
                  left: sparkle['left'] != null
                      ? size.width * sparkle['left']
                      : null,
                  right: sparkle['right'] != null
                      ? size.width * sparkle['right']
                      : null,
                  child: Opacity(
                    opacity: 0.3 + (opacity * 0.7),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: sparkle['size'],
                        height: sparkle['size'],
                        decoration: BoxDecoration(
                          color: _getColor(index),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
