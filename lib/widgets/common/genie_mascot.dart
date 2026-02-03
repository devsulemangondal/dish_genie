import 'package:flutter/material.dart';
import 'dart:math' as math;

enum GenieMascotSize { sm, md, lg, xl }

class GenieMascot extends StatefulWidget {
  final GenieMascotSize size;
  final String? className;

  const GenieMascot({
    super.key,
    this.size = GenieMascotSize.lg,
    this.className,
  });

  @override
  State<GenieMascot> createState() => _GenieMascotState();
}

class _GenieMascotState extends State<GenieMascot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getSize() {
    switch (widget.size) {
      case GenieMascotSize.sm:
        return 56;
      case GenieMascotSize.md:
        return 80;
      case GenieMascotSize.lg:
        return 112;
      case GenieMascotSize.xl:
        return 160;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _getSize();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Floating sparkles
          Positioned(
            top: -8,
            right: 16,
            child: _Sparkle(
              size: 12,
              color: const Color(0xFF0FA87A),
              delay: 0,
            ),
          ),
          Positioned(
            top: 40,
            left: -8,
            child: _Sparkle(
              size: 8,
              color: const Color(0xFF3DD5A8),
              delay: 200,
            ),
          ),
          Positioned(
            bottom: 16,
            right: 0,
            child: _Sparkle(
              size: 10,
              color: const Color(0xFF7FC6D8),
              delay: 300,
            ),
          ),
          // Mascot image with float animation
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Image.asset(
                  'assets/images/genie-mascot.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatefulWidget {
  final double size;
  final Color color;
  final int delay;

  const _Sparkle({
    required this.size,
    required this.color,
    required this.delay,
  });

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat();
    });
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
        final opacity = (math.sin(_controller.value * 2 * math.pi) + 1) / 2;
        final scale = 0.8 + (opacity * 0.4);
        return Opacity(
          opacity: 0.3 + (opacity * 0.7),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
