import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/ad_config.dart';
import 'ad_service.dart';
import '../providers/premium_provider.dart';
import '../services/remote_config_service.dart';

/// Manages app open ads with proper lifecycle handling
/// Prevents showing ads at inappropriate times (permission dialogs, pro screen, etc.)
class AppOpenAdManager {
  AppOpenAdManager._privateConstructor();

  static final AppOpenAdManager instance =
      AppOpenAdManager._privateConstructor();

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  bool _isAdAvailable = false;
  bool _isResuming = false;

  // Suppress app-open ad/loader on the next resume (e.g. returning from image picker/camera)
  bool _suppressNextResume = false;
  DateTime? _suppressNextResumeUntil;
  String? _suppressNextResumeReason;

  // Track app start time to prevent showing ad on initial launch
  DateTime? _appStartTime;
  // Track if app has been paused at least once (to distinguish initial launch from resume)
  bool _hasBeenPaused = false;

  // Track ad timing (kept for potential future use, but not used for blocking)
  DateTime? _lastAdShownTime;
  DateTime? _lastAdLoadTime;
  DateTime? _lastAppOpenAdDismissedTime;

  // Cooldown period to prevent ads from chaining (interstitial -> app open -> interstitial)
  // Minimum time between interstitial dismissal and app open ad showing
  static const Duration _cooldownAfterInterstitial = Duration(seconds: 3);

  // Connectivity checker
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = true;

  // Callbacks
  VoidCallback? _onAdDismissed;
  Function()? _onAdShowed;

  // Track previous route before showing ad
  String? _previousRouteBeforeAd;

  // Navigator key for showing dialogs
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  BuildContext? _appContext;
  GoRouter? _router;

  bool get isAdAvailable => _isAdAvailable && _appOpenAd != null;
  bool get isShowingAd => _isShowingAd;

  /// Set the app context
  void setAppContext(BuildContext context) {
    _appContext = context;
  }

  /// Set the router (called from app.dart when router is created)
  void setRouter(GoRouter router) {
    _router = router;
    if (kDebugMode) {
      print('✅ [AppOpenAdManager] Router set');
    }
  }

  /// Reset resuming flag (used by loader screen after ad is dismissed)
  void resetResuming() {
    _isResuming = false;
  }

  /// Suppress the next resume-triggered app-open ad/loader attempt.
  ///
  /// Useful when launching external activities (image picker/camera) or other flows
  /// that background the app briefly and would otherwise trigger an app-open ad.
  void suppressNextResume({
    Duration duration = const Duration(minutes: 2),
    String? reason,
  }) {
    _suppressNextResume = true;
    _suppressNextResumeReason = reason;
    final now = DateTime.now();
    final newUntil = now.add(duration);
    if (_suppressNextResumeUntil == null ||
        _suppressNextResumeUntil!.isBefore(newUntil)) {
      _suppressNextResumeUntil = newUntil;
    }
    if (kDebugMode) {
      print(
        '🛑 [AppOpenAdManager] suppressNextResume set (reason=${_suppressNextResumeReason ?? 'unknown'}, until=$_suppressNextResumeUntil)',
      );
    }
  }

  bool _consumeSuppressNextResume() {
    if (!_suppressNextResume) return false;

    final until = _suppressNextResumeUntil;
    final now = DateTime.now();

    // If we have an "until" and it's expired, clear and allow resume flow.
    if (until != null && now.isAfter(until)) {
      if (kDebugMode) {
        print(
          '🟡 [AppOpenAdManager] suppressNextResume expired (reason=${_suppressNextResumeReason ?? 'unknown'}), allowing resume',
        );
      }
      _suppressNextResume = false;
      _suppressNextResumeUntil = null;
      _suppressNextResumeReason = null;
      return false;
    }

    // Consume suppression once.
    if (kDebugMode) {
      print(
        '🛑 [AppOpenAdManager] Suppressing resume-triggered app-open (reason=${_suppressNextResumeReason ?? 'unknown'})',
      );
    }
    _suppressNextResume = false;
    _suppressNextResumeUntil = null;
    _suppressNextResumeReason = null;
    return true;
  }

