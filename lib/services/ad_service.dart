import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'remote_config_service.dart';
import 'storage_service.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../core/router/app_router.dart';

class AdService {
  // Test Ad Unit IDs (for development)
  static const String _testNativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  // Official Google test App Open Ad Unit ID for Android
  // Source: https://developers.google.com/admob/android/test-ads
  static const String _testAppOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

  // Production Ad Unit IDs (from the plan)
  static const String _productionAppOpenAdUnitId = 'ca-app-pub-6882687050623219/2543111627';
  static const String _productionSplashInterAdUnitId = 'ca-app-pub-6882687050623219/3856193297';
  static const String _productionLanguageNativeAdUnitId = 'ca-app-pub-6882687050623219/7841887375';
  static const String _productionHomeNativeAdUnitId = 'ca-app-pub-6882687050623219/1276479023';
  static const String _productionRecipeNativeAdUnitId = 'ca-app-pub-6882687050623219/5104043397';
  static const String _productionPlanNativeAdUnitId = 'ca-app-pub-6882687050623219/6150349996';
  static const String _productionShopNativeAdUnitId = 'ca-app-pub-6882687050623219/3856193297';
  static const String _productionChatNativeAdUnitId = 'ca-app-pub-6882687050623219/2686775378';
  static const String _productionRecipeDetailNativeAdUnitId = 'ca-app-pub-6882687050623219/2543111627';
  static const String _productionCameraNativeAdUnitId = 'ca-app-pub-6882687050623219/1812677406';
  static const String _productionBottomInterAdUnitId = 'ca-app-pub-6882687050623219/8916948280';
  static const String _productionCardInterAdUnitId = 'ca-app-pub-6882687050623219/5160895477';
  static const String _productionGeneratePlanInterAdUnitId = 'ca-app-pub-6882687050623219/1276479023';
  static const String _productionCookingAiInterAdUnitId = 'ca-app-pub-6882687050623219/2211104985';

  // Get ad unit IDs (use test IDs in debug/test/profile mode, production IDs in release bundle)
  static String _getAdUnitId(String productionId, {String? testAdType}) {
    // Use test IDs in debug/test/profile mode, production IDs in release bundle
    // kReleaseMode is true only in release builds (flutter build --release)
    // In debug/profile/test builds, always use test IDs
    if (!kReleaseMode) {
      // Use appropriate test ID based on ad type
      if (testAdType == 'native' || testAdType == 'Native') {
        return _testNativeAdUnitId;
      } else if (testAdType == 'interstitial' || testAdType == 'Inter') {
        return _testInterstitialAdUnitId;
      } else if (testAdType == 'appOpen' || testAdType == 'AppOpen') {
        return _testAppOpenAdUnitId;
      } else {
        // Fallback: infer from productionId if testAdType not provided
        if (productionId.contains('Native')) {
          return _testNativeAdUnitId;
        } else if (productionId.contains('Inter')) {
          return _testInterstitialAdUnitId;
        } else {
          return _testAppOpenAdUnitId;
        }
      }
    }
    // Use production IDs in release bundle only
    return productionId;
  }

