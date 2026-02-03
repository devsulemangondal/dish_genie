import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/app_open_ad_manager.dart';
import '../services/ad_service.dart';
import '../providers/premium_provider.dart';
import '../l10n/app_localizations.dart';

/// Full-screen loader for App Open Ad
/// Shows loader, loads ad, shows ad, then navigates back
class AppOpenAdLoaderScreen extends StatefulWidget {
  const AppOpenAdLoaderScreen({super.key});

  @override
  State<AppOpenAdLoaderScreen> createState() => _AppOpenAdLoaderScreenState();
}

class _AppOpenAdLoaderScreenState extends State<AppOpenAdLoaderScreen> {
  String _dots = '';
  bool _adShown = false;
  bool _isLoading = false;
  DateTime? _screenStartTime;
  static const Duration _minDisplayTime = Duration(milliseconds: 1500); // Minimum 1.5 seconds

  @override
  void initState() {
    super.initState();
    _screenStartTime = DateTime.now();
    if (kDebugMode) {
      print('🚀 [LoaderScreen] initState() called');
    }
    // Ensure screen is visible immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    });
    _animateDots();
    // Small delay to ensure screen is rendered before loading ad
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadAndShowAd();
      }
    });
  }

  void _animateDots() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && !_adShown) {
        setState(() {
          _dots = _dots.length >= 3 ? '' : _dots + '.';
        });
        return mounted && !_adShown;
      }
      return false;
    });
  }

  Future<void> _loadAndShowAd() async {
    // Prevent multiple simultaneous ad loads
    if (_isLoading || _adShown) {
      if (kDebugMode) {
        print('⚠️ [LoaderScreen] Ad already loading or shown, skipping');
      }
      return;
    }

    _isLoading = true;

    try {
      if (kDebugMode) {
        print('📥 [LoaderScreen] Starting ad load process...');
      }

      // Check premium status
      final premiumProvider = Provider.of<PremiumProvider>(
        context,
        listen: false,
      );
      if (premiumProvider.isPremium) {
        if (kDebugMode) {
          print('⚠️ [LoaderScreen] Premium user, skipping ad');
        }
        _isLoading = false;
        _navigateBack();
        return;
      }

      // Load ad using the manager with timeout
      final adManager = AppOpenAdManager.instance;
      if (kDebugMode) {
        print('📥 [LoaderScreen] Calling loadAd()...');
      }
      final ad = await adManager.loadAd().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          if (kDebugMode) {
            print('⏱️ [LoaderScreen] Ad loading timed out after 12 seconds');
          }
          return null;
        },
      );

      if (kDebugMode) {
        print(
          '📊 [LoaderScreen] loadAd() returned: ${ad != null ? "ad loaded" : "null"}',
        );
      }

      if (!mounted) {
        _isLoading = false;
        return;
      }

      if (ad == null) {
        if (kDebugMode) {
          print('⚠️ [LoaderScreen] Ad not loaded (null), navigating back');
        }
        _isLoading = false;
        // Ensure minimum display time before navigating back
        await _ensureMinimumDisplayTime();
        // Reset resuming flag if ad failed to load
        Future.delayed(const Duration(milliseconds: 500), () {
          AppOpenAdManager.instance.resetResuming();
        });
        if (mounted) {
          _navigateBack();
        }
        return;
      }

      if (kDebugMode) {
        print(
          '✅ [LoaderScreen] Ad loaded successfully, waiting a moment before showing...',
        );
      }

      // Small delay to ensure ad is fully ready
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) {
        _isLoading = false;
        try {
          ad.dispose();
        } catch (_) {}
        return;
      }

      // Show ad
      _showAd(ad);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [LoaderScreen] Error loading ad: $e');
        print('Stack trace: $stackTrace');
      }
      _isLoading = false;
      // Ensure minimum display time before navigating back
      await _ensureMinimumDisplayTime();
      // Reset resuming flag on error
      Future.delayed(const Duration(milliseconds: 500), () {
        AppOpenAdManager.instance.resetResuming();
      });
      if (mounted) {
        _navigateBack();
      }
    }
  }

  /// Ensure the loader screen is displayed for a minimum amount of time
  /// This prevents the screen from flashing too quickly
  Future<void> _ensureMinimumDisplayTime() async {
    if (_screenStartTime == null) return;
    
    final elapsed = DateTime.now().difference(_screenStartTime!);
    if (elapsed < _minDisplayTime) {
      final remaining = _minDisplayTime - elapsed;
      if (kDebugMode) {
        print(
          '⏱️ [LoaderScreen] Ensuring minimum display time: ${remaining.inMilliseconds}ms remaining',
        );
      }
      await Future.delayed(remaining);
    }
  }

  void _showAd(AppOpenAd ad) {
    // Double-check to prevent showing ad multiple times
    if (_adShown) {
      if (kDebugMode) {
        print('⚠️ [LoaderScreen] Ad already shown, disposing duplicate ad');
      }
      try {
        ad.dispose();
      } catch (_) {}
      return;
    }

    _adShown = true;
    _isLoading = false;

    // Update AppOpenAdManager state
    final adManager = AppOpenAdManager.instance;
    adManager.setShowingAd(true);
    adManager.setAppOpenAd(ad);

    if (kDebugMode) {
      print('🎬 [LoaderScreen] Setting up ad callbacks and showing ad...');
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('✅ [LoaderScreen] App Open Ad showed successfully');
        }
        // Dismiss loader screen immediately when ad is shown
        // Pop the loader screen so it's removed from navigation stack
        // When ad is dismissed, it will go directly to the previous route
        // Note: We don't clear the previous route here - it will be cleared after ad dismisses
        if (mounted) {
          if (kDebugMode) {
            print('📱 [LoaderScreen] Popping loader screen as ad is now showing');
          }
          // Pop the loader screen - this removes it from the stack
          // The ad is full screen, so user won't see the transition
          // When ad dismisses, it will return to the route before the loader
          if (context.canPop()) {
            context.pop();
          } else {
            // Fallback: navigate to previous route if can't pop
            // But don't clear previous route yet - will be cleared after ad dismisses
            final adManager = AppOpenAdManager.instance;
            final previousRoute = adManager.getPreviousRoute();
            if (previousRoute != null &&
                previousRoute.isNotEmpty &&
                previousRoute != '/app-open-ad-loader') {
              context.go(previousRoute);
            } else {
              context.go('/');
            }
          }
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('✅ [LoaderScreen] App Open Ad dismissed');
        }
        final adManager = AppOpenAdManager.instance;
        adManager.onAppOpenAdDismissed();
        adManager.setShowingAd(false);
        adManager.setAppOpenAd(null);
        // Notify AdService that app open ad was dismissed (for cooldown)
        AdService.notifyAppOpenAdDismissed();
        // Clear the stored previous route now that ad is dismissed
        adManager.clearPreviousRoute();
        // Reset resuming flag after a short delay to allow navigation to complete
        Future.delayed(const Duration(milliseconds: 500), () {
          adManager.resetResuming();
        });
        try {
          ad.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [LoaderScreen] Error disposing ad: $e');
          }
        }
        // Don't navigate here - loader was already popped when ad was shown
        // The ad dismissal will automatically return to the previous route
        // (which is now at the top of the stack since we popped the loader)
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          print(
            '❌ [LoaderScreen] App Open Ad failed to show: ${error.message} (code: ${error.code})',
          );
        }
        final adManager = AppOpenAdManager.instance;
        adManager.onAppOpenAdDismissed();
        adManager.setShowingAd(false);
        adManager.setAppOpenAd(null);
        // Notify AdService that app open ad was dismissed (for cooldown)
        AdService.notifyAppOpenAdDismissed();
        // Reset resuming flag after a short delay to allow navigation to complete
        Future.delayed(const Duration(milliseconds: 500), () {
          adManager.resetResuming();
        });
        try {
          ad.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [LoaderScreen] Error disposing failed ad: $e');
          }
        }
        if (mounted) {
          _navigateBack();
        }
      },
    );

    try {
      ad.show();
      if (kDebugMode) {
        print('📱 [LoaderScreen] ad.show() called');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [LoaderScreen] Exception calling ad.show(): $e');
        print('Stack trace: $stackTrace');
      }
      _adShown = false;
      _isLoading = false;
      try {
        ad.dispose();
      } catch (_) {}
      if (mounted) {
        _navigateBack();
      }
    }
  }

  void _navigateBack() {
    if (!mounted) return;

    // Get the previous route before ad was shown
    final adManager = AppOpenAdManager.instance;
    final previousRoute = adManager.getPreviousRoute();

    // Clear the stored route
    adManager.clearPreviousRoute();

    if (previousRoute != null &&
        previousRoute.isNotEmpty &&
        previousRoute != '/app-open-ad-loader') {
      // Navigate back to the previous route
      if (kDebugMode) {
        print(
          '📋 [LoaderScreen] Navigating back to previous route: $previousRoute',
        );
      }
      context.go(previousRoute);
    } else if (context.canPop()) {
      // Fallback: Pop this screen to go back
      if (kDebugMode) {
        print('📋 [LoaderScreen] Popping back');
      }
      context.pop();
    } else {
      // Final fallback: Navigate to home
      if (kDebugMode) {
        print('📋 [LoaderScreen] No previous route, navigating to home');
      }
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.background;

    // Ensure the screen is built immediately by scheduling a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force a frame update to ensure screen is visible
      WidgetsBinding.instance.ensureVisualUpdate();
    });

    return PopScope(
      canPop: false, // Prevent back button while loading
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loader icon - matching web app Loader2 icon size (w-12 h-12 = 48px)
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24), // gap-6 in web = 24px
              // Loading text with animated dots - matching web app
              Builder(
                builder: (context) {
                  // Use Directionality from context for reliable RTL detection
                  final textDirection = Directionality.of(context);
                  final isRTL = textDirection == TextDirection.rtl;
                  final localizations = AppLocalizations.of(context);
                  final loadingText = localizations?.adLoading ?? 'Loading ad';
                  // Remove existing dots from localization if present
                  final cleanText = loadingText.replaceAll('...', '').trim();
                  // In RTL, dots should appear on the left (start) side of the text
                  final textWithDots = isRTL
                      ? '$_dots$cleanText'
                      : '$cleanText$_dots';
                  return Text(
                    textWithDots,
                    textDirection: textDirection,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
