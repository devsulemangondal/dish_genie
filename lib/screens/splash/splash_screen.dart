import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/pro_config.dart';
import '../../services/storage_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/startup_service.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(milliseconds: 2500);

  late AnimationController _stageController;
  late AnimationController _bounceController;
  late AnimationController _dotsController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _translateAnimation;
  late Animation<double> _glowAnimation;
  int _stage = 0;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();

    // Stage controller for sequential animations
    _stageController = AnimationController(
      // Keep animation aligned with desired splash duration.
      duration: _minSplashDuration,
      vsync: this,
    );

    // Bounce controller for mascot
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Dots animation controller for loading indicator
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    _translateAnimation = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    // Stage progression
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _stage = 1);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _stage = 2);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _stage = 3);
    });

    _stageController.forward();
    _bounceController.repeat(reverse: true);
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Ensure splash is visible for proper minimum duration and wait for critical initialization
    const minSplash = _minSplashDuration; // 2.5 seconds minimum
    const maxTotalWait = Duration(seconds: 4); // Maximum 4 seconds total wait

    final startTime = DateTime.now();
    bool? isFirstLaunchResult;
    bool? languageSelectedResult;

    // Initialize StorageService first to ensure SharedPreferences is ready
    await StorageService.initialize();
    
    // Start all async operations in parallel
    final firstLaunchCheck = StorageService.isFirstLaunch().then(
      (v) {
        isFirstLaunchResult = v;
        debugPrint('[SplashScreen] ✅ First launch check: $v');
      },
    ).catchError((e) {
      debugPrint('[SplashScreen] ❌ First launch check error: $e');
      isFirstLaunchResult = true; // Default to true on error (assume first launch)
    });
    
    final languageCheck = StorageService.isLanguageSelected().then(
      (v) => languageSelectedResult = v,
    );
    
    // Wait for critical startup tasks (with timeout to avoid blocking too long)
    final startupCheck = StartupService.start().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('[SplashScreen] ⚠️ StartupService timeout, continuing...');
      },
    ).catchError((e) {
      debugPrint('[SplashScreen] ⚠️ StartupService error: $e');
    });

    // Wait for minimum splash duration AND critical tasks to complete
    await Future.wait([
      // Ensure minimum display time
      Future.delayed(minSplash),
      // Wait for critical checks (with timeout)
      Future.any([
        Future.wait([firstLaunchCheck, languageCheck, startupCheck]),
        Future.delayed(maxTotalWait),
      ]),
    ]);

    // Calculate elapsed time and ensure we've waited at least the minimum
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minSplash) {
      final remaining = minSplash - elapsed;
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    // CRITICAL: Ensure first launch check has completed
    // If it's still null, wait a bit more or default to true
    if (isFirstLaunchResult == null) {
      debugPrint('[SplashScreen] ⚠️ First launch check still null, waiting...');
      try {
        isFirstLaunchResult = await StorageService.isFirstLaunch().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => true, // Default to true (first launch) if timeout
        );
        debugPrint('[SplashScreen] ✅ First launch check after wait: $isFirstLaunchResult');
      } catch (e) {
        debugPrint('[SplashScreen] ❌ Error getting first launch: $e');
        isFirstLaunchResult = true; // Default to true on error
      }
    }

    if (!mounted) return;

    // First launch flow: Splash → Pro → Inter Ad → Language
    final isFirstLaunch = isFirstLaunchResult ?? true; // Default to true for first launch
    debugPrint('[SplashScreen] 🚀 Navigation decision - isFirstLaunch: $isFirstLaunch, languageSelected: $languageSelectedResult');
    
    if (!mounted) return;
    
    if (isFirstLaunch) {
      // On iOS, skip Pro screen when showProOnIos is false
      if (Platform.isIOS && !ProConfig.showProOnIos) {
        debugPrint('[SplashScreen] 📱 iOS: Pro hidden, going to language-selection');
        context.go('/language-selection');
        return;
      }
      debugPrint('[SplashScreen] 📱 Navigating to Pro screen (first launch)');
      context.go('/pro?src=splash');
      return;
    }

    // Subsequent launches: check if pro should be shown (feature-flagged)
    final openPro = await _shouldOpenPro();
    if (!mounted) return;
    if (openPro) {
      // On iOS, skip Pro screen when showProOnIos is false
      if (Platform.isIOS && !ProConfig.showProOnIos) {
        final isLanguageSelected = languageSelectedResult ?? false;
        if (!isLanguageSelected) {
          context.go('/language-selection');
        } else {
          context.go('/');
        }
        return;
      }
      context.go('/pro?src=splash');
      return;
    }

    // If Pro is disabled remotely or fails, continue with the core app flow.
    try {
      final isLanguageSelected = languageSelectedResult ?? false;
      if (!mounted) return;
      if (!isLanguageSelected) {
        context.go('/language-selection');
      } else {
        context.go('/');
      }
    } catch (e) {
      debugPrint('[SplashScreen] ❌ Error checking language: $e');
      // Default to language selection on error
      if (mounted) {
        context.go('/language-selection');
      }
    }
  }

  // _navigateAfterAd removed: interstitial is now after Pro, not on splash.

  Future<bool> _shouldOpenPro() async {
    // Keep this fast: if Remote Config isn't ready quickly, fall back to defaults.
    try {
      final ok = await RemoteConfigService.initialize().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (!ok) return RemoteConfigService.weeklySub;

      // If disabled, try one quick fetch to avoid being stuck on cached/defaults.
      if (!RemoteConfigService.weeklySub) {
        unawaited(
          RemoteConfigService.fetchAndActivate().timeout(
            const Duration(seconds: 2),
            onTimeout: () {},
          ),
        );
      }
      return RemoteConfigService.weeklySub;
    } catch (_) {
      return RemoteConfigService.weeklySub;
    }
  }

  @override
  void dispose() {
    _stageController.dispose();
    _bounceController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.getGradientHero(context),
          ),
          child: Stack(
            children: [
              // Floating sparkles background
              ...List.generate(8, (i) {
                return Positioned(
                  left: (10 + i * 12) * MediaQuery.of(context).size.width / 100,
                  top:
                      (20 + (i % 3) * 25) *
                      MediaQuery.of(context).size.height /
                      100,
                  child: AnimatedOpacity(
                    opacity: _stage >= 1 ? 0.4 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.geniePurple.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon with animation
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _scaleAnimation,
                        _bounceController,
                      ]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _stage >= 1 ? _scaleAnimation.value : 0.0,
                          child: Transform.rotate(
                            angle: _stage >= 1 ? 0.0 : -3.14159,
                            child: Opacity(
                              opacity: _stage >= 1 ? 1.0 : 0.0,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow effect
                                  AnimatedBuilder(
                                    animation: _glowAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.geniePurple
                                                  .withOpacity(
                                                    _stage >= 2 ? 0.6 : 0.0,
                                                  ),
                                              blurRadius: 60,
                                              spreadRadius: _stage >= 2
                                                  ? 30
                                                  : 0,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  // Mascot image with bounce
                                  Transform.translate(
                                    offset: Offset(
                                      0,
                                      _stage >= 1
                                          ? (math.sin(
                                                  _bounceController.value *
                                                      2 *
                                                      math.pi,
                                                ) *
                                                8)
                                          : 0,
                                    ),
                                    child: Image.asset(
                                      'assets/images/genie-mascot.png',
                                      width: 128,
                                      height: 128,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // App Name
                    AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _stage >= 2 ? _fadeAnimation.value : 0.0,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              _stage >= 2
                                  ? (1 - _translateAnimation.value)
                                  : 16,
                            ),
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => AppColors
                                      .gradientPrimary
                                      .createShader(bounds),
                                  child: Text(
                                    context.t('splashAppName'),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                    textDirection: Directionality.of(context),
                                  ),
                                ),
                                AnimatedOpacity(
                                  opacity: _stage >= 3 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 500),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      context.t('splashSubtitle'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textDirection: Directionality.of(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    // Loading indicator with animated dots (left to right)
                    AnimatedOpacity(
                      opacity: _stage >= 3 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _stage >= 3
                                ? AnimatedBuilder(
                                    animation: _dotsController,
                                    builder: (context, child) {
                                      // Create left-to-right wave effect
                                      // Each dot animates in sequence from left (0) to right (2)
                                      final totalDots = 3;
                                      final cycleProgress =
                                          _dotsController.value; // 0.0 to 1.0

                                      // Calculate the wave position (0.0 to 1.0 across all dots)
                                      final wavePosition =
                                          cycleProgress *
                                          (totalDots + 1); // 0.0 to 4.0

                                      // Calculate distance from wave position to this dot
                                      final dotIndex = i.toDouble();
                                      final distance = (wavePosition - dotIndex)
                                          .abs();

                                      // Create a smooth pulse effect as wave passes
                                      double activeValue;
                                      if (distance < 1.0) {
                                        // Wave is near this dot - create smooth pulse
                                        activeValue =
                                            1.0 -
                                            distance; // 1.0 when wave is at dot, 0.0 when 1.0 away
                                      } else {
                                        // Wave is far from this dot
                                        activeValue = 0.0;
                                      }

                                      // Apply smooth easing
                                      activeValue = activeValue.clamp(0.0, 1.0);
                                      final scale =
                                          0.6 +
                                          (activeValue * 0.4); // 0.6 to 1.0
                                      final opacity =
                                          0.5 +
                                          (activeValue * 0.5); // 0.5 to 1.0

                                      return Transform.scale(
                                        scale: scale,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: AppColors.geniePurple,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.geniePurple.withOpacity(
                                        0.3,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
