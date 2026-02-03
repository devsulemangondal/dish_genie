import 'ad_service.dart';
import 'remote_config_service.dart';

/// Helper class for managing interstitial ads based on triggers and remote config
class InterstitialAdHelper {
  // Track trigger counts for frequency control
  static final Map<String, int> _triggerCounts = {};

  /// Show interstitial ad for bottom tab click
  /// Config: "off, 1, 2, 3, 4..." - shows on specified counts
  static Future<void> showBottomTabInterstitial({
    Function()? onAdDismissed,
    Function()? onAdFailed,
  }) async {
    await RemoteConfigService.initialize();
    
    final config = RemoteConfigService.bottomInter;
    if (!RemoteConfigService.shouldShowInterstitial(config, _incrementCount('bottom'))) {
      return;
    }

    // Show ad with loader (loader is handled in AdService)
    await AdService.showInterstitialAdForType(
      adType: 'bottom',
      loadAdFunction: () => AdService.loadBottomInterstitialAd(),
      onAdDismissed: onAdDismissed,
      onAdFailedToShow: (ad) => onAdFailed?.call(),
    );
  }

  /// Show interstitial ad for card open/back press
  /// Config: "off, open1, open2, ..." or "off, back1, back2, ..."
  static Future<void> showCardInterstitial({
    required String action, // 'open' or 'back'
    Function()? onAdDismissed,
    Function()? onAdFailed,
  }) async {
    await RemoteConfigService.initialize();
    
    final count = _incrementCount('card_$action');
    if (!RemoteConfigService.shouldShowCardInterstitial(action, count)) {
      return;
    }

    // Show ad with loader (loader is handled in AdService)
    await AdService.showInterstitialAdForType(
      adType: 'card',
      loadAdFunction: () => AdService.loadCardInterstitialAd(),
      onAdDismissed: onAdDismissed,
      onAdFailedToShow: (ad) => onAdFailed?.call(),
    );
  }

  /// Show interstitial ad for generate meal plan
  /// Config: "off, 1, 2, 3, 4..." - shows on specified counts
  static Future<void> showGeneratePlanInterstitial({
    Function()? onAdDismissed,
    Function()? onAdFailed,
  }) async {
    await RemoteConfigService.initialize();
    
    final config = RemoteConfigService.generatePlanInter;
    if (!RemoteConfigService.shouldShowInterstitial(config, _incrementCount('generatePlan'))) {
      return;
    }

    // Show ad with loader (loader is handled in AdService)
    await AdService.showInterstitialAdForType(
      adType: 'generatePlan',
      loadAdFunction: () => AdService.loadGeneratePlanInterstitialAd(),
      onAdDismissed: onAdDismissed,
      onAdFailedToShow: (ad) => onAdFailed?.call(),
    );
  }

  /// Show interstitial ad for cooking AI start
  /// Config: "off, 1, 2, 3, 4..." - shows on specified counts
  static Future<void> showCookingAiInterstitial({
    Function()? onAdDismissed,
    Function()? onAdFailed,
  }) async {
    await RemoteConfigService.initialize();
    
    final config = RemoteConfigService.cookingAiInter;
    if (!RemoteConfigService.shouldShowInterstitial(config, _incrementCount('cookingAi'))) {
      return;
    }

    // Show ad with loader (loader is handled in AdService)
    await AdService.showInterstitialAdForType(
      adType: 'cookingAi',
      loadAdFunction: () => AdService.loadCookingAiInterstitialAd(),
      onAdDismissed: onAdDismissed,
      onAdFailedToShow: (ad) => onAdFailed?.call(),
    );
  }

  /// Increment and return count for a trigger key
  static int _incrementCount(String key) {
    _triggerCounts[key] = (_triggerCounts[key] ?? 0) + 1;
    return _triggerCounts[key]!;
  }

  /// Reset count for a trigger key (useful for testing or manual reset)
  static void resetCount(String key) {
    _triggerCounts[key] = 0;
  }

  /// Get current count for a trigger key
  static int getCount(String key) {
    return _triggerCounts[key] ?? 0;
  }
}