  static String get appOpenAdUnitId => _getAdUnitId(_productionAppOpenAdUnitId, testAdType: 'appOpen');
  static String get splashInterAdUnitId => _getAdUnitId(_productionSplashInterAdUnitId, testAdType: 'interstitial');
  static String get languageNativeAdUnitId => _getAdUnitId(_productionLanguageNativeAdUnitId, testAdType: 'native');
  static String get homeNativeAdUnitId => _getAdUnitId(_productionHomeNativeAdUnitId, testAdType: 'native');
  static String get recipeNativeAdUnitId => _getAdUnitId(_productionRecipeNativeAdUnitId, testAdType: 'native');
  static String get planNativeAdUnitId => _getAdUnitId(_productionPlanNativeAdUnitId, testAdType: 'native');
  static String get shopNativeAdUnitId => _getAdUnitId(_productionShopNativeAdUnitId, testAdType: 'native');
  static String get chatNativeAdUnitId => _getAdUnitId(_productionChatNativeAdUnitId, testAdType: 'native');
  static String get recipeDetailNativeAdUnitId => _getAdUnitId(_productionRecipeDetailNativeAdUnitId, testAdType: 'native');
  static String get cameraNativeAdUnitId => _getAdUnitId(_productionCameraNativeAdUnitId, testAdType: 'native');
  static String get bottomInterAdUnitId => _getAdUnitId(_productionBottomInterAdUnitId, testAdType: 'interstitial');
  static String get cardInterAdUnitId => _getAdUnitId(_productionCardInterAdUnitId, testAdType: 'interstitial');
  static String get generatePlanInterAdUnitId => _getAdUnitId(_productionGeneratePlanInterAdUnitId, testAdType: 'interstitial');
  static String get cookingAiInterAdUnitId => _getAdUnitId(_productionCookingAiInterAdUnitId, testAdType: 'interstitial');

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;
  }

  // Check internet connectivity
  static Future<bool> _checkInternetConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Native Ad Loader - Per Screen
  static final Map<String, NativeAd?> _nativeAds = {};
  static final Map<String, bool> _isLoadingNative = {};

  static Future<NativeAd?> loadNativeAdForScreen({
    required String screenKey,
    required String adUnitId,
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    // Premium users never see ads (local-only entitlement).
    if (await StorageService.getIsPremium()) {
      return null;
    }

    // Check remote config first
    if (!await _shouldShowAdForScreen(screenKey)) {
      return null;
    }

    // Check internet connectivity
    if (!await _checkInternetConnectivity()) {
      return null;
    }

    if (!_isInitialized) {
      await initialize();
    }

    // If already loading or loaded, return existing
    if (_isLoadingNative[screenKey] == true && _nativeAds[screenKey] != null) {
      return _nativeAds[screenKey];
    }

    // Dispose existing ad for this screen
    _nativeAds[screenKey]?.dispose();

    _isLoadingNative[screenKey] = true;

    // Determine factory ID based on screen key
    // Use medium layout for: plan, recipeDetail, language
    // Use small layout for: home, recipe, shop, chat, camera
    final factoryId = (screenKey == 'plan' || 
                       screenKey == 'recipeDetail' || 
                       screenKey == 'language')
        ? 'mediumAd'
        : 'smallAd';

    final ad = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      factoryId: factoryId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _isLoadingNative[screenKey] = false;
          final nativeAd = ad as NativeAd;
          _nativeAds[screenKey] = nativeAd;
          onAdLoaded?.call(nativeAd);
        },
        onAdFailedToLoad: (ad, error) {
          _isLoadingNative[screenKey] = false;
          ad.dispose();
          _nativeAds[screenKey] = null;
          onAdFailedToLoad?.call(error);
        },
      ),
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(
          startMuted: true,
          clickToExpandRequested: false,
        ),
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        mediaAspectRatio: MediaAspectRatio.any,
      ),
    );

    ad.load();
    return ad;
  }

  // Helper method to check if ad should be shown based on remote config
  static Future<bool> _shouldShowAdForScreen(String screenKey) async {
    try {
      // Premium users never see ads (local-only entitlement).
      if (await StorageService.getIsPremium()) {
        return false;
      }

      await RemoteConfigService.initialize();
      
      switch (screenKey) {
        case 'language':
          return RemoteConfigService.languageNative;
        case 'home':
          return RemoteConfigService.homeNative;
        case 'recipe':
          return RemoteConfigService.recipeNative;
        case 'plan':
          return RemoteConfigService.planNative;
        case 'shop':
          return RemoteConfigService.shopNative;
        case 'chat':
          return RemoteConfigService.chatNative;
        case 'recipeDetail':
          return RemoteConfigService.recipeDetailNative;
        case 'camera':
          return RemoteConfigService.cameraNative;
        default:
          return RemoteConfigService.showAds;
      }
    } catch (e) {
      return RemoteConfigService.showAds; // Fallback to default
    }
  }

  // Convenience methods for each screen
  static Future<NativeAd?> loadLanguageNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'language',
      adUnitId: languageNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadHomeNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'home',
      adUnitId: homeNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadRecipeNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'recipe',
      adUnitId: recipeNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadPlanNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'plan',
      adUnitId: planNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadShopNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'shop',
      adUnitId: shopNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadChatNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'chat',
      adUnitId: chatNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadRecipeDetailNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'recipeDetail',
      adUnitId: recipeDetailNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<NativeAd?> loadCameraNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'camera',
      adUnitId: cameraNativeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  // Dispose native ad for a specific screen
  static void disposeNativeAdForScreen(String screenKey) {
    _nativeAds[screenKey]?.dispose();
    _nativeAds[screenKey] = null;
    _isLoadingNative[screenKey] = false;
  }

  // Interstitial Ad Loader - Per Type
  static final Map<String, InterstitialAd?> _interstitialAds = {};
  static final Map<String, bool> _isLoadingInterstitial = {};
  static final Map<String, bool> _isShowingInterstitial = {};
  
  // Track when interstitial ad was dismissed to prevent app open ad from showing immediately
  static DateTime? _lastInterstitialDismissedTime;
  
  // Track when app open ad was dismissed to prevent interstitial ads from showing immediately
  static DateTime? _lastAppOpenAdDismissedTime;
  
  // Cooldown period to prevent ads from chaining
  static const Duration _cooldownAfterAppOpenAd = Duration(seconds: 2);

  static Future<void> loadInterstitialAdForType({
    required String adType,
    required String adUnitId,
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    // Premium users never see ads (local-only entitlement).
    if (await StorageService.getIsPremium()) {
      return;
    }

    // Check internet connectivity
    if (!await _checkInternetConnectivity()) {
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    if (_isLoadingInterstitial[adType] == true) return;

    _isLoadingInterstitial[adType] = true;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAds[adType]?.dispose();
          _interstitialAds[adType] = ad;
          _isLoadingInterstitial[adType] = false;
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (error) {
          _interstitialAds[adType] = null;
          _isLoadingInterstitial[adType] = false;
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }

  static Future<void> showInterstitialAdForType({
    required String adType,
    BuildContext? context,
    Function()? onAdDismissed,
    Function(Ad)? onAdShowed,
    Function(Ad?)? onAdFailedToShow,
    Future<void> Function()? loadAdFunction,
  }) async {
    // Premium users never see ads (local-only entitlement).
    if (await StorageService.getIsPremium()) {
      onAdFailedToShow?.call(null);
      return;
    }

    // Check cooldown period after app open ad dismissal
    // This prevents interstitial ads from showing immediately after an app open ad is closed
    if (_lastAppOpenAdDismissedTime != null) {
      final timeSinceAppOpenAd = DateTime.now().difference(_lastAppOpenAdDismissedTime!);
      if (timeSinceAppOpenAd < _cooldownAfterAppOpenAd) {
        if (kDebugMode) {
          print(
            '⚠️ [AdService] Cooldown active after app open ad dismissal: ${timeSinceAppOpenAd.inSeconds}s / ${_cooldownAfterAppOpenAd.inSeconds}s, skipping interstitial ad',
          );
        }
        onAdFailedToShow?.call(null);
        return;
      }
    }
    // Track if loader was shown and dismissed
    bool loaderShown = false;
    bool loaderDismissed = false;
    NavigatorState? rootNavigator;
    
    // Helper function to safely dismiss loader
    void dismissLoader() {
      if (loaderDismissed || !loaderShown) return;

      // Prefer navigator captured at show-time (survives caller context unmount).
      final NavigatorState? navigator =
          rootNavigator ?? AppRouter.getNavigatorKey()?.currentState;

      // Fallback if no navigator captured and we still have a mounted context.
      final NavigatorState? fallbackNavigator =
          (navigator == null && context != null && context.mounted)
              ? Navigator.of(context, rootNavigator: true)
              : null;

      final NavigatorState? navToUse = navigator ?? fallbackNavigator;
      if (navToUse == null || !navToUse.mounted) return;

      if (!navToUse.canPop()) return;

      try {
        navToUse.pop();
        loaderDismissed = true;
        if (kDebugMode) {
          print('✅ [AdService] Loader dismissed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [AdService] Error dismissing loader: $e');
        }
      }
    }

    // Show loader dialog first if context is provided
    try {
      if (context != null && context.mounted) {
        // Capture the root navigator now (safe even if caller context unmounts later).
        rootNavigator = Navigator.of(context, rootNavigator: true);

        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          useRootNavigator: true, // Use root navigator to show on top
          builder: (dialogContext) => const _AdLoadingDialog(),
        );
        loaderShown = true;
        if (kDebugMode) {
          print('📥 [AdService] Loader shown for ad type: $adType');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AdService] Error showing loader: $e');
      }
      loaderShown = false;
    }

    // Load the ad if loadAdFunction is provided and ad is not already loaded
    InterstitialAd? ad = _interstitialAds[adType];
    Timer? pollTimer;
    
    try {
      if (ad == null && loadAdFunction != null) {
        final completer = Completer<void>();
        int pollCount = 0;
        const int maxPolls = 50; // 50 * 100ms = 5 seconds max
        
        // Poll for ad to be loaded or failed (check every 100ms)
        pollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          pollCount++;
          final loadedAd = _interstitialAds[adType];
          final isLoading = _isLoadingInterstitial[adType] == true;
          
          // Check if ad loaded successfully
          if (loadedAd != null) {
            timer.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
          // Check if loading failed: not loading anymore, no ad, and we've waited at least 1 second (10 polls)
          // This gives the ad time to start loading before we check for failure
          else if (!isLoading && loadedAd == null && pollCount >= 10) {
            timer.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
            if (kDebugMode) {
              print('⚠️ [AdService] Ad loading failed for type: $adType (loading stopped but no ad available)');
            }
          }
          // Timeout after max polls
          else if (pollCount >= maxPolls) {
            timer.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
            if (kDebugMode) {
              print('⚠️ [AdService] Ad loading timed out for type: $adType');
            }
          }
        });
        
        // Start loading the ad
        try {
          await loadAdFunction();
        } catch (e) {
          if (kDebugMode) {
            print('❌ [AdService] Error loading ad: $e');
          }
          pollTimer.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
        
        // Wait for ad to load, fail, or timeout
        try {
          await completer.future;
        } catch (e) {
          if (kDebugMode) {
            print('❌ [AdService] Error waiting for ad: $e');
          }
        }
        
        // Get the ad after loading attempt
        ad = _interstitialAds[adType];
      }
    } finally {
      // Always cancel the timer if it was created
      pollTimer?.cancel();
    }

    // Check if ad is already being shown to prevent duplicate shows
    if (_isShowingInterstitial[adType] == true) {
      if (kDebugMode) {
        print('⚠️ [AdService] Interstitial ad for type "$adType" is already being shown, skipping duplicate');
      }
      dismissLoader();
      onAdFailedToShow?.call(null);
      return;
    }

    // Show the ad if available
    if (ad != null && context != null && context.mounted) {
      // Mark as showing to prevent duplicate shows
      _isShowingInterstitial[adType] = true;
      
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          // Dismiss loading overlay as soon as ad appears
          dismissLoader();
          onAdShowed?.call(ad);
          if (kDebugMode) {
            print('✅ [AdService] Ad showed for type: $adType');
          }
        },
        onAdDismissedFullScreenContent: (ad) {
          if (kDebugMode) {
            print('✅ [AdService] Ad dismissed for type: $adType');
          }
          // Safety: if onAdShowed didn't fire (rare), the loader dialog can
          // re-appear after the ad is closed. Ensure it's dismissed here too.
          dismissLoader();
          // Track dismissal time to prevent app open ad from showing immediately
          _lastInterstitialDismissedTime = DateTime.now();
          // Reset showing flag
          _isShowingInterstitial[adType] = false;
          ad.dispose();
          _interstitialAds[adType] = null;
          onAdDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          if (kDebugMode) {
            print('❌ [AdService] Ad failed to show for type: $adType, error: $error');
          }
          // Reset showing flag
          _isShowingInterstitial[adType] = false;
          ad.dispose();
          _interstitialAds[adType] = null;
          // Dismiss loader if ad failed to show
          dismissLoader();
          onAdFailedToShow?.call(ad);
        },
      );
      try {
        ad.show();
      } catch (e) {
        if (kDebugMode) {
          print('❌ [AdService] Exception calling ad.show() for type: $adType: $e');
        }
        _isShowingInterstitial[adType] = false;
        _interstitialAds[adType] = null;
        dismissLoader();
        onAdFailedToShow?.call(ad);
      }
    } else {
      // If ad failed to load/show, dismiss loading overlay here
      // (onAdShown won't be called if ad fails)
      dismissLoader();
      // Ad not available - call failed callback
      if (kDebugMode) {
        print('⚠️ [AdService] Interstitial ad for type "$adType" not available, skipping');
      }
      // Reset showing flag if ad is not available
      _isShowingInterstitial[adType] = false;
      onAdFailedToShow?.call(null);
    }
  }

  // Convenience methods for interstitial ads
  static Future<void> loadSplashInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    // Check remote config
    if (!RemoteConfigService.splashInter) {
      return;
    }
    
    return loadInterstitialAdForType(
      adType: 'splash',
      adUnitId: splashInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadBottomInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'bottom',
      adUnitId: bottomInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadCardInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'card',
      adUnitId: cardInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadGeneratePlanInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'generatePlan',
      adUnitId: generatePlanInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadCookingAiInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'cookingAi',
      adUnitId: cookingAiInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  // App Open Ad
  static AppOpenAd? _appOpenAd;
  static bool _isLoadingAppOpen = false;
  static bool _isShowingAppOpen = false;

  static Future<void> loadAppOpenAd({
    Function(AppOpenAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    // Premium users never see ads (local-only entitlement).
    if (await StorageService.getIsPremium()) {
      return;
    }

    // Check remote config
    if (!RemoteConfigService.appOpen) {
      return;
    }

    // Check internet connectivity
    if (!await _checkInternetConnectivity()) {
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    if (_isLoadingAppOpen) return;

    _isLoadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _isLoadingAppOpen = false;
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _isLoadingAppOpen = false;
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }

  static void showAppOpenAd({
    Function()? onAdDismissed,
    Function(AppOpenAd)? onAdShowed,
    Function(AppOpenAd)? onAdFailedToShow,
  }) {
    if (_appOpenAd != null && !_isShowingAppOpen) {
      _isShowingAppOpen = true;
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          onAdShowed?.call(ad);
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _appOpenAd = null;
          _isShowingAppOpen = false;
          onAdDismissed?.call();
          // Preload next ad
          loadAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _appOpenAd = null;
          _isShowingAppOpen = false;
          onAdFailedToShow?.call(ad);
        },
      );
      _appOpenAd!.show();
    }
  }

  static bool get showAds => RemoteConfigService.showAds;
  
  /// Get the time when last interstitial ad was dismissed
  /// Used by app open ad manager to prevent showing app open ad immediately after interstitial
  static DateTime? get lastInterstitialDismissedTime => _lastInterstitialDismissedTime;

  /// Check if any interstitial ad is currently showing
  /// Used by app open ad manager to prevent showing app open ad while interstitial is active
  static bool get isAnyInterstitialShowing {
    return _isShowingInterstitial.values.any((isShowing) => isShowing == true);
  }

  /// Notify that an app open ad was dismissed
  /// Used to prevent interstitial ads from showing immediately after app open ad
  static void notifyAppOpenAdDismissed() {
    _lastAppOpenAdDismissedTime = DateTime.now();
    if (kDebugMode) {
      print('📋 [AdService] App open ad dismissed, starting cooldown for interstitial ads');
    }
  }

  static void dispose() {
    // Dispose all native ads
    for (var ad in _nativeAds.values) {
      ad?.dispose();
    }
    _nativeAds.clear();
    _isLoadingNative.clear();

    // Dispose all interstitial ads
    for (var ad in _interstitialAds.values) {
      ad?.dispose();
    }
    _interstitialAds.clear();
    _isLoadingInterstitial.clear();
    _isShowingInterstitial.clear();

    // Dispose app open ad
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}

/// Loading dialog shown while interstitial ad loads
/// Matching web app AdLoadingScreen.tsx design exactly
class _AdLoadingDialog extends StatefulWidget {
  const _AdLoadingDialog();

  @override
  State<_AdLoadingDialog> createState() => _AdLoadingDialogState();
}

class _AdLoadingDialogState extends State<_AdLoadingDialog> {
  String _dots = '';

  @override
  void initState() {
    super.initState();
    // Animate loading dots (matching web app)
    _animateDots();
  }

  void _animateDots() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _dots = _dots.length >= 3 ? '' : _dots + '.';
        });
        return mounted;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors for consistent background
    final theme = Theme.of(context);
    // Use solid background color matching the theme (no transparency)
    final backgroundColor = theme.colorScheme.background;

    return PopScope(
      canPop: false, // Prevent dismissing while loading
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background container covering entire screen including status bar
              Container(color: backgroundColor),
              // Content centered on screen
              Center(
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
                        final languageProvider = Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        );
                        final isRTL = languageProvider.isRTL;
                        final localizations = AppLocalizations.of(context);
                        final loadingText = (localizations?.adLoading ?? 'Loading ad').replaceAll('...', '').trim();
                        final textWithDots = isRTL
                            ? '$_dots$loadingText'
                            : '$loadingText$_dots';
                        return Text(
                          textWithDots,
                          textDirection: isRTL
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        );
                      },
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
