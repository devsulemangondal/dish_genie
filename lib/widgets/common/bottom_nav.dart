import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../services/card_ad_tracker.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';
import '../../providers/premium_provider.dart';
import '../../core/router/app_router.dart';

class BottomNav extends StatelessWidget {
  final String activeTab;
  final bool hideWhenKeyboardVisible;

  const BottomNav({
    super.key,
    required this.activeTab,
    this.hideWhenKeyboardVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(
      context,
    ).textScaleFactor.clamp(0.8, 1.2);

    // Hide bottom nav when keyboard is visible
    if (hideWhenKeyboardVisible && isKeyboardVisible) {
      return const SizedBox.shrink();
    }

    // Calculate responsive values based on screen width
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    final horizontalPadding = isSmallScreen
        ? 2.0
        : (isMediumScreen ? 3.0 : 4.0);
    final verticalPadding = isSmallScreen ? 2.0 : (isMediumScreen ? 3.0 : 4.0);

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  label: context.t('common.home'),
                  isActive: activeTab == 'home',
                  onTap: () => context.go('/'),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.restaurant_menu_outlined,
                  label: context.t('common.recipes'),
                  isActive: activeTab == 'recipes',
                  onTap: () => context.go('/recipes'),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_month_outlined,
                  label: context.t('common.plan'),
                  isActive: activeTab == 'planner',
                  onTap: () => context.go('/planner'),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.shopping_cart_outlined,
                  label: context.t('common.shop'),
                  isActive: activeTab == 'grocery',
                  onTap: () => context.go('/grocery'),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.chat_bubble_outline,
                  label: context.t('common.chat'),
                  isActive: activeTab == 'chat',
                  onTap: () => context.go('/chat'),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double screenWidth;
  final double textScaleFactor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.screenWidth,
    required this.textScaleFactor,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isProcessing = false;

  Future<void> _handleTap() async {
    // Prevent double taps - debounce mechanism
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Navigate immediately first (user tap > navigate)
      widget.onTap();

      // Check if user is premium (premium users don't see ads)
      final premiumProvider = Provider.of<PremiumProvider>(
        context,
        listen: false,
      );
      if (premiumProvider.isPremium) {
        return;
      }

      // Get the bottom_inter configuration (single integer string or "off")
      final bottomInterConfig = RemoteConfigService.bottomInter
          .trim()
          .toLowerCase();

      // Check if bottom_inter is "off" - if so, don't show ad
      if (bottomInterConfig == 'off' || bottomInterConfig.isEmpty) {
        return;
      }

      // Get current count BEFORE incrementing
      final currentCount = await CardAdTracker.getBottomNavCount();

      // Parse the threshold value (single integer string)
      int threshold = 0;
      try {
        threshold = int.parse(bottomInterConfig);
      } catch (e) {
        // If parsing fails, don't show ad
        return;
      }

      if (threshold <= 0) {
        return;
      }

      // Check if we should show ad BEFORE incrementing
      // We want to show ad when the NEXT tap will reach the threshold
      // So if currentCount + 1 == threshold, show ad
      final shouldShowAd = (currentCount + 1) == threshold;

      // Always increment the counter
      await CardAdTracker.trackBottomNavTap();

      if (shouldShowAd) {
        // Wait a brief moment for navigation to complete, then show loader and ad
        // This ensures the new screen is ready before showing the loader
        await Future.delayed(const Duration(milliseconds: 150));

        // Get the root navigator context from the router to ensure we have a valid context
        // after navigation (AdService uses rootNavigator: true anyway)
        final navigatorKey = AppRouter.getNavigatorKey();
        final navigatorContext = navigatorKey?.currentContext;

        // Check if context is still mounted after navigation
        if (!mounted || navigatorContext == null || !navigatorContext.mounted) {
          return;
        }

        // Show ad with loader (loader is handled in AdService)
        // Loader will show instantly, then ad will show
        await AdService.showInterstitialAdForType(
          adType: 'bottom',
          context: navigatorContext,
          loadAdFunction: () => AdService.loadBottomInterstitialAd(),
          onAdDismissed: () {
            // Reset counter after ad is shown
            CardAdTracker.resetBottomNavCount();
            // Don't navigate again - we already navigated before showing ad
          },
          onAdFailedToShow: (ad) {
            // Reset counter even if ad fails to show
            CardAdTracker.resetBottomNavCount();
            // Don't navigate again - we already navigated before showing ad
          },
        );
      }
    } finally {
      // Reset processing flag after a delay to prevent rapid taps
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive values based on screen width
    final isSmallScreen = widget.screenWidth < 360;
    final isMediumScreen =
        widget.screenWidth >= 360 && widget.screenWidth < 400;

    // Responsive icon size
    final iconSize = isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0);

    // Responsive font size (adjusted for text scale factor)
    final baseFontSize = isSmallScreen ? 9.0 : (isMediumScreen ? 10.0 : 11.0);
    final fontSize = baseFontSize * widget.textScaleFactor;

    // Responsive padding
    final horizontalPadding = isSmallScreen
        ? 2.0
        : (isMediumScreen ? 3.0 : 4.0);
    final verticalPadding = isSmallScreen ? 4.0 : (isMediumScreen ? 5.0 : 6.0);
    final spacing = isSmallScreen ? 1.0 : 2.0;

    // Responsive border radius
    final borderRadius = isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0);

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          gradient: widget.isActive ? AppColors.gradientPrimary : null,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: widget.isActive ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.icon,
                size: iconSize,
                color: widget.isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            SizedBox(height: spacing),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: widget.isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
