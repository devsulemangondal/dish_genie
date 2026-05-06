import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../providers/recipe_provider.dart';
import '../../services/ad_service.dart';
import '../../services/remote_config_service.dart';

/// Global back button handler.
///
/// Rules:
/// - If current route IS Home (`/`), show an exit confirmation bottom sheet.
/// - If current route is a main bottom nav tab (recipes, plan, shop, chat), go to Home.
/// - Otherwise: pop if possible, else go to parent route or Home.
class BackButtonHandler extends StatefulWidget {
  final Widget child;
  final List<String> homeRoutes;

  const BackButtonHandler({
    super.key,
    required this.child,
    this.homeRoutes = const ['/'],
  });

  @override
  State<BackButtonHandler> createState() => _BackButtonHandlerState();
}

class _BackButtonHandlerState extends State<BackButtonHandler> {
  bool _isReady = false;
  bool _isExitSheetOpen = false;

  @override
  void initState() {
    super.initState();
    // Delay enabling the handler to ensure router is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  /// Show exit confirmation bottom sheet
  Future<void> _showExitConfirmation(BuildContext context) async {
    if (!context.mounted) return;
    if (_isExitSheetOpen) return;

    _isExitSheetOpen = true;
    try {
      // Use rootNavigator to ensure the bottom sheet appears above everything
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: false,
        useRootNavigator: true, // Use root navigator to ensure it shows
        builder: (context) => const ExitConfirmationBottomSheet(
          bottomNavOverlap: kExitSheetBottomNavOverlapFallback,
        ),
      );
    } catch (e) {
      // If showing bottom sheet fails, reset the flag
      debugPrint('Error showing exit confirmation: $e');
    } finally {
      if (mounted) {
        _isExitSheetOpen = false;
      }
    }
  }

  String _currentPath(GoRouter router) {
    try {
      // Try multiple methods to get the current path for better reliability
      String? path;

      // Method 1: Try router.routerDelegate.currentConfiguration.uri.path (most reliable)
      try {
        final uri = router.routerDelegate.currentConfiguration.uri;
        path = uri.path;
      } catch (_) {}

      // Method 2: Try routerDelegate.currentConfiguration.last.matchedLocation
      if (path == null || path.isEmpty) {
        try {
          final config = router.routerDelegate.currentConfiguration;
          if (config.matches.isNotEmpty) {
            path = config.matches.last.matchedLocation;
          }
        } catch (_) {}
      }

      // Method 3: Try router.routeInformationProvider.value.uri.path
      if (path == null || path.isEmpty) {
        try {
          path = router.routeInformationProvider.value.uri.path;
        } catch (_) {}
      }

      // Method 4: Try router.routerDelegate.currentConfiguration.uri.toString() and parse
      if (path == null || path.isEmpty) {
        try {
          final fullUri = router.routerDelegate.currentConfiguration.uri
              .toString();
          final uri = Uri.parse(fullUri);
          path = uri.path;
        } catch (_) {}
      }

      if (path == null || path.isEmpty) return '/';

      // Normalize trailing slash (except for root '/')
      if (path.length > 1 && path.endsWith('/')) {
        return path.substring(0, path.length - 1);
      }
      return path;
    } catch (_) {
      return '/';
    }
  }

  /// Main bottom nav tabs: back should always go to home, never close app.
  static const _bottomNavRoutes = ['/recipes', '/planner', '/grocery', '/chat'];

