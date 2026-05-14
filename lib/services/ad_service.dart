import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../config/ad_config.dart';
import '../core/router/app_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import 'gdpr_consent_service.dart';
import 'remote_config_service.dart';
import 'storage_service.dart';

class AdService {
  // Test Ad Unit IDs (for development)
  static const String _testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  // Official Google test App Open Ad Unit ID for Android
  // Source: https://developers.google.com/admob/android/test-ads
  static const String _testAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testBannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerAdUnitIdIos =
      'ca-app-pub-3940256099942544/2934735716';

  // Production Ad Unit IDs (from the plan)
  static const String _productionAppOpenAdUnitId =
      'ca-app-pub-6882687050623219/2543111627';
  static const String _productionSplashInterAdUnitId =
      'ca-app-pub-6882687050623219/3856193297';
  // Language native ad (Android / iOS)
  static const String _productionLanguageNativeAndroid =
      'ca-app-pub-6882687050623219/7841887375';
  /// Native on language screen — iOS (RC: `language_native_ios`).
  static const String _productionLanguageNativeIos =
      'ca-app-pub-6882687050623219/3376170317';
  static const String _productionHomeNativeAdUnitId =
      'ca-app-pub-6882687050623219/1276479023';
  static const String _productionRecipeNativeAdUnitId =
      'ca-app-pub-6882687050623219/5104043397';
  static const String _productionPlanNativeAdUnitId =
      'ca-app-pub-6882687050623219/6150349996';
  static const String _productionShopNativeAdUnitId =
      'ca-app-pub-6882687050623219/3856193297';
  static const String _productionChatNativeAdUnitId =
      'ca-app-pub-6882687050623219/2686775378';
  static const String _productionRecipeDetailNativeAdUnitId =
      'ca-app-pub-6882687050623219/2543111627';
  static const String _productionCameraNativeAdUnitId =
      'ca-app-pub-6882687050623219/1812677406';
  // Onboarding native ad (Android / iOS)
  static const String _productionOnboardingNativeAndroid =
      'ca-app-pub-6882687050623219/8025861761';
  /// Onboarding native — iOS (RC: `onboarding_native_ios`).
  static const String _productionOnboardingNativeIos =
      'ca-app-pub-6882687050623219/6329636711';
  static const String _productionBottomInterAdUnitId =
      'ca-app-pub-6882687050623219/8916948280';

  /// Bottom tab switch interstitial — Android (RC: `bottom_tab_inter`).
  static const String _productionBottomTabChangeInterAndroid =
      'ca-app-pub-6882687050623219/2365011322';
  /// Bottom tab switch interstitial — iOS (RC: `bottom_tab_inter_ios`).
  static const String _productionBottomTabChangeInterIos =
      'ca-app-pub-6882687050623219/3022675771';
  static const String _productionCardInterAdUnitId =
      'ca-app-pub-6882687050623219/5160895477';
  static const String _productionGeneratePlanInterAdUnitId =
      'ca-app-pub-6882687050623219/1276479023';
  static const String _productionCookingAiInterAdUnitId =
      'ca-app-pub-6882687050623219/2211104985';
  // Exit interstitial (when user confirms exit)
  static const String _productionExitInterAndroid =
      'ca-app-pub-6882687050623219/8775507081';
  /// Exit interstitial — iOS (RC: `exit_inter_ios`).
  static const String _productionExitInterIos =
      'ca-app-pub-6882687050623219/9924937221';
  // Chat reset interstitial (when user starts new chat)
  static const String _productionChatResetInterAndroid =
      'ca-app-pub-6882687050623219/7462425415';
  /// Chat reset / new chat interstitial — iOS (RC: `chatreset_inter_ios`).
  static const String _productionChatResetInterIos =
      'ca-app-pub-6882687050623219/2063088649';
  // View Plan / Continue Plan interstitial (returning user on home)
  static const String _productionViewPlanContinueInterAndroid =
      'ca-app-pub-6882687050623219/2773535082';
  /// View plan / continue plan interstitial — iOS (RC: `viewplancontinue_inter_ios`).
  static const String _productionViewPlanContinueInterIos =
      'ca-app-pub-6882687050623219/9422703914';

  /// Recipe detail back (system / app bar) interstitial — Android (`recipe_backpress_inter`).
  static const String _productionRecipeDetailBackInterAndroid =
      'ca-app-pub-6882687050623219/3678092993';
  /// Recipe detail back interstitial — iOS (RC: `recipe_backpress_inter_ios`).
  static const String _productionRecipeDetailBackInterIos =
      'ca-app-pub-6882687050623219/1877115068';

