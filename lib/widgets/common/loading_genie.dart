import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import 'genie_mascot.dart';

class LoadingGenie extends StatefulWidget {
  final String? message;
  final GenieMascotSize size;

  const LoadingGenie({
    super.key,
    this.message,
    this.size = GenieMascotSize.md,
  });

  @override
  State<LoadingGenie> createState() => _LoadingGenieState();
}

class _LoadingGenieState extends State<LoadingGenie>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late AnimationController _dotsController;
  late List<AnimationController> _dotControllers;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _dotControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    for (var controller in _dotControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Container to position glow and mascot
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Glow effect behind mascot
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final opacity = (math.sin(_pulseController.value * 2 * math.pi) +
                        1) /
                    2;
                return Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: AppColors.geniePurple.withOpacity(0.3 * opacity),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            // Mascot with bounce
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceController.value * -20),
                  child: const GenieMascot(size: GenieMascotSize.md),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Loading text
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final opacity = (math.sin(_pulseController.value * 2 * math.pi) +
                    1) /
                2;
            return Opacity(
              opacity: 0.5 + (opacity * 0.5),
              child: Text(
                widget.message ?? context.t('common.loading'),
                style: Theme.of(context).textTheme.bodyLarge,
                textDirection: Directionality.of(context),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Animated dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _dotControllers[index],
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _dotControllers[index].value * -8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? AppColors.geniePurple
                          : index == 1
                              ? AppColors.geniePink
                              : AppColors.genieGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