  /// When on a "child" route (e.g. /grocery/:id), back should go to parent (e.g. /grocery).
  /// Returns the parent path or null if we should use default behavior (go to home).
  String? _parentRoute(String path) {
    if (RegExp(r'^/grocery/[^/]+$').hasMatch(path)) return '/grocery';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Only wrap with PopScope if the handler is ready
    // This prevents interference with app initialization
    if (!_isReady) {
      return widget.child;
    }

    // Use PopScope to intercept back button presses
    // canPop determines if we can pop naturally (if true, allow pop; if false, intercept)
    return PopScope(
      canPop: false, // Always intercept to handle custom logic
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Check immediately if exit sheet is open
          if (_isExitSheetOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).maybePop();
              }
            });
            return;
          }

          // Handle back button synchronously to avoid timing issues
          _handleBackButton(context);
        }
      },
      child: widget.child,
    );
  }

  void _handleBackButton(BuildContext context) {
    // Use post-frame callback to ensure context is fully built and route is stable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      // Double-check exit sheet state after frame
      if (_isExitSheetOpen) {
        Navigator.of(context, rootNavigator: true).maybePop();
        return;
      }

      // Get router and check route
      final router = GoRouter.maybeOf(context);
      if (router == null) return;

      // Get current route path - try multiple methods for reliability
      String routePath = '/';
      try {
        // Method 1: Try GoRouterState (most reliable)
        final routerState = GoRouterState.of(context);
        routePath = routerState.uri.path;
      } catch (_) {
        // Method 2: Try router delegate
        try {
          routePath = router.routerDelegate.currentConfiguration.uri.path;
        } catch (_) {
          // Method 3: Fallback to manual detection
          routePath = _currentPath(router);
        }
      }

      // Normalize the path
      if (routePath.isEmpty) {
        routePath = '/';
      } else if (routePath.length > 1 && routePath.endsWith('/')) {
        routePath = routePath.substring(0, routePath.length - 1);
      }

      final isHome = widget.homeRoutes.contains(routePath);
      final isBottomNavTab = _bottomNavRoutes.contains(routePath);

      // Home => confirm exit (defer while AI recipe is generating — home PopScope shows cancel dialog)
      if (isHome) {
        try {
          final rp = Provider.of<RecipeProvider>(context, listen: false);
          if (rp.isLoading) {
            return;
          }
        } catch (_) {}
        _showExitConfirmation(context);
        return;
      }

      // Bottom nav tabs: each tab's [PopScope] (or [MainTabShell] delegating
      // [Navigator.maybePop] to the branch) handles back — e.g. meal planner
      // cancel-while-loading. Do not [router.go] here; it raced those handlers.
      if (isBottomNavTab) {
        return;
      }

      // Child routes (e.g. /grocery/:id) => go to parent
      final parent = _parentRoute(routePath);
      if (parent != null) {
        router.go(parent);
        return;
      }

      // Other routes => pop if possible, else go home
      if (context.canPop()) {
        context.pop();
      } else {
        router.go('/');
      }
    });
  }
}

/// Fallback bottom inset when the live [BottomNav] height cannot be read yet.
/// Clears the tab row + typical banner strip above system gesture / nav bar.
const double kExitSheetBottomNavOverlapFallback = 108;

/// Exit confirmation bottom sheet (exit interstitial + [SystemNavigator.pop]).
/// Used from [BackButtonHandler] and [MainTabShell].
class ExitConfirmationBottomSheet extends StatelessWidget {
  const ExitConfirmationBottomSheet({
    super.key,
    this.bottomNavOverlap = kExitSheetBottomNavOverlapFallback,
  });

  /// Extra space below the action row so buttons stay above the main tab bar
  /// when the sheet stacks with the shell (and for system inset via [SafeArea]).
  final double bottomNavOverlap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Text(
              context.t('exit.dialog.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              context.t('exit.dialog.message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: theme.dividerColor.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      context.t('exit.dialog.cancel'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Exit button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await RemoteConfigService.initialize();
                        await RemoteConfigService.fetchAndActivate();
                      } catch (_) {}
                      final shouldShowExitAd = Platform.isIOS
                          ? RemoteConfigService.exitInterIos
                          : RemoteConfigService.exitInter;

                      if (shouldShowExitAd) {
                        try {
                          if (context.mounted) {
                            await AdService.showInterstitialAdForType(
                              adType: 'exit',
                              context: context,
                              loadAdFunction: () =>
                                  AdService.loadExitInterstitialAd(),
                              onAdDismissed: () {
                                // App closes ONLY after user dismisses the ad
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                SystemNavigator.pop();
                              },
                              onAdFailedToShow: (_) {
                                // Ad failed to load/show - exit without waiting
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                SystemNavigator.pop();
                              },
                            );
                            return; // Do NOT fall through - exit happens in callbacks only
                          }
                        } catch (_) {}
                      }

                      // No ad shown - close sheet and exit
                      if (context.mounted) Navigator.of(context).pop();
                      SystemNavigator.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      context.t('exit.dialog.exit'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: bottomNavOverlap.clamp(0, 10)),
          ],
        ),
      ),
    );
  }
}