  /// Grocery smart suggestion **Add** tap interstitial — Android (`add_sug_inter`).
  static const String _productionGroceryAddSugInterAndroid =
      'ca-app-pub-6882687050623219/2243698188';
  /// Grocery smart suggestion **Add** tap — iOS (RC: `add_sug_inter_ios`).
  static const String _productionGroceryAddSugInterIos =
      'ca-app-pub-6882687050623219/9564033396';
  // Resume app open ad when app returns from background (Android / iOS)
  static const String _productionResumeAppOpenAndroid =
      'ca-app-pub-6882687050623219/7730206739';
  /// Resume app open — iOS (RC: `resume_appopen_ios`).
  static const String _productionResumeAppOpenIos =
      'ca-app-pub-6882687050623219/1854729725';
  // Splash app open ad on first install (Android / iOS)
  static const String _productionSplashAppOpen1stTimeAndroid =
      'ca-app-pub-6882687050623219/1308080602';
  static const String _productionSplashAppOpen1stTimeIos =
      'ca-app-pub-6882687050623219/1540344462';
  // Splash app open ad for returning user (2nd+ open) (Android / iOS)
  static const String _productionSplashAppOpen2ndTimeAndroid =
      'ca-app-pub-6882687050623219/7371255644';
  static const String _productionSplashAppOpen2ndTimeIos =
      'ca-app-pub-6882687050623219/9227262791';
  // Splash interstitial ad (Android first install / returning)
  static const String _productionSplashInter1stTimeAndroid =
      'ca-app-pub-6882687050623219/1089595004';
  /// iOS first open splash interstitial (RC: `splash_inter_1sttime_ios`).
  static const String _productionSplashInter1stTimeIos =
      'ca-app-pub-6882687050623219/6959868047';
  static const String _productionSplashInter2ndTimeAndroid =
      'ca-app-pub-6882687050623219/5051550699';
  /// iOS returning-user splash interstitial (RC: `splash_inter_2ndtime_ios`).
  static const String _productionSplashInter2ndTimeIos =
      'ca-app-pub-6882687050623219/5698757269';
  // Bottom banner on bottom nav screens (Android / iOS)
  static const String _productionBottomBannerAndroid =
      'ca-app-pub-6882687050623219/9130584518';
  /// Bottom tab strip banner — iOS (RC: `bottom_banner_ios`).
  static const String _productionBottomBannerIos =
      'ca-app-pub-6882687050623219/9541648057';

  /// Native fallback when bottom banner fails — Android (RC: `bottom_native`).
  static const String _productionBottomNativeAndroid =
      'ca-app-pub-6882687050623219/7110423193';
  /// Native fallback when bottom banner fails — iOS (RC: `bottom_native_ios`).
  static const String _productionBottomNativeIos =
      'ca-app-pub-6882687050623219/4468224626';

  // ========== FOR TESTING ONLY: Test ads in release APK ==========
  // Set to true: release APK shows Google test ads (for testing).
  // Set to false: release APK uses production ad units (real ads).
  static const bool _forceTestAds = false;
  // ================================================================

  // Get ad unit IDs. Production IDs are used in all build modes unless
  // _forceTestAds is explicitly enabled.
  static String _getAdUnitId(String productionId, {String? testAdType}) {
    final testBannerId = Platform.isIOS
        ? _testBannerAdUnitIdIos
        : _testBannerAdUnitIdAndroid;
    if (_forceTestAds) {
      if (testAdType == 'native' || testAdType == 'Native')
        return _testNativeAdUnitId;
      if (testAdType == 'interstitial' || testAdType == 'Inter')
        return _testInterstitialAdUnitId;
      if (testAdType == 'appOpen' || testAdType == 'AppOpen')
        return _testAppOpenAdUnitId;
      if (testAdType == 'banner' || testAdType == 'Banner') return testBannerId;
      if (productionId.contains('Native')) return _testNativeAdUnitId;
      if (productionId.contains('Inter')) return _testInterstitialAdUnitId;
      return _testAppOpenAdUnitId;
    }
    return productionId;
  }

  static String get appOpenAdUnitId =>
      _getAdUnitId(_productionAppOpenAdUnitId, testAdType: 'appOpen');