  /// Get the previous route before ad was shown
  String? getPreviousRoute() {
    return _previousRouteBeforeAd;
  }

  /// Clear the stored previous route
  void clearPreviousRoute() {
    _previousRouteBeforeAd = null;
  }

  /// Initialize the ad manager
  Future<void> initialize() async {
    // Record app start time to prevent showing ad on initial launch
    _appStartTime = DateTime.now();

    if (kDebugMode) {
      print('🚀 [AppOpenAdManager] Initialized at ${_appStartTime}');
    }

    // Check connectivity
    await _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _isConnected = results.any((result) => result != ConnectivityResult.none);

      // If we regain connectivity and don't have an ad, try to load one
      if (_isConnected && !_isAdAvailable && !_isLoadingAd) {
        _loadAd();
      }
    });

    // Only load ad if internet is available
    if (_isConnected) {
      await _loadAd();
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connectivity: $e');
      }
      _isConnected = false;
    }
  }

  /// Load app open ad (only if internet is available)
  Future<void> _loadAd() async {
    if (Platform.isIOS && !AdConfig.showAdsOnIos) return;

    // Don't load if already loading or ad is available
    if (_isLoadingAd || _isAdAvailable) return;

    // Don't load if no internet
    if (!_isConnected) return;

    // Check remote config first
    try {
      await RemoteConfigService.initialize();
      if (!RemoteConfigService.appOpen) return;
    } catch (e) {
      // Continue if remote config fails
    }

    // Note: Removed time-based rate limiting as requested
    // Ads will load on every resume attempt

    _isLoadingAd = true;
    _lastAdLoadTime = DateTime.now();

    try {
      // Ensure AdMob is fully initialized
      await AdService.initialize();

      // Add a small delay to ensure AdMob SDK is fully ready
      // This helps prevent "Ad unit doesn't match format" errors
      await Future.delayed(const Duration(milliseconds: 500));

      await AppOpenAd.load(
        adUnitId: AdService.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd?.dispose();
            _appOpenAd = ad;
            _isAdAvailable = true;
            _isLoadingAd = false;

            if (kDebugMode) {
              print('App Open Ad loaded successfully');
            }

            // Set up callbacks
            _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _onAdShowed?.call();
                if (kDebugMode) {
                  print('App Open Ad showed');
                }
              },
              onAdDismissedFullScreenContent: (ad) {
                _handleAdDismissed();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                _handleAdFailedToShow(ad, error);
              },
            );
          },
          onAdFailedToLoad: (error) {
            _appOpenAd = null;
            _isAdAvailable = false;
            _isLoadingAd = false;

            if (kDebugMode) {
              print(
                'App Open Ad failed to load: ${error.message} (code: ${error.code})',
              );

              // Provide helpful error messages for common issues
              if (error.code == 3) {
                print('⚠️ Error code 3: Ad unit format mismatch');
                print(
                  '   This usually means the ad unit ID is configured for a different ad format',
                );
                print('   or AdMob SDK may not be fully initialized');
              }
            }

            // Don't retry immediately - wait for minRetryDelay
          },
        ),
      );
    } catch (e) {
      _isLoadingAd = false;
      _isAdAvailable = false;
      if (kDebugMode) {
        print('Error loading App Open Ad: $e');
      }
    }
  }

  /// Handle ad dismissed (internal method)
  void _handleAdDismissed() {
    if (_appOpenAd != null) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
    }

    _isAdAvailable = false;
    _isShowingAd = false;
    _lastAdShownTime = DateTime.now();
    _lastAppOpenAdDismissedTime = DateTime.now();

    // Call callback
    _onAdDismissed?.call();

    // Preload next ad (but not immediately - respect rate limits)
    Future.delayed(const Duration(minutes: 1), () {
      if (_isConnected && !_isLoadingAd && !_isAdAvailable) {
        _loadAd();
      }
    });

    if (kDebugMode) {
      print('App Open Ad dismissed');
    }
  }

  /// Handle ad failed to show
  void _handleAdFailedToShow(AppOpenAd ad, AdError error) {
    ad.dispose();
    _appOpenAd = null;
    _isAdAvailable = false;
    _isShowingAd = false;

    if (kDebugMode) {
      print('App Open Ad failed to show: ${error.message}');
    }

    // Don't reload immediately
  }

  /// Show app open ad if appropriate
  /// Returns true if ad was shown, false otherwise
  bool showAdIfAvailable({
    required AppLifecycleState appState,
    String? currentRoute,
    PremiumProvider? premiumProvider,
    VoidCallback? onAdDismissed,
    Function()? onAdShowed,
  }) {
    // Don't show if already showing
    if (_isShowingAd) return false;

    // Don't show if no ad available
    if (!_isAdAvailable || _appOpenAd == null) return false;

    // Don't show if no internet (shouldn't happen, but check anyway)
    if (!_isConnected) return false;

    // Don't show if premium user
    if (premiumProvider != null && premiumProvider.isPremium) {
      return false;
    }

    // Don't show if app is not in resumed state
    if (appState != AppLifecycleState.resumed) {
      return false;
    }

    // Don't show on pro screen
    if (currentRoute != null &&
        (currentRoute.contains('/pro') || currentRoute == '/pro')) {
      return false;
    }

    // Note: Removed time-based check as requested
    // Ads will show on every resume (unless blocked by other conditions)

    // Don't show on splash screen, onboarding, or auth screens
    if (currentRoute != null) {
      final blockedRoutes = [
        '/splash',
        '/language-selection',
        '/language-picker',
        '/onboarding',
        '/auth',
      ];

      if (blockedRoutes.any((route) => currentRoute.contains(route))) {
        return false;
      }
    }

    // Store callbacks
    _onAdDismissed = onAdDismissed;
    _onAdShowed = onAdShowed;

    // Show the ad
    try {
      _isShowingAd = true;

      _appOpenAd!.show();

      return true;
    } catch (e) {
      _isShowingAd = false;
      if (kDebugMode) {
        print('Error showing App Open Ad: $e');
      }
      return false;
    }
  }

  /// Call this on app resume - navigates to loader screen
  void resume() {
    if (Platform.isIOS && !AdConfig.showAdsOnIos) return;

    if (kDebugMode) {
      print('========== RESUME CALLED ==========');
      print('📊 State: _isShowingAd=$_isShowingAd, _isResuming=$_isResuming');
      print(
        '📊 navigatorKey.currentState: ${navigatorKey.currentState != null}',
      );
      print(
        '📊 navigatorKey.currentContext: ${navigatorKey.currentContext != null}',
      );
      print('📊 _appContext: ${_appContext != null}');
      print('📊 _router: ${_router != null}');
    }

    // CRITICAL: Set flag immediately to prevent race conditions
    // Check and set atomically to prevent multiple simultaneous resume calls
    if (_isShowingAd || _isResuming) {
      if (kDebugMode) {
        print('⚠️ Ad or loader already showing, skipping resume flow');
      }
      return;
    }

    // Don't show ad on initial app launch - only show when resuming from background
    if (!_hasBeenPaused) {
      if (kDebugMode) {
        print(
          '⚠️ [AppOpenAdManager] App has not been paused yet (initial launch), skipping ad',
        );
      }
      return;
    }

    // Allow feature flows (image picker/camera/system UI) to suppress the next resume
    if (_consumeSuppressNextResume()) {
      return;
    }

    // Early check: Try to get current route immediately to block pro screen
    // This prevents setting _isResuming if we're on pro screen
    String? earlyRouteCheck;
    try {
      if (_router != null) {
        earlyRouteCheck = _router!.routerDelegate.currentConfiguration.uri
            .toString();
        // Normalize route (remove query params, trailing slashes)
        earlyRouteCheck = earlyRouteCheck.split('?').first;
        if (earlyRouteCheck.endsWith('/') && earlyRouteCheck.length > 1) {
          earlyRouteCheck = earlyRouteCheck.substring(
            0,
            earlyRouteCheck.length - 1,
          );
        }

        // Block if on pro screen - check multiple patterns
        if (earlyRouteCheck == '/pro' ||
            earlyRouteCheck.contains('/pro') ||
            earlyRouteCheck.startsWith('/pro') ||
            earlyRouteCheck.endsWith('/pro')) {
          if (kDebugMode) {
            print(
              '⚠️ [AppOpenAdManager] Early check: On pro screen ($earlyRouteCheck), skipping app open ad',
            );
          }
          return;
        }
      }
    } catch (e) {
      // If we can't get route early, continue - will check again later
      if (kDebugMode) {
        print('⚠️ [AppOpenAdManager] Could not get route for early check: $e');
      }
    }

    _isResuming = true;

    // Note: Removed time-based checks as requested
    // Ads will show on every resume (unless blocked by other conditions)

    // Don't show app open ad if an interstitial ad is currently showing
    if (AdService.isAnyInterstitialShowing) {
      if (kDebugMode) {
        print('⚠️ Interstitial ad is currently showing, skipping app open ad');
      }
      _isResuming = false;
      return;
    }

    // Check cooldown period after interstitial ad dismissal
    // This prevents app open ads from showing immediately after an interstitial is closed
    final lastInterstitialDismissed = AdService.lastInterstitialDismissedTime;
    if (lastInterstitialDismissed != null) {
      final timeSinceInterstitial = DateTime.now().difference(
        lastInterstitialDismissed,
      );
      if (timeSinceInterstitial < _cooldownAfterInterstitial) {
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] Cooldown active after interstitial dismissal: ${timeSinceInterstitial.inSeconds}s / ${_cooldownAfterInterstitial.inSeconds}s, skipping app open ad',
          );
        }
        _isResuming = false;
        return;
      }
    }

    // Use a delayed callback to ensure widget tree is ready
    // Try multiple times with increasing delays to ensure router is available
    Future.delayed(const Duration(milliseconds: 100), () async {
      await _attemptNavigateToLoader();
    });
  }

  /// Attempt to navigate to loader screen (with retries if router not available)
  Future<void> _attemptNavigateToLoader({int retryCount = 0}) async {
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 200);

    try {
      // Check conditions before showing loader
      final shouldShow = await _shouldShowLoader();
      if (!shouldShow) {
        if (kDebugMode) {
          print('⚠️ Conditions not met, skipping loader and ad');
        }
        _isResuming = false;
        return;
      }

      // Navigate to loader screen immediately - don't wait for post-frame
      // This ensures the loader appears instantly on resume
      try {
        if (kDebugMode) {
          print(
            '📱 [AppOpenAdManager] Attempting to navigate to loader screen (attempt ${retryCount + 1}/$maxRetries)',
          );
        }

        // Try multiple methods to get the router
        GoRouter? router;
        String? currentRoute;

        // Method 1: Use stored router (most reliable)
        if (_router != null) {
          router = _router;
          try {
            currentRoute = router!.routerDelegate.currentConfiguration.uri
                .toString();
            if (kDebugMode) {
              print('✅ [AppOpenAdManager] Using stored router');
              print('📊 [AppOpenAdManager] Current route: $currentRoute');
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '⚠️ [AppOpenAdManager] Failed to get route from stored router: $e',
              );
            }
          }
        }

        // Method 2: Try to get router from context (if stored router didn't work)
        if (router == null) {
          BuildContext? context = _appContext;
          if (context == null || !context.mounted) {
            context = navigatorKey.currentContext;
          }

          if (context != null && context.mounted) {
            try {
              router = GoRouter.of(context);
              currentRoute = router.routerDelegate.currentConfiguration.uri
                  .toString();
              if (kDebugMode) {
                print(
                  '✅ [AppOpenAdManager] Got router from GoRouter.of(context)',
                );
                print('📊 [AppOpenAdManager] Current route: $currentRoute');
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ [AppOpenAdManager] GoRouter.of(context) failed: $e');
              }
            }
          }
        }

        // Method 3: Try router's navigatorKey (last resort)
        if (router == null) {
          try {
            final routerNavKey = _router?.routerDelegate.navigatorKey;
            final navContext = routerNavKey?.currentContext;
            if (navContext != null && navContext.mounted) {
              router = GoRouter.of(navContext);
              currentRoute = router.routerDelegate.currentConfiguration.uri
                  .toString();
              if (kDebugMode) {
                print(
                  '✅ [AppOpenAdManager] Got router from router navigatorKey',
                );
                print('📊 [AppOpenAdManager] Current route: $currentRoute');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '⚠️ [AppOpenAdManager] Failed to get router from navigatorKey: $e',
              );
            }
          }
        }

        // If router is still null, retry if we haven't exceeded max retries
        if (router == null) {
          if (retryCount < maxRetries) {
            if (kDebugMode) {
              print(
                '⚠️ [AppOpenAdManager] Router not available yet, retrying in ${retryDelay.inMilliseconds}ms...',
              );
            }
            Future.delayed(retryDelay, () {
              _attemptNavigateToLoader(retryCount: retryCount + 1);
            });
            return;
          } else {
            if (kDebugMode) {
              print(
                '❌ [AppOpenAdManager] Could not get router from any method after $maxRetries attempts',
              );
              print('  - Stored router: ${_router != null}');
              print(
                '  - _appContext: ${_appContext != null ? (_appContext!.mounted ? "mounted" : "not mounted") : "null"}',
              );
              print(
                '  - navigatorKey.currentContext: ${navigatorKey.currentContext != null}',
              );
            }
            _isResuming = false;
            return;
          }
        }

        // CRITICAL: Don't navigate if already on loader screen (prevents multiple ads)
        if (currentRoute == '/app-open-ad-loader') {
          if (kDebugMode) {
            print(
              '⚠️ [AppOpenAdManager] Already on loader screen, skipping navigation',
            );
          }
          _isResuming = false;
          return;
        }

        // Don't show app open ad on pro screen
        // Normalize route for comparison (remove query params, trailing slashes)
        String? normalizedRoute = currentRoute;
        if (normalizedRoute != null) {
          normalizedRoute = normalizedRoute.split('?').first;
          if (normalizedRoute.endsWith('/') && normalizedRoute.length > 1) {
            normalizedRoute = normalizedRoute.substring(
              0,
              normalizedRoute.length - 1,
            );
          }

          if (normalizedRoute == '/pro' ||
              normalizedRoute.contains('/pro') ||
              normalizedRoute.startsWith('/pro')) {
            if (kDebugMode) {
              print(
                '⚠️ [AppOpenAdManager] On pro screen (normalized: $normalizedRoute, original: $currentRoute), skipping app open ad',
              );
            }
            _isResuming = false;
            return;
          }
        }

        // Double-check: Don't show if interstitial is currently showing
        if (AdService.isAnyInterstitialShowing) {
          if (kDebugMode) {
            print(
              '⚠️ [AppOpenAdManager] Interstitial ad is showing, skipping app open ad',
            );
          }
          _isResuming = false;
          return;
        }

        // Check cooldown period after interstitial ad dismissal
        final lastInterstitialDismissed =
            AdService.lastInterstitialDismissedTime;
        if (lastInterstitialDismissed != null) {
          final timeSinceInterstitial = DateTime.now().difference(
            lastInterstitialDismissed,
          );
          if (timeSinceInterstitial < _cooldownAfterInterstitial) {
            if (kDebugMode) {
              print(
                '⚠️ [AppOpenAdManager] Cooldown active after interstitial dismissal: ${timeSinceInterstitial.inSeconds}s / ${_cooldownAfterInterstitial.inSeconds}s, skipping app open ad',
              );
            }
            _isResuming = false;
            return;
          }
        }

        // Mark that we're showing an ad (prevent loops) - only after confirming we'll navigate
        _lastAdShownTime = DateTime.now();

        // Store the current route before navigating to ad loader
        if (currentRoute != '/app-open-ad-loader') {
          _previousRouteBeforeAd = currentRoute;
          if (kDebugMode) {
            print(
              '📋 [AppOpenAdManager] Stored previous route: $_previousRouteBeforeAd',
            );
          }
        }

        try {
          if (kDebugMode) {
            print('✅ [AppOpenAdManager] Pushing loader screen (keep current route under stack)...');
          }
          // Use push so when loader is popped after ad, user returns to the screen they were on
          router.push('/app-open-ad-loader');
          if (kDebugMode) {
            print(
              '✅ [AppOpenAdManager] Pushed loader screen successfully',
            );
          }
          // Force visual update to ensure screen is shown immediately
          WidgetsBinding.instance.ensureVisualUpdate();
          // Schedule another frame to ensure screen renders
          WidgetsBinding.instance.scheduleFrame();
          // Don't reset _isResuming here - let loader screen handle it
          return;
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ [AppOpenAdManager] Navigation failed: $e');
            print('Stack trace: $stackTrace');
          }
          _isResuming = false;
          _lastAdShownTime = null; // Reset on error
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('❌ [AppOpenAdManager] Failed to navigate to loader screen: $e');
          print('Stack trace: $stackTrace');
        }
        _isResuming = false;
        _lastAdShownTime = null; // Reset on error
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Exception in resume flow: $e');
        print('Stack trace: $stackTrace');
      }
      _isResuming = false;
      _lastAdShownTime = null; // Reset on error
    }
    // Note: Don't reset _isResuming in finally - let loader screen reset it when ad is dismissed
  }

  /// Check if loader should be shown
  Future<bool> _shouldShowLoader() async {
    try {
      if (Platform.isIOS && !AdConfig.showAdsOnIos) return false;

      if (kDebugMode) {
        print('🔍 [AppOpenAdManager] Checking if loader should be shown...');
      }

      // Don't show ad on initial app launch - check if app has been paused
      // This is a more reliable check than time-based
      if (!_hasBeenPaused) {
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] App has not been paused yet (initial launch), skipping',
          );
        }
        return false;
      }

      // Note: Removed time-based safety check as requested
      // Ads will show immediately after app has been paused at least once

      // Check internet
      await _checkConnectivity();
      if (!_isConnected) {
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] No internet connection, skipping loader',
          );
        }
        return false;
      }

      // Check remote config
      try {
        await RemoteConfigService.initialize();
        final appOpenEnabled = RemoteConfigService.appOpen;
        if (kDebugMode) {
          print(
            '📊 [AppOpenAdManager] Remote config app_open: $appOpenEnabled',
          );
        }
        if (!appOpenEnabled) {
          if (kDebugMode) {
            print(
              '⚠️ [AppOpenAdManager] App open ad disabled in remote config, skipping loader',
            );
          }
          return false;
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] Remote config check failed, continuing: $e',
          );
        }
        // Continue if remote config fails - default to showing
      }

      // Don't show if interstitial ad is currently showing
      if (AdService.isAnyInterstitialShowing) {
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] Interstitial ad is currently showing, skipping loader',
          );
        }
        return false;
      }

      // Check cooldown period after interstitial ad dismissal
      final lastInterstitialDismissed = AdService.lastInterstitialDismissedTime;
      if (lastInterstitialDismissed != null) {
        final timeSinceInterstitial = DateTime.now().difference(
          lastInterstitialDismissed,
        );
        if (timeSinceInterstitial < _cooldownAfterInterstitial) {
          if (kDebugMode) {
            print(
              '⚠️ [AppOpenAdManager] Cooldown active after interstitial dismissal: ${timeSinceInterstitial.inSeconds}s / ${_cooldownAfterInterstitial.inSeconds}s, skipping loader',
            );
          }
          return false;
        }
      }

      // Try to check current route to avoid showing on pro screen
      // This is a best-effort check - main check happens in _attemptNavigateToLoader
      try {
        if (_router != null) {
          String currentRoute = _router!.routerDelegate.currentConfiguration.uri
              .toString();
          // Normalize route (remove query params, trailing slashes)
          currentRoute = currentRoute.split('?').first;
          if (currentRoute.endsWith('/') && currentRoute.length > 1) {
            currentRoute = currentRoute.substring(0, currentRoute.length - 1);
          }

          if (currentRoute == '/pro' ||
              currentRoute.contains('/pro') ||
              currentRoute.startsWith('/pro')) {
            if (kDebugMode) {
              print(
                '⚠️ [AppOpenAdManager] On pro screen (normalized: $currentRoute), skipping loader',
              );
            }
            return false;
          }
        }
      } catch (e) {
        // If we can't get route, continue - main check will happen in navigation
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] Could not check route in _shouldShowLoader, will check during navigation: $e',
          );
        }
      }

      // Note: We don't check for router/context availability here
      // because the retry mechanism in _attemptNavigateToLoader will handle that
      // This allows the loader to show even if router isn't immediately available

      if (kDebugMode) {
        print(
          '✅ [AppOpenAdManager] All conditions met, loader should be shown',
        );
        print('  - Internet: $_isConnected');
        print('  - Remote config app_open: ${RemoteConfigService.appOpen}');
        print(
          '  - Interstitial showing: ${AdService.isAnyInterstitialShowing}',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AppOpenAdManager] Exception checking loader conditions: $e');
      }
      return false;
    }
  }

  /// Set showing ad state (used by loader screen)
  void setShowingAd(bool value) {
    _isShowingAd = value;
    if (kDebugMode) {
      print('📊 [AppOpenAdManager] setShowingAd($value)');
    }
  }

  /// Set app open ad (used by loader screen)
  void setAppOpenAd(AppOpenAd? ad) {
    _appOpenAd = ad;
    _isAdAvailable = ad != null;
    if (kDebugMode) {
      print('📊 [AppOpenAdManager] setAppOpenAd(${ad != null})');
    }
  }

  /// Loads an App Open Ad (public method for loader screen)
  /// Retries once if error code 3 occurs (format mismatch - often transient)
  Future<AppOpenAd?> loadAd({int retryCount = 0}) async {
    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      return null;
    }
    if (kDebugMode) {
      print(
        '📥 [AppOpenAdManager] loadAd() called (attempt ${retryCount + 1})',
      );
    }

    Completer<AppOpenAd?> completer = Completer();

    try {
      if (!_isConnected) {
        if (kDebugMode) {
          print('⚠️ [AppOpenAdManager] No internet, cannot load ad');
        }
        completer.complete(null);
        return completer.future;
      }

      // Check remote config
      try {
        await RemoteConfigService.initialize();
        if (!RemoteConfigService.appOpen) {
          if (kDebugMode) {
            print(
              '⚠️ [AppOpenAdManager] App open ad disabled in remote config',
            );
          }
          completer.complete(null);
          return completer.future;
        }
      } catch (e) {
        // Continue if remote config fails
        if (kDebugMode) {
          print(
            '⚠️ [AppOpenAdManager] Remote config check failed, continuing: $e',
          );
        }
      }

      // Ensure AdMob is fully initialized before loading
      await AdService.initialize();

      // Add a longer delay to ensure AdMob SDK is fully ready
      // Error code 3 (ad unit format mismatch) often occurs when SDK isn't fully initialized
      // Increasing delay helps prevent this error
      // On retry, use a longer delay
      final delay = retryCount > 0
          ? const Duration(milliseconds: 2000)
          : const Duration(milliseconds: 1000);
      await Future.delayed(delay);

      if (kDebugMode) {
        print('📥 [AppOpenAdManager] Starting to load app open ad...');
        print('📡 [AppOpenAdManager] Ad Unit ID: ${AdService.appOpenAdUnitId}');
      }

      AppOpenAd.load(
        adUnitId: AdService.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (kDebugMode) {
              print('✅ [AppOpenAdManager] App Open Ad loaded successfully');
            }
            // Dispose old ad if exists
            if (_appOpenAd != null && _appOpenAd != ad) {
              _appOpenAd?.dispose();
            }
            _appOpenAd = ad;
            _isAdAvailable = true;
            if (!completer.isCompleted) {
              completer.complete(ad);
            }
          },
          onAdFailedToLoad: (error) {
            if (kDebugMode) {
              print(
                '❌ [AppOpenAdManager] App Open Ad failed to load: ${error.message} (code: ${error.code}, domain: ${error.domain})',
              );

              // Provide helpful error messages for common issues
              if (error.code == 3) {
                print(
                  '⚠️ [AppOpenAdManager] Error code 3: Ad unit format mismatch',
                );
                print('   This usually means:');
                print(
                  '   1. The ad unit ID is configured for a different ad format in AdMob',
                );
                print('   2. AdMob SDK may not be fully initialized');
                print(
                  '   3. For test ads, ensure you\'re using the correct test ad unit ID',
                );
                print(
                  '   Test App Open Ad Unit ID (Android): ca-app-pub-3940256099942544/9257395921',
                );

                // Retry once for error code 3 (format mismatch - often transient)
                if (retryCount == 0) {
                  print(
                    '🔄 [AppOpenAdManager] Retrying ad load after error code 3...',
                  );
                  Future.delayed(const Duration(milliseconds: 500), () async {
                    final retryAd = await loadAd(retryCount: 1);
                    if (!completer.isCompleted) {
                      completer.complete(retryAd);
                    }
                  });
                  return; // Don't complete with null yet - wait for retry
                }
              }
            }
            _appOpenAd = null;
            _isAdAvailable = false;
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
        ),
      );

      // Add timeout to prevent indefinite waiting
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          if (kDebugMode) {
            print('⏱️ [AppOpenAdManager] Ad loading timeout after 10 seconds');
          }
          completer.complete(null);
        }
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [AppOpenAdManager] Exception loading ad: $e');
        print('Stack trace: $stackTrace');
      }
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }

  /// Called when an app open ad is dismissed
  void onAppOpenAdDismissed() {
    _lastAppOpenAdDismissedTime = DateTime.now();
    // Also bump "shown" time so short-window checks still protect
    _lastAdShownTime = _lastAppOpenAdDismissedTime;
    if (kDebugMode) {
      print('📋 App open ad dismissed, starting cooldown to prevent loops');
    }
    // Note: We don't set a flag here to block interstitial ads because
    // interstitial ads are triggered by user actions, not lifecycle events.
    // The cooldown after interstitial dismissal is handled in resume() method.
  }

  /// Update app lifecycle state (kept for backward compatibility)
  void updateAppState(AppLifecycleState state) {
    // Use resume() method instead
    if (state == AppLifecycleState.resumed) {
      resume();
    }
  }

  /// Update current route (for tracking purposes)
  void updateRoute(String? route) {
    // Route is checked in showAdIfAvailable method
  }

  /// Call this on app pause
  void pause() {
    if (kDebugMode) {
      print('⏸️ Pause called');
    }
    // Mark that app has been paused (so we know it's a real resume, not initial launch)
    _hasBeenPaused = true;
    // Nothing special needed here, loader/ad flow handled on resume
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isAdAvailable = false;
    _isShowingAd = false;
    _isLoadingAd = false;
    _isResuming = false;
    _lastAdShownTime = null;
    _lastAppOpenAdDismissedTime = null;
    _previousRouteBeforeAd = null;
    _suppressNextResume = false;
    _suppressNextResumeUntil = null;
    _suppressNextResumeReason = null;
  }
}
