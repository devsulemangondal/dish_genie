import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../services/storage_service.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../widgets/common/floating_sparkles.dart';
import '../../widgets/common/genie_mascot.dart';
import '../../widgets/common/rtl_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  late AnimationController _floatController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _steps = [
    {
      'titleKey': 'onboarding.step1.title',
      'descriptionKey': 'onboarding.step1.description',
      'icon': Icons.restaurant_menu,
      'gradient': [AppColors.geniePurple, AppColors.geniePink],
    },
    {
      'titleKey': 'onboarding.step2.title',
      'descriptionKey': 'onboarding.step2.description',
      'icon': Icons.calendar_today,
      'gradient': [AppColors.geniePink, AppColors.genieGold],
    },
    {
      'titleKey': 'onboarding.step3.title',
      'descriptionKey': 'onboarding.step3.description',
      'icon': Icons.shopping_cart,
      'gradient': [AppColors.genieGold, AppColors.geniePurple],
    },
    {
      'titleKey': 'onboarding.step4.title',
      'descriptionKey': 'onboarding.step4.description',
      'icon': Icons.auto_awesome,
      'gradient': [AppColors.genieLavender, AppColors.geniePink],
    },
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _scaleController.forward();
    _slideController.forward();
  }

  Future<void> _handleNext() async {
    if (_currentStep < _steps.length - 1) {
      _scaleController.reset();
      _slideController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(milliseconds: 100), () {
        _scaleController.forward();
        _slideController.forward();
      });
    } else {
      await StorageService.setOnboardingComplete(true);
      if (mounted) {
        // Navigate to pro screen after onboarding
        final opened = await ProNavigation.tryOpen(context, replace: true);
        if (!opened && mounted) {
          context.go('/');
        }
      }
    }
  }

  Future<void> _handleSkip() async {
    await StorageService.setOnboardingComplete(true);
    if (mounted) {
      // Navigate to pro screen after skipping onboarding
      final opened = await ProNavigation.tryOpen(context, replace: true);
      if (!opened && mounted) {
        context.go('/');
      }
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.getGradientHero(context),
            ),
          ),
          // Floating sparkles
          const FloatingSparkles(),
          // Main Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentStep = index);
                      _scaleController.reset();
                      _slideController.reset();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _scaleController.forward();
                        _slideController.forward();
                      });
                    },
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Mascot with float animation
                            AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _floatAnimation.value),
                                  child: const GenieMascot(size: GenieMascotSize.xl),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            // Icon with scale animation
                            AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: step['gradient'] as List<Color>,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (step['gradient'] as List<Color>)[0]
                                              .withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      step['icon'] as IconData,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            // Title with slide animation
                            AnimatedBuilder(
                              animation: _slideAnimation,
                              builder: (context, child) {
                                return SlideTransition(
                                  position: _slideAnimation,
                                  child: FadeTransition(
                                    opacity: _slideController,
                                    child: Text(
                                      context.t(step['titleKey'] as String),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Description with slide animation
                            AnimatedBuilder(
                              animation: _slideAnimation,
                              builder: (context, child) {
                                return SlideTransition(
                                  position: _slideAnimation,
                                  child: FadeTransition(
                                    opacity: _slideController,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        context.t(step['descriptionKey'] as String),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                          color: Colors.grey[600],
                                          height: 1.6,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Progress Dots & Button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      // Progress Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _steps.length,
                          (index) {
                            final isActive = index == _currentStep;
                            final isPast = index < _currentStep;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 32 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? LinearGradient(
                                        colors: AppColors.gradientPrimary.colors,
                                      )
                                    : null,
                                color: isActive
                                    ? null
                                    : isPast
                                        ? AppColors.primary.withOpacity(0.6)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Next Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_currentStep == _steps.length - 1) ...[
                                const Icon(Icons.check, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                _currentStep == _steps.length - 1
                                    ? context.t('onboarding.get.started')
                                    : context.t('onboarding.next'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentStep < _steps.length - 1) ...[
                                const SizedBox(width: 8),
                                const RtlForwardIcon(size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Skip Button - positioned on top of everything
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleSkip,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        context.t('onboarding.skip'),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