  /// Resume app open ad - shown when app returns from background
  static String get resumeAppOpenAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionResumeAppOpenIos, testAdType: 'appOpen')
      : _getAdUnitId(_productionResumeAppOpenAndroid, testAdType: 'appOpen');
  static String get splashAppOpen1stTimeAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionSplashAppOpen1stTimeIos, testAdType: 'appOpen')
      : _getAdUnitId(
          _productionSplashAppOpen1stTimeAndroid,
          testAdType: 'appOpen',
        );
  static String get splashAppOpen2ndTimeAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionSplashAppOpen2ndTimeIos, testAdType: 'appOpen')
      : _getAdUnitId(
          _productionSplashAppOpen2ndTimeAndroid,
          testAdType: 'appOpen',
        );
  static String get splashInterAdUnitId =>
      _getAdUnitId(_productionSplashInterAdUnitId, testAdType: 'interstitial');
  static String get splashInter1stTimeAdUnitId => Platform.isIOS
      ? _getAdUnitId(
          _productionSplashInter1stTimeIos,
          testAdType: 'interstitial',
        )
      : _getAdUnitId(
          _productionSplashInter1stTimeAndroid,
          testAdType: 'interstitial',
        );
  static String get splashInter2ndTimeAdUnitId => Platform.isIOS
      ? _getAdUnitId(
          _productionSplashInter2ndTimeIos,
          testAdType: 'interstitial',
        )
      : _getAdUnitId(
          _productionSplashInter2ndTimeAndroid,
          testAdType: 'interstitial',
        );
  static String get languageNativeAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionLanguageNativeIos, testAdType: 'native')
      : _getAdUnitId(_productionLanguageNativeAndroid, testAdType: 'native');
  static String get homeNativeAdUnitId =>
      _getAdUnitId(_productionHomeNativeAdUnitId, testAdType: 'native');
  static String get recipeNativeAdUnitId =>
      _getAdUnitId(_productionRecipeNativeAdUnitId, testAdType: 'native');
  static String get planNativeAdUnitId =>
      _getAdUnitId(_productionPlanNativeAdUnitId, testAdType: 'native');
  static String get shopNativeAdUnitId =>
      _getAdUnitId(_productionShopNativeAdUnitId, testAdType: 'native');
  static String get chatNativeAdUnitId =>
      _getAdUnitId(_productionChatNativeAdUnitId, testAdType: 'native');
  static String get recipeDetailNativeAdUnitId =>
      _getAdUnitId(_productionRecipeDetailNativeAdUnitId, testAdType: 'native');
  static String get cameraNativeAdUnitId =>
      _getAdUnitId(_productionCameraNativeAdUnitId, testAdType: 'native');
  static String get onboardingNativeAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionOnboardingNativeIos, testAdType: 'native')
      : _getAdUnitId(_productionOnboardingNativeAndroid, testAdType: 'native');
  static String get bottomInterAdUnitId =>
      _getAdUnitId(_productionBottomInterAdUnitId, testAdType: 'interstitial');
  static String get bottomTabChangeInterAdUnitId => Platform.isIOS
      ? _getAdUnitId(
          _productionBottomTabChangeInterIos,
          testAdType: 'interstitial',
        )
      : _getAdUnitId(
          _productionBottomTabChangeInterAndroid,
          testAdType: 'interstitial',
        );
  static String get cardInterAdUnitId =>
      _getAdUnitId(_productionCardInterAdUnitId, testAdType: 'interstitial');
  static String get generatePlanInterAdUnitId => _getAdUnitId(
    _productionGeneratePlanInterAdUnitId,
    testAdType: 'interstitial',
  );
  static String get cookingAiInterAdUnitId => _getAdUnitId(
    _productionCookingAiInterAdUnitId,
    testAdType: 'interstitial',
  );
  static String get exitInterAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionExitInterIos, testAdType: 'interstitial')
      : _getAdUnitId(_productionExitInterAndroid, testAdType: 'interstitial');
  static String get chatResetInterAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionChatResetInterIos, testAdType: 'interstitial')
      : _getAdUnitId(
          _productionChatResetInterAndroid,
          testAdType: 'interstitial',
        );
  static String get viewPlanContinueInterAdUnitId => Platform.isIOS
      ? _getAdUnitId(
          _productionViewPlanContinueInterIos,
          testAdType: 'interstitial',
        )
      : _getAdUnitId(
          _productionViewPlanContinueInterAndroid,
          testAdType: 'interstitial',
        );
  static String get recipeDetailBackInterAdUnitId => Platform.isIOS
      ? _getAdUnitId(
          _productionRecipeDetailBackInterIos,
          testAdType: 'interstitial',
        )
      : _getAdUnitId(
          _productionRecipeDetailBackInterAndroid,
          testAdType: 'interstitial',
        );
  static String get groceryAddSugInterAdUnitId => Platform.isIOS
      ? _getAdUnitId(
          _productionGroceryAddSugInterIos,
          testAdType: 'interstitial',
        )
      : _getAdUnitId(
          _productionGroceryAddSugInterAndroid,
          testAdType: 'interstitial',
        );
  static String get bottomBannerAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionBottomBannerIos, testAdType: 'banner')
      : _getAdUnitId(_productionBottomBannerAndroid, testAdType: 'banner');

  static String get bottomNativeAdUnitId => Platform.isIOS
      ? _getAdUnitId(_productionBottomNativeIos, testAdType: 'native')
      : _getAdUnitId(_productionBottomNativeAndroid, testAdType: 'native');

  static bool _isInitialized = false;
  // Block ads on mobile until UMP consent completes (Android + iOS).
  static bool _gdprAllowsAds =
      (Platform.isAndroid || Platform.isIOS) ? false : true;

  /// True when GDPR/UMP consent allows requesting ads. Non-mobile defaults to true.
  static bool get gdprAllowsAds => _gdprAllowsAds;

  /// When false: no ads on iOS. When true: show ads on iOS. Android always shows ads.
  static bool get _shouldShowAdsOnPlatform {
    if (Platform.isIOS) return AdConfig.showAdsOnIos;
    return true; // Android and other platforms always show ads
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Don't initialize Google Mobile Ads on iOS if ads are disabled
    if (Platform.isIOS && !AdConfig.showAdsOnIos) {
      if (kDebugMode) {
        print(
          '🚫 [AdService] Skipping MobileAds initialization on iOS (ads disabled)',
        );
      }
      _isInitialized = true;
      return;
    }

    // GDPR/UMP consent gate (Android + iOS). If consent blocks ad requests,
    // skip initializing ads for this run.
    _gdprAllowsAds = await GdprConsentService.gatherConsentIfRequired();
    if (!_gdprAllowsAds) {
      _isInitialized = true;
      return;
    }

    await MobileAds.instance.initialize();
    _isInitialized = true;
  }

  // Check internet connectivity (connectivity_plus returns List<ConnectivityResult>)
  static Future<bool> _checkInternetConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
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
    if (!_shouldShowAdsOnPlatform) return null;
    if (!_gdprAllowsAds) return null;

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
    if (!_gdprAllowsAds) return null;

    // If already loading or loaded, return existing
    if (_isLoadingNative[screenKey] == true && _nativeAds[screenKey] != null) {
      return _nativeAds[screenKey];
    }

    // Dispose existing ad for this screen
    _nativeAds[screenKey]?.dispose();

    _isLoadingNative[screenKey] = true;

    // Determine factory ID based on screen key
    // Use medium layout for: plan, recipeDetail, language, onboarding
    // Use small layout for: home, recipe, shop, chat, camera
    final factoryId =
        (screenKey == 'plan' ||
            screenKey == 'recipeDetail' ||
            screenKey == 'language' ||
            screenKey == 'onboarding')
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
          return Platform.isIOS
              ? RemoteConfigService.languageNativeIos
              : RemoteConfigService.languageNative;
        case 'home':
          return Platform.isIOS
              ? RemoteConfigService.homeNativeIos
              : RemoteConfigService.homeNative;
        case 'recipe':
          return Platform.isIOS
              ? RemoteConfigService.recipeNativeIos
              : RemoteConfigService.recipeNative;
        case 'plan':
          return Platform.isIOS
              ? RemoteConfigService.planNativeIos
              : RemoteConfigService.planNative;
        case 'shop':
          return Platform.isIOS
              ? RemoteConfigService.shopNativeIos
              : RemoteConfigService.shopNative;
        case 'chat':
          return Platform.isIOS
              ? RemoteConfigService.chatNativeIos
              : RemoteConfigService.chatNative;
        case 'recipeDetail':
          return Platform.isIOS
              ? RemoteConfigService.recipeDetailNativeIos
              : RemoteConfigService.recipeDetailNative;
        case 'camera':
          return Platform.isIOS
              ? RemoteConfigService.cameraNativeIos
              : RemoteConfigService.cameraNative;
        case 'onboarding':
          return Platform.isIOS
              ? RemoteConfigService.onboardingNativeIos
              : RemoteConfigService.onboardingNative;
        default:
          return Platform.isIOS
              ? RemoteConfigService.showAdsIos
              : RemoteConfigService.showAds;
      }
    } catch (e) {
      return Platform.isIOS
          ? RemoteConfigService.showAdsIos
          : RemoteConfigService.showAds; // Fallback to default
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

  static Future<NativeAd?> loadOnboardingNativeAd({
    Function(NativeAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadNativeAdForScreen(
      screenKey: 'onboarding',
      adUnitId: onboardingNativeAdUnitId,
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

  /// Tracks show attempt from entry - blocks overlapping calls (e.g. rapid bottom nav taps)
  static final Map<String, bool> _isShowInterstitialInProgress = {};

  /// Global lock: only one interstitial (any type) can load/show at a time.
  /// Prevents double ads when user navigates quickly on slow internet.
  static bool _isAnyInterstitialInProgress = false;

  // Track when interstitial ad was dismissed to prevent app open ad from showing immediately
  static DateTime? _lastInterstitialDismissedTime;

  // Track when app open ad was dismissed to prevent interstitial ads from showing immediately
  static DateTime? _lastAppOpenAdDismissedTime;

  // Cooldown period to prevent ads from chaining
  static const Duration _cooldownAfterAppOpenAd = Duration(seconds: 2);
  static const Duration _cooldownAfterInterstitialAd = Duration(seconds: 1);

  static Future<void> loadInterstitialAdForType({
    required String adType,
    required String adUnitId,
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
    int retryCount = 0,
  }) async {
    if (!_shouldShowAdsOnPlatform) return;
    if (!_gdprAllowsAds) return;

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
    if (!_gdprAllowsAds) return;

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

          // Retry once for common transient failures.
          // (0 = internal error, 2 = no fill, 3 = internal/invalid request in some SDKs)
          final shouldRetry =
              retryCount == 0 &&
              (error.code == 0 || error.code == 2 || error.code == 3);
          if (shouldRetry) {
            if (kDebugMode) {
              print(
                '🔄 [AdService] Retrying interstitial load for "$adType" (retry=${retryCount + 1}) after error code ${error.code}',
              );
            }
            Future.delayed(const Duration(milliseconds: 800), () {
              // Fire-and-forget retry; show flow polls for _interstitialAds[adType].
              loadInterstitialAdForType(
                adType: adType,
                adUnitId: adUnitId,
                onAdLoaded: onAdLoaded,
                onAdFailedToLoad: onAdFailedToLoad,
                retryCount: 1,
              );
            });
            return;
          }

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
    bool showLoader = true,
  }) async {
    void logBottomTab(String msg) {
      if (adType == 'bottomTab') {
        debugPrint('📢 [BottomTabAd] $msg');
      }
    }

    if (!_shouldShowAdsOnPlatform) {
      logBottomTab('skip: ads disabled on this platform (AdConfig)');
      onAdFailedToShow?.call(null);
      return;
    }
    if (!_gdprAllowsAds) {
      logBottomTab('skip: GDPR consent blocked ad requests');
      onAdFailedToShow?.call(null);
      return;
    }
    // Block overlapping show attempts (e.g. rapid bottom nav taps)
    if (_isShowInterstitialInProgress[adType] == true) {
      logBottomTab('skip: show already in progress for this adType');
      if (kDebugMode) {
        print(
          '⚠️ [AdService] Interstitial show already in progress for "$adType", skipping duplicate',
        );
      }
      onAdFailedToShow?.call(null);
      return;
    }
    // Global lock: only one interstitial of any type at a time (prevents double ads on fast navigation)
    if (_isAnyInterstitialInProgress) {
      logBottomTab('skip: another interstitial is loading or showing');
      if (kDebugMode) {
        print(
          '⚠️ [AdService] Another interstitial already loading or showing, skipping "$adType"',
        );
      }
      onAdFailedToShow?.call(null);
      return;
    }
    _isShowInterstitialInProgress[adType] = true;
    _isAnyInterstitialInProgress = true;

    // Premium users never see ads (local-only entitlement).
    if (await StorageService.getIsPremium()) {
      logBottomTab('skip: user is premium');
      _isShowInterstitialInProgress[adType] = false;
      _isAnyInterstitialInProgress = false;
      onAdFailedToShow?.call(null);
      return;
    }

    // Make sure consent is gathered before any show attempt.
    if (!_isInitialized) {
      await initialize();
    }
    if (!_gdprAllowsAds) {
      logBottomTab('skip: GDPR consent blocked ad requests (post-initialize)');
      _isShowInterstitialInProgress[adType] = false;
      _isAnyInterstitialInProgress = false;
      onAdFailedToShow?.call(null);
      return;
    }

    // Check cooldown period after app open ad dismissal
    // This prevents interstitial ads from showing immediately after an app open ad is closed
    if (_lastAppOpenAdDismissedTime != null) {
      final timeSinceAppOpenAd = DateTime.now().difference(
        _lastAppOpenAdDismissedTime!,
      );
      if (timeSinceAppOpenAd < _cooldownAfterAppOpenAd) {
        logBottomTab(
          'skip: cooldown after app open ad (${timeSinceAppOpenAd.inMilliseconds}ms < ${_cooldownAfterAppOpenAd.inMilliseconds}ms)',
        );
        if (kDebugMode) {
          print(
            '⚠️ [AdService] Cooldown active after app open ad dismissal: ${timeSinceAppOpenAd.inSeconds}s / ${_cooldownAfterAppOpenAd.inSeconds}s, skipping interstitial ad',
          );
        }
        _isShowInterstitialInProgress[adType] = false;
        _isAnyInterstitialInProgress = false;
        onAdFailedToShow?.call(null);
        return;
      }
    }
    // Short cooldown after last interstitial to avoid rapid chaining on fast navigation
    if (_lastInterstitialDismissedTime != null) {
      final timeSince = DateTime.now().difference(
        _lastInterstitialDismissedTime!,
      );
      if (timeSince < _cooldownAfterInterstitialAd) {
        logBottomTab(
          'skip: cooldown after last interstitial (${timeSince.inMilliseconds}ms < ${_cooldownAfterInterstitialAd.inMilliseconds}ms)',
        );
        if (kDebugMode) {
          print(
            '⚠️ [AdService] Cooldown active after interstitial: ${timeSince.inMilliseconds}ms, skipping "$adType"',
          );
        }
        _isShowInterstitialInProgress[adType] = false;
        _isAnyInterstitialInProgress = false;
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

      // Fallback: caller context, then app root (tab-switch interstitial may unmount caller).
      final NavigatorState? fallbackNavigator =
          (navigator == null && context != null && context.mounted)
          ? Navigator.of(context, rootNavigator: true)
          : null;
      final NavigatorState? rootKeyNav =
          navigator == null && fallbackNavigator == null
          ? AppRouter.getNavigatorKey()?.currentState
          : null;

      final NavigatorState? navToUse =
          navigator ?? fallbackNavigator ?? rootKeyNav;
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

    // Loader: prefer caller context's root navigator; after go_router tab switches the
    // caller may unmount before load finishes — fall back to app root navigator.
    try {
      if (showLoader) {
        final NavigatorState? navForLoader =
            (context != null && context.mounted)
            ? Navigator.of(context, rootNavigator: true)
            : AppRouter.getNavigatorKey()?.currentState;
        rootNavigator = navForLoader;
        if (navForLoader != null && navForLoader.mounted) {
          showDialog(
            context: navForLoader.context,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.7),
            useRootNavigator: true,
            useSafeArea: false,
            builder: (dialogContext) => const _AdLoadingDialog(),
          );
          loaderShown = true;
          logBottomTab(
            'loader shown via ${context != null && context.mounted ? "caller context" : "AppRouter root"}',
          );
          if (kDebugMode) {
            print('📥 [AdService] Loader shown for ad type: $adType');
          }
        } else {
          logBottomTab(
            'loader skipped: no mounted navigator (callerMounted=${context?.mounted})',
          );
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
        // Give the auction/network more time on real devices.
        const int maxPolls = 100; // 100 * 100ms = 10 seconds max

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
              print(
                '⚠️ [AdService] Ad loading failed for type: $adType (loading stopped but no ad available)',
              );
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

    logBottomTab(
      'after load/wait: ad=${ad != null ? "loaded" : "null (no fill / error / timeout)"}',
    );

    // Check if ad is already being shown to prevent duplicate shows
    if (_isShowingInterstitial[adType] == true) {
      logBottomTab('skip: interstitial already showing for this adType');
      if (kDebugMode) {
        print(
          '⚠️ [AdService] Interstitial ad for type "$adType" is already being shown, skipping duplicate',
        );
      }
      _isShowInterstitialInProgress[adType] = false;
      _isAnyInterstitialInProgress = false;
      dismissLoader();
      onAdFailedToShow?.call(null);
      return;
    }

    // Interstitial.show() does not need the caller's BuildContext; caller may be unmounted
    // after go_router navigates while we were loading (e.g. bottom tab interstitial).
    if (ad != null) {
      logBottomTab(
        'showing interstitial (callerContextMounted=${context?.mounted ?? "null"})',
      );
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
          // Reset showing and in-progress flags
          _isShowingInterstitial[adType] = false;
          _isShowInterstitialInProgress[adType] = false;
          _isAnyInterstitialInProgress = false;
          ad.dispose();
          _interstitialAds[adType] = null;
          onAdDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          if (adType == 'bottomTab') {
            debugPrint(
              '📢 [BottomTabAd] onAdFailedToShowFullScreenContent: $error',
            );
          }
          if (kDebugMode) {
            print(
              '❌ [AdService] Ad failed to show for type: $adType, error: $error',
            );
          }
          // Reset showing and in-progress flags
          _isShowingInterstitial[adType] = false;
          _isShowInterstitialInProgress[adType] = false;
          _isAnyInterstitialInProgress = false;
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
          print(
            '❌ [AdService] Exception calling ad.show() for type: $adType: $e',
          );
        }
        _isShowingInterstitial[adType] = false;
        _isShowInterstitialInProgress[adType] = false;
        _isAnyInterstitialInProgress = false;
        _interstitialAds[adType] = null;
        dismissLoader();
        onAdFailedToShow?.call(ad);
      }
    } else {
      // If ad failed to load/show, dismiss loading overlay here
      // (onAdShown won't be called if ad fails)
      dismissLoader();
      // Ad not available - call failed callback
      if (adType == 'bottomTab') {
        debugPrint(
          '📢 [BottomTabAd] skip: ad not shown — adNull=${ad == null} '
          '(callerContextMounted=${context?.mounted ?? "null"})',
        );
      }
      if (kDebugMode) {
        print(
          '⚠️ [AdService] Interstitial ad for type "$adType" not available, skipping',
        );
      }
      // Reset showing and in-progress flags if ad is not available
      _isShowingInterstitial[adType] = false;
      _isShowInterstitialInProgress[adType] = false;
      _isAnyInterstitialInProgress = false;
      onAdFailedToShow?.call(null);
    }
  }

  // Convenience methods for interstitial ads
  static Future<void> loadSplashInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    final allowSplashInter = Platform.isIOS
        ? RemoteConfigService.splashInterIos
        : RemoteConfigService.splashInter;
    if (!allowSplashInter) {
      return;
    }

    return loadInterstitialAdForType(
      adType: 'splash',
      adUnitId: splashInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadSplashFirstTimeInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    return loadInterstitialAdForType(
      adType: 'splashFirstTime',
      adUnitId: splashInter1stTimeAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadSplashReturningInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    return loadInterstitialAdForType(
      adType: 'splashReturning',
      adUnitId: splashInter2ndTimeAdUnitId,
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

  static Future<void> loadBottomTabChangeInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'bottomTab',
      adUnitId: bottomTabChangeInterAdUnitId,
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

  static Future<void> loadExitInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'exit',
      adUnitId: exitInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadChatResetInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'chatReset',
      adUnitId: chatResetInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadViewPlanContinueInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'viewPlanContinue',
      adUnitId: viewPlanContinueInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadRecipeDetailBackInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'recipeDetailBack',
      adUnitId: recipeDetailBackInterAdUnitId,
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  static Future<void> loadGroceryAddSuggestionInterstitialAd({
    Function(InterstitialAd)? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    return loadInterstitialAdForType(
      adType: 'groceryAddSug',
      adUnitId: groceryAddSugInterAdUnitId,
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
    if (!_shouldShowAdsOnPlatform) return;
    if (!_gdprAllowsAds) return;

    // Premium users never see ads (local-only entitlement).
    if (await StorageService.getIsPremium()) {
      return;
    }

    final allowAppOpen = Platform.isIOS
        ? RemoteConfigService.appOpenIos
        : RemoteConfigService.appOpen;
    if (!allowAppOpen) {
      return;
    }

    // Check internet connectivity
    if (!await _checkInternetConnectivity()) {
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }
    if (!_gdprAllowsAds) return;

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

  /// Load and show splash app open ad on first install.
  /// Controlled by RC: splash_appopen_1sttime (Android) / splash_appopen_1sttime_ios (iOS).
  /// Calls [onComplete] when ad is dismissed, failed to load/show, or times out.
  static Future<void> loadAndShowSplashFirstTimeAppOpenAd({
    required BuildContext context,
    required VoidCallback onComplete,
  }) async {
    // Consent gate first; if user didn't consent, skip ads entirely.
    if (!_isInitialized) {
      await initialize();
    }
    if (!_gdprAllowsAds) {
      onComplete();
      return;
    }

    if (!await _checkInternetConnectivity()) {
      onComplete();
      return;
    }

    // Show full-screen loader while ad loads
    bool loaderShown = false;
    bool loaderDismissed = false;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    void dismissLoader() {
      if (loaderDismissed || !loaderShown) return;
      try {
        if (rootNavigator.mounted && rootNavigator.canPop()) {
          rootNavigator.pop();
          loaderDismissed = true;
          if (kDebugMode) {
            print('✅ [AdService] Splash first-time app open loader dismissed');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [AdService] Error dismissing loader: $e');
        }
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        useRootNavigator: true,
        useSafeArea: false,
        builder: (dialogContext) => const _AdLoadingDialog(),
      );
      loaderShown = true;
      if (kDebugMode) {
        print('📥 [AdService] Loader shown for splash first-time app open ad');
      }
    }

    // Give the ad auction enough time during app start/network variance.
    const loadTimeout = Duration(seconds: 10);
    final completer = Completer<void>();
    AppOpenAd? ad;
    bool didComplete = false;
    int retryCount = 0;

    void complete() {
      if (didComplete) return;
      didComplete = true;
      dismissLoader();
      ad?.dispose();
      if (!completer.isCompleted) completer.complete();
      onComplete();
    }

    void startLoad() {
      if (didComplete) return;
      if (kDebugMode) {
        print(
          '📥 [AdService] Splash first-time app open startLoad(retry=$retryCount) adUnitId=$splashAppOpen1stTimeAdUnitId',
        );
      }

      AppOpenAd.load(
        adUnitId: splashAppOpen1stTimeAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (loadedAd) {
            if (didComplete) {
              loadedAd.dispose();
              return;
            }
            ad = loadedAd;
            ad!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (_) {
                dismissLoader(); // Dismiss loader when ad appears
                if (kDebugMode) {
                  print('✅ [AdService] Splash first-time app open ad showed');
                }
              },
              onAdDismissedFullScreenContent: (_) {
                if (kDebugMode) {
                  print(
                    '✅ [AdService] Splash first-time app open ad dismissed',
                  );
                }
                ad?.dispose();
                ad = null;
                complete();
              },
              onAdFailedToShowFullScreenContent: (_, error) {
                if (kDebugMode) {
                  print(
                    '❌ [AdService] Splash first-time app open ad failed to show: $error',
                  );
                }
                ad?.dispose();
                ad = null;
                complete();
              },
            );
            if (context.mounted) {
              ad!.show();
            } else {
              ad?.dispose();
              complete();
            }
          },
          onAdFailedToLoad: (error) {
            if (kDebugMode) {
              print(
                '❌ [AdService] Splash first-time app open ad failed to load: ${error.code} ${error.message}',
              );
            }

            // Retry once for common transient failures (network / internal / SDK timing).
            // If it's truly a configuration problem, this won't help, but it improves resilience.
            final shouldRetry =
                retryCount < 1 &&
                (error.code == 0 || error.code == 2 || error.code == 3);
            if (shouldRetry) {
              retryCount++;
              if (kDebugMode) {
                print(
                  '🔄 [AdService] Retrying splash first-time app open ad load (retry=$retryCount)...',
                );
              }
              Future.delayed(const Duration(milliseconds: 800), () {
                if (!didComplete) startLoad();
              });
              return;
            }

            complete();
          },
        ),
      );
    }

    startLoad();

    // Timeout: proceed if ad doesn't load in time
    Future.delayed(loadTimeout, () {
      if (!didComplete) {
        if (kDebugMode) {
          print(
            '⚠️ [AdService] Splash first-time app open ad load timeout, proceeding',
          );
        }
        complete();
      }
    });

    await completer.future;
  }

  /// Load and show splash app open ad for returning user (2nd+ app open).
  /// Controlled by RC: splash_appopen_2ndtime (Android) / splash_appopen_2ndtime_ios (iOS).
  /// Calls [onComplete] when ad is dismissed, failed to load/show, or times out.
  static Future<void> loadAndShowSplashReturningUserAppOpenAd({
    required BuildContext context,
    required VoidCallback onComplete,
  }) async {
    // Consent gate first; if user didn't consent, skip ads entirely.
    if (!_isInitialized) {
      await initialize();
    }
    if (!_gdprAllowsAds) {
      onComplete();
      return;
    }

    if (!await _checkInternetConnectivity()) {
      onComplete();
      return;
    }

    bool loaderShown = false;
    bool loaderDismissed = false;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    void dismissLoader() {
      if (loaderDismissed || !loaderShown) return;
      try {
        if (rootNavigator.mounted && rootNavigator.canPop()) {
          rootNavigator.pop();
          loaderDismissed = true;
          if (kDebugMode) {
            print(
              '✅ [AdService] Splash returning user app open loader dismissed',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [AdService] Error dismissing loader: $e');
        }
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        useRootNavigator: true,
        useSafeArea: false,
        builder: (dialogContext) => const _AdLoadingDialog(),
      );
      loaderShown = true;
      if (kDebugMode) {
        print(
          '📥 [AdService] Loader shown for splash returning user app open ad',
        );
      }
    }

    // Give the ad auction enough time during app start/network variance.
    const loadTimeout = Duration(seconds: 10);
    final completer = Completer<void>();
    AppOpenAd? ad;
    bool didComplete = false;
    int retryCount = 0;

    void complete() {
      if (didComplete) return;
      didComplete = true;
      dismissLoader();
      ad?.dispose();
      if (!completer.isCompleted) completer.complete();
      onComplete();
    }

    void startLoad() {
      if (didComplete) return;
      if (kDebugMode) {
        print(
          '📥 [AdService] Splash returning user app open startLoad(retry=$retryCount) adUnitId=$splashAppOpen2ndTimeAdUnitId',
        );
      }

      AppOpenAd.load(
        adUnitId: splashAppOpen2ndTimeAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (loadedAd) {
            if (didComplete) {
              loadedAd.dispose();
              return;
            }
            ad = loadedAd;
            ad!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (_) {
                dismissLoader();
                if (kDebugMode) {
                  print(
                    '✅ [AdService] Splash returning user app open ad showed',
                  );
                }
              },
              onAdDismissedFullScreenContent: (_) {
                if (kDebugMode) {
                  print(
                    '✅ [AdService] Splash returning user app open ad dismissed',
                  );
                }
                ad?.dispose();
                ad = null;
                complete();
              },
              onAdFailedToShowFullScreenContent: (_, error) {
                if (kDebugMode) {
                  print(
                    '❌ [AdService] Splash returning user app open ad failed to show: $error',
                  );
                }
                ad?.dispose();
                ad = null;
                complete();
              },
            );
            if (context.mounted) {
              ad!.show();
            } else {
              ad?.dispose();
              complete();
            }
          },
          onAdFailedToLoad: (error) {
            if (kDebugMode) {
              print(
                '❌ [AdService] Splash returning user app open ad failed to load: ${error.code} ${error.message}',
              );
            }

            // Retry once for common transient failures (network / internal / SDK timing).
            final shouldRetry =
                retryCount < 1 &&
                (error.code == 0 || error.code == 2 || error.code == 3);
            if (shouldRetry) {
              retryCount++;
              if (kDebugMode) {
                print(
                  '🔄 [AdService] Retrying splash returning user app open ad load (retry=$retryCount)...',
                );
              }
              Future.delayed(const Duration(milliseconds: 800), () {
                if (!didComplete) startLoad();
              });
              return;
            }

            complete();
          },
        ),
      );
    }

    startLoad();

    Future.delayed(loadTimeout, () {
      if (!didComplete) {
        if (kDebugMode) {
          print(
            '⚠️ [AdService] Splash returning user app open ad load timeout, proceeding',
          );
        }
        complete();
      }
    });

    await completer.future;
  }

  /// Load and show splash interstitial ad on first install.
  /// RC: `splash_inter_1sttime` (Android) / `splash_inter_1sttime_ios` (iOS).
  static Future<void> loadAndShowSplashFirstTimeInterstitialAd({
    required BuildContext context,
    required VoidCallback onComplete,
  }) async {
    await showInterstitialAdForType(
      adType: 'splashFirstTime',
      context: context,
      loadAdFunction: () => loadSplashFirstTimeInterstitialAd(),
      showLoader: false,
      onAdDismissed: onComplete,
      onAdFailedToShow: (_) => onComplete(),
    );
  }

  /// Load and show splash interstitial ad for returning users.
  /// RC: `splash_inter_2ndtime` (Android) / `splash_inter_2ndtime_ios` (iOS).
  static Future<void> loadAndShowSplashReturningUserInterstitialAd({
    required BuildContext context,
    required VoidCallback onComplete,
  }) async {
    await showInterstitialAdForType(
      adType: 'splashReturning',
      context: context,
      loadAdFunction: () => loadSplashReturningInterstitialAd(),
      showLoader: false,
      onAdDismissed: onComplete,
      onAdFailedToShow: (_) => onComplete(),
    );
  }

  static void showAppOpenAd({
    Function()? onAdDismissed,
    Function(AppOpenAd)? onAdShowed,
    Function(AppOpenAd)? onAdFailedToShow,
  }) {
    if (!_shouldShowAdsOnPlatform) return;
    if (!_gdprAllowsAds) return;
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

  static bool get showAds => Platform.isIOS
      ? RemoteConfigService.showAdsIos
      : RemoteConfigService.showAds;

  /// Get the time when last interstitial ad was dismissed
  /// Used by app open ad manager to prevent showing app open ad immediately after interstitial
  static DateTime? get lastInterstitialDismissedTime =>
      _lastInterstitialDismissedTime;

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
      print(
        '📋 [AdService] App open ad dismissed, starting cooldown for interstitial ads',
      );
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
    _isShowInterstitialInProgress.clear();

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
    // Hide status bar and nav bar for true full-screen loader
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Animate loading dots (matching web app)
    _animateDots();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _animateDots() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _dots = _dots.length >= 3 ? '' : '$_dots.';
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
    final backgroundColor = theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: backgroundColor,
      systemNavigationBarColor: backgroundColor,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return PopScope(
      canPop: false, // Prevent dismissing while loading
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Material(
          type: MaterialType.canvas,
          color: backgroundColor,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: backgroundColor),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        const SizedBox(height: 24),
                        Builder(
                          builder: (context) {
                            final languageProvider =
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                );
                            final isRTL = languageProvider.isRTL;
                            final localizations = AppLocalizations.of(context);
                            final loadingText =
                                (localizations?.adLoading ?? 'Loading ad')
                                    .replaceAll('...', '')
                                    .trim();
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
        ),
      ),
    );
  }
}
