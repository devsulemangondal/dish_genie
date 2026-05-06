import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../services/interstitial_ad_helper.dart';
import '../ads/bottom_banner_ad_widget.dart';

/// Shared lock to prevent double interstitial when tapping bottom nav rapidly
bool _bottomNavProcessing = false;

class BottomNav extends StatelessWidget {
  /// When null, [activeTab] and [context.go] are used (e.g. legacy `/home`).
  final StatefulNavigationShell? navigationShell;
  final String activeTab;
  final bool hideWhenKeyboardVisible;
  /// Stable key for the bottom banner when using [navigationShell] (main tab shell).
  final GlobalKey? bannerKey;

  /// Optional key on the outer bar (tabs + banner) for measuring height (e.g. exit sheet padding).
  final Key? bottomBarMeasureKey;

  const BottomNav({
    super.key,
    this.navigationShell,
    this.activeTab = 'home',
    this.hideWhenKeyboardVisible = true,
    this.bannerKey,
    this.bottomBarMeasureKey,
  }) : assert(
          navigationShell == null || bannerKey != null,
          'Use bannerKey with navigationShell so the banner keeps one AdWidget.',
        );

  static const List<String> _tabIds = [
    'home',
    'recipes',
    'planner',
    'grocery',
    'chat',
  ];

  bool _isActive(int index) {
    if (navigationShell != null) {
      return navigationShell!.currentIndex == index;
    }
    return activeTab == _tabIds[index];
  }

  void _goBranch(BuildContext context, int index) {
    if (navigationShell != null) {
      final shell = navigationShell!;
      shell.goBranch(
        index,
        initialLocation: index == shell.currentIndex,
      );
      return;
    }
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/recipes');
        break;
      case 2:
        context.go('/planner');
        break;
      case 3:
        context.go('/grocery');
        break;
      case 4:
        context.go('/chat');
        break;
    }
  }

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
      key: bottomBarMeasureKey,
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
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
                      isActive: _isActive(0),
                      onTap: () => _goBranch(context, 0),
                      screenWidth: screenWidth,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.restaurant_menu_outlined,
                      label: context.t('common.recipes'),
                      isActive: _isActive(1),
                      onTap: () => _goBranch(context, 1),
                      screenWidth: screenWidth,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.calendar_month_outlined,
                      label: context.t('common.plan'),
                      isActive: _isActive(2),
                      onTap: () => _goBranch(context, 2),
                      screenWidth: screenWidth,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.shopping_cart_outlined,
                      label: context.t('common.shop'),
                      isActive: _isActive(3),
                      onTap: () => _goBranch(context, 3),
                      screenWidth: screenWidth,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.chat_bubble_outline,
                      label: context.t('common.chat'),
                      isActive: _isActive(4),
                      onTap: () => _goBranch(context, 4),
                      screenWidth: screenWidth,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                ],
              ),
            ),
            if (navigationShell == null)
              const BottomBannerAdWidget()
            else
              BottomBannerAdWidget(key: bannerKey),
          ],
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
    // Prevent double taps - global lock for all nav items (rapid switching)
    if (_isProcessing || _bottomNavProcessing) {
      return;
    }

    _bottomNavProcessing = true;
    setState(() {
      _isProcessing = true;
    });

    try {
      final switchingTab = !widget.isActive;
      widget.onTap();
      if (switchingTab) {
        InterstitialAdHelper.showBottomTabInterstitial(context: context);
      }
    } finally {
      // Reset both flags after a delay to prevent rapid taps
      Future.delayed(const Duration(milliseconds: 600), () {
        _bottomNavProcessing = false;
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
