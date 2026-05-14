import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ad_service.dart';
import 'remote_config_service.dart';

/// Helper class for managing interstitial ads based on triggers and remote config
class InterstitialAdHelper {
  // Track trigger counts for frequency control
  static final Map<String, int> _triggerCounts = {};

  /// Grocery smart suggestion card **Add** tap. RC [add_sug_inter] / [add_sug_inter_ios] (string `off` / `1` / `2` / `3`…).
  /// Runs [afterAdOrSkip] after ad closes, load failure, or when RC skips (no ad).
  static Future<void> showGrocerySmartSuggestionAddInterstitial({
    required BuildContext context,
    required Future<void> Function() afterAdOrSkip,
  }) async {
    await RemoteConfigService.initialize();
    try {
      if (RemoteConfigService.isInitialized) {
        await RemoteConfigService.fetchAndActivate();
      }
    } catch (_) {}

    if (!(Platform.isIOS
        ? RemoteConfigService.showAdsIos
        : RemoteConfigService.showAds)) {
      await afterAdOrSkip();
      return;
    }

    final config = Platform.isIOS
        ? RemoteConfigService.addSugInterIos
        : RemoteConfigService.addSugInter;
    final count = _incrementCount('groceryAddSug');
    if (!RemoteConfigService.shouldShowInterstitial(config, count)) {
      await afterAdOrSkip();
      return;
    }

    if (!context.mounted) {
      await afterAdOrSkip();
      return;
    }

    try {
      await AdService.showInterstitialAdForType(
        adType: 'groceryAddSug',
        context: context,
        loadAdFunction: () => AdService.loadGroceryAddSuggestionInterstitialAd(),
        onAdDismissed: () async {
          await afterAdOrSkip();
        },
        onAdFailedToShow: (_) async {
          await afterAdOrSkip();
        },
      );
    } catch (_) {
      await afterAdOrSkip();
    }
  }

  /// Recipe detail: system back or app bar back. RC [recipe_backpress_inter] / [recipe_backpress_inter_ios].
  /// Calls [onLeave] after ad is dismissed/failed/skipped (always pop/navigate from [onLeave]).
  static Future<void> showRecipeDetailBackInterstitial({
    required BuildContext context,
    required VoidCallback onLeave,
  }) async {
    await RemoteConfigService.initialize();
    try {
      if (RemoteConfigService.isInitialized) {
        await RemoteConfigService.fetchAndActivate();
      }
    } catch (_) {}

    if (!(Platform.isIOS
        ? RemoteConfigService.showAdsIos
        : RemoteConfigService.showAds)) {
      onLeave();
      return;
    }

    final config = Platform.isIOS
        ? RemoteConfigService.recipeBackpressInterIos
        : RemoteConfigService.recipeBackpressInter;
    final count = _incrementCount('recipeDetailBack');
    if (!RemoteConfigService.shouldShowInterstitial(config, count)) {
      onLeave();
      return;
    }

    if (!context.mounted) {
      onLeave();
      return;
    }

    try {
      await AdService.showInterstitialAdForType(
        adType: 'recipeDetailBack',
        context: context,
        loadAdFunction: () => AdService.loadRecipeDetailBackInterstitialAd(),
        onAdDismissed: onLeave,
        onAdFailedToShow: (_) => onLeave(),
      );
    } catch (_) {
      onLeave();
    }
  }

  /// Show interstitial when user switches bottom tabs (not when re-tapping the active tab).
  /// RC: [bottom_tab_inter] Android, [bottom_tab_inter_ios] iOS — string values.
  /// `"off"` / empty: never. `"3"`: every 3rd switch (3rd, 6th, …), same rules as [shouldShowInterstitial].
  static Future<void> showBottomTabInterstitial({
    BuildContext? context,
    Function()? onAdDismissed,
    Function()? onAdFailed,
  }) async {
    void log(String msg) => debugPrint('📢 [BottomTabInter] $msg');

    await RemoteConfigService.initialize();
    try {
      if (RemoteConfigService.isInitialized) {
        await RemoteConfigService.fetchAndActivate();
      }
    } catch (e, st) {
      log('fetchAndActivate failed (using cached RC): $e');
      debugPrint('$st');
    }

    log(RemoteConfigService.describeBottomTabInterRc());

    if (!(Platform.isIOS
        ? RemoteConfigService.showAdsIos
        : RemoteConfigService.showAds)) {
      log('skip: Remote Config show_ads / show_ads_ios is false');
      return;
    }

    final config = Platform.isIOS
        ? RemoteConfigService.bottomTabInterIos
        : RemoteConfigService.bottomTabInter;
    final switchCount = _incrementCount('bottomTab');
    final allow = RemoteConfigService.shouldShowInterstitial(config, switchCount);
    log(
      'platform=${Platform.operatingSystem} activeRcKey=${Platform.isIOS ? "bottom_tab_inter_ios" : "bottom_tab_inter"} '
      'config="$config" switchCount=$switchCount shouldShow=$allow',
    );
    if (!allow) {
      return;
    }

    try {
      await AdService.showInterstitialAdForType(
        adType: 'bottomTab',
        context: context,
        loadAdFunction: () => AdService.loadBottomTabChangeInterstitialAd(),
        onAdDismissed: onAdDismissed,
        onAdFailedToShow: (ad) {
          log('onAdFailedToShow callback (ad=${ad != null})');
          onAdFailed?.call();
        },
      );
      log('showInterstitialAdForType finished');
    } catch (e, st) {
      log('exception in showInterstitialAdForType: $e');
      debugPrint('$st');
      onAdFailed?.call();
    }
  }

  /// Show interstitial ad for card open/back press
  /// Config: "off, open1, open2, ..." or "off, back1, back2, ..."
  static Future<void> showCardInterstitial({
    required String action, // 'open' or 'back'
    Function()? onAdDismissed,
    Function()? onAdFailed,
  }) async {
    await RemoteConfigService.initialize();

    if (!(Platform.isIOS
        ? RemoteConfigService.showAdsIos
        : RemoteConfigService.showAds)) {
      return;
    }

    final count = _incrementCount('card_$action');
    final cardCfg = Platform.isIOS
        ? RemoteConfigService.cardInterIos
        : RemoteConfigService.cardInter;
    if (!RemoteConfigService.shouldShowCardInterstitial(
      action,
      count,
      config: cardCfg,
    )) {
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

    if (!(Platform.isIOS
        ? RemoteConfigService.showAdsIos
        : RemoteConfigService.showAds)) {
      return;
    }

    final config = Platform.isIOS
        ? RemoteConfigService.generatePlanInterIos
        : RemoteConfigService.generatePlanInter;
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

    if (!(Platform.isIOS
        ? RemoteConfigService.showAdsIos
        : RemoteConfigService.showAds)) {
      return;
    }

    final config = Platform.isIOS
        ? RemoteConfigService.cookingAiInterIos
        : RemoteConfigService.cookingAiInter;
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
