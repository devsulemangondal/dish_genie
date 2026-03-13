import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _isInitialized = false;

  /// Check if Remote Config is initialized
  static bool get isInitialized => _isInitialized && _remoteConfig != null;

  // Default values
  static const Map<String, dynamic> _defaults = {
    'show_ads': true,
    'interstitial_ad_frequency': 5,
    'show_premium_features': true,
    'max_free_chats': 5,
    'enable_voice_feature': true,
    'enable_scanner_feature': true,
    'app_version_required': '1.0.0',
    'maintenance_mode':
        false, // Should be false by default - only enable remotely when needed
    'premium_product_id_weekly': 'weekly_sub',
    // Ad configuration flags
    // Fail-safe: keep Pro/paywall hidden unless explicitly enabled remotely.
    'weekly_sub': false,
    // Weekly plan: trial added from backend (Play Console/App Store) - show trial text when true
    'weekly_sub_trial': false,
    'splash_inter': true,
    'app_open': true,
    // Resume app open ad when app returns from background (Android / iOS)
    'resume_appopen': true,
    'resume_appopen_ios': true,
    // Splash app open ad on first install (Android / iOS separate keys)
    'splash_appopen_1sttime': false,
    'splash_appopen_1sttime_ios': false,
    // Splash app open ad for returning user (2nd+ open) (Android / iOS separate keys)
    'splash_appopen_2ndtime': false,
    'splash_appopen_2ndtime_ios': false,
    // Native ad flags
    'language_native': true,
    'language_native_ios': true,
    'home_native': true,
    'recipe_native': true,
    'plan_native': true,
    'shop_native': true,
    'chat_native': true,
    'reciepedetaile_native': true,
    'camera_native': true,
    // Onboarding native ad (Android / iOS separate keys)
    'onboarding_native': false,
    'onboarding_native_ios': false,
    // Interstitial ad configuration
    'bottom_inter': '5',
    'card_inter': 'open5',
    'generateplan_inter': '5',
    'cookingai_inter': 'off',
    // Exit interstitial (when user confirms exit from bottom sheet)
    'exit_inter': false,
    'exit_inter_ios': false,
    // Chat reset / new chat interstitial (Android / iOS)
    'chatreset_inter': false,
    'chatreset_inter_ios': false,
    // View Plan / Continue Plan interstitial - returning user on home (Android / iOS)
    'viewplancontinue_inter': false,
    'viewplancontinue_inter_ios': false,
    // Pro button on home screen - show subscription entry (Android / iOS)
    'sub_probutton': false,
    'sub_probutton_ios': false,
    // Premium card in settings screen (Android / iOS)
    'sub_card': false,
    'sub_card_ios': false,
    // Scan/Camera limit for returning non-premium users: 'off'/'0'=unlimited, '1'/'2'/'3'=limit (Android / iOS)
    'sub_scancamera': 'off',
    'sub_scancamera_ios': 'off',
    // AI Meal Planner limit: 'off'/'0'=unlimited, '1'/'2'/etc=plan limit (Android / iOS)
    'sub_mealplan': 'off',
    'sub_mealplan_ios': 'off',
    // AI Chat (Meal Generator) limit: 'off'/'0'=unlimited, '1'/'2'/etc=message limit (Android / iOS)
    'sub_aichat': 'off',
    'sub_aichat_ios': 'off',
    // Start Cooking with AI Chef / Generate Recipe btn (AI generate screen): 'off'/'0'=unlimited (separate from scan)
    'sub_aichef': 'off',
    'sub_aichef_ios': 'off',
    // Show subscription screen after splash app open: 'off'/'0'=always, N=every Nth session (3,6,9...)
    'sub_splash': 'off',
    'sub_splash_ios': 'off',
    // Show discount dialog on Pro screen close: once per 24 hours (Android / iOS)
    'discount_popup': false,
    'discount_popup_ios': false,
    // Bottom banner on bottom nav screens only (Android / iOS)
    'bottom_banner': false,
    'bottom_banner_ios': false,
    'ai_chef': '5',
    // Supabase configuration (matching web app: VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY)
    'supabase_url': '',
    'supabase_anon_key': '',
  };

  static String get premiumProductIdWeekly =>
      _remoteConfig?.getString('premium_product_id_weekly') ??
      _defaults['premium_product_id_weekly'];

  static Future<bool> initialize() async {
    if (_isInitialized && _remoteConfig != null) {
      if (kDebugMode) {
        print('[RemoteConfig] ✅ Already initialized');
      }
      return true;
    }

    try {
      if (kDebugMode) {
        print('[RemoteConfig] 🔄 Initializing...');
      }

      // Check if Firebase is initialized first
      try {
        Firebase.app(); // This will throw if Firebase is not initialized
      } catch (e) {
        if (kDebugMode) {
          print(
            '[RemoteConfig] ❌ Firebase not initialized. Please call Firebase.initializeApp() first.',
          );
        }
        _isInitialized =
            false; // Don't mark as initialized if Firebase is not ready
        return false;
      }

      _remoteConfig = FirebaseRemoteConfig.instance;

      final isDev = !kReleaseMode;
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: isDev
              ? Duration
                    .zero // No cache in development
              : const Duration(hours: 1), // 1 hour cache in production
        ),
      );

      await _remoteConfig!.setDefaults(_defaults);

      _isInitialized = true;
      if (kDebugMode) {
        print('[RemoteConfig] ✅ Initialized successfully');
        print(
          '[RemoteConfig] 📋 Mode: ${isDev ? "Development (no cache)" : "Production (1h cache)"}',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[RemoteConfig] ❌ Initialization error: $e');
        print(
          '[RemoteConfig] 📋 Will use default values. Make sure Firebase is properly configured.',
        );
      }
      _isInitialized = false; // Don't mark as initialized if there was an error
      _remoteConfig = null; // Clear the config instance
      return false;
    }
  }

  static bool get showAds =>
      _remoteConfig?.getBool('show_ads') ?? _defaults['show_ads'];

  static int get interstitialAdFrequency =>
      _remoteConfig?.getInt('interstitial_ad_frequency') ??
      _defaults['interstitial_ad_frequency'];

  static bool get showPremiumFeatures =>
      _remoteConfig?.getBool('show_premium_features') ??
      _defaults['show_premium_features'];

  static int get maxFreeChats =>
      _remoteConfig?.getInt('max_free_chats') ?? _defaults['max_free_chats'];

  static bool get enableVoiceFeature =>
      _remoteConfig?.getBool('enable_voice_feature') ??
      _defaults['enable_voice_feature'];

  static bool get enableScannerFeature =>
      _remoteConfig?.getBool('enable_scanner_feature') ??
      _defaults['enable_scanner_feature'];

  static String get appVersionRequired =>
      _remoteConfig?.getString('app_version_required') ??
      _defaults['app_version_required'];

  static bool get maintenanceMode =>
      _remoteConfig?.getBool('maintenance_mode') ??
      _defaults['maintenance_mode'];

  // Weekly subscription flag
  static bool get weeklySub {
    // If Remote Config isn't ready, treat as disabled (fail-safe).
    if (!isInitialized) return _defaults['weekly_sub'] as bool;
    return _remoteConfig!.getBool('weekly_sub');
  }

  /// Weekly subscription trial added from backend (Play Console / App Store).
  /// When true, Pro screen shows "3 Days Free Trial" for weekly plan.
  static bool get weeklySubTrial {
    if (!isInitialized) return _defaults['weekly_sub_trial'] as bool;
    return _remoteConfig!.getBool('weekly_sub_trial');
  }

  // Splash interstitial ad
  static bool get splashInter =>
      _remoteConfig?.getBool('splash_inter') ?? _defaults['splash_inter'];

  // App open ad
  static bool get appOpen =>
      _remoteConfig?.getBool('app_open') ?? _defaults['app_open'];

  /// Resume app open ad when app returns from background - Android (show only when true)
  static bool get resumeAppOpen =>
      _remoteConfig?.getBool('resume_appopen') ??
      _defaults['resume_appopen'];

  /// Resume app open ad when app returns from background - iOS (show only when true)
  static bool get resumeAppOpenIos =>
      _remoteConfig?.getBool('resume_appopen_ios') ??
      _defaults['resume_appopen_ios'];

  /// Splash app open ad on first install - Android (show only when true)
  static bool get splashAppOpen1stTime =>
      _remoteConfig?.getBool('splash_appopen_1sttime') ??
      _defaults['splash_appopen_1sttime'];

  /// Splash app open ad on first install - iOS (show only when true)
  static bool get splashAppOpen1stTimeIos =>
      _remoteConfig?.getBool('splash_appopen_1sttime_ios') ??
      _defaults['splash_appopen_1sttime_ios'];

  /// Splash app open ad for returning user - Android (show only when true)
  static bool get splashAppOpen2ndTime =>
      _remoteConfig?.getBool('splash_appopen_2ndtime') ??
      _defaults['splash_appopen_2ndtime'];

  /// Splash app open ad for returning user - iOS (show only when true)
  static bool get splashAppOpen2ndTimeIos =>
      _remoteConfig?.getBool('splash_appopen_2ndtime_ios') ??
      _defaults['splash_appopen_2ndtime_ios'];

  // Native ad flags
  static bool get languageNative =>
      _remoteConfig?.getBool('language_native') ?? _defaults['language_native'];

  /// Language native ad - iOS (show only when true)
  static bool get languageNativeIos =>
      _remoteConfig?.getBool('language_native_ios') ??
      _defaults['language_native_ios'];

  static bool get homeNative =>
      _remoteConfig?.getBool('home_native') ?? _defaults['home_native'];

  static bool get recipeNative =>
      _remoteConfig?.getBool('recipe_native') ?? _defaults['recipe_native'];

  static bool get planNative =>
      _remoteConfig?.getBool('plan_native') ?? _defaults['plan_native'];

  static bool get shopNative =>
      _remoteConfig?.getBool('shop_native') ?? _defaults['shop_native'];

  static bool get chatNative =>
      _remoteConfig?.getBool('chat_native') ?? _defaults['chat_native'];

  static bool get recipeDetailNative =>
      _remoteConfig?.getBool('reciepedetaile_native') ??
      _defaults['reciepedetaile_native'];

  static bool get cameraNative =>
      _remoteConfig?.getBool('camera_native') ?? _defaults['camera_native'];

  /// Onboarding native ad - Android (show only when true)
  static bool get onboardingNative =>
      _remoteConfig?.getBool('onboarding_native') ??
      _defaults['onboarding_native'];

  /// Onboarding native ad - iOS (show only when true)
  static bool get onboardingNativeIos =>
      _remoteConfig?.getBool('onboarding_native_ios') ??
      _defaults['onboarding_native_ios'];

  /// Exit interstitial ad - Android (show when user confirms exit)
  static bool get exitInter =>
      _remoteConfig?.getBool('exit_inter') ?? _defaults['exit_inter'];

  /// Exit interstitial ad - iOS (show when user confirms exit)
  static bool get exitInterIos =>
      _remoteConfig?.getBool('exit_inter_ios') ?? _defaults['exit_inter_ios'];

  /// Chat reset interstitial - Android (show when user starts new chat)
  static bool get chatResetInter =>
      _remoteConfig?.getBool('chatreset_inter') ?? _defaults['chatreset_inter'];

  /// Chat reset interstitial - iOS (show when user starts new chat)
  static bool get chatResetInterIos =>
      _remoteConfig?.getBool('chatreset_inter_ios') ??
      _defaults['chatreset_inter_ios'];

  /// View Plan / Continue Plan interstitial - Android (returning user on home)
  static bool get viewPlanContinueInter =>
      _remoteConfig?.getBool('viewplancontinue_inter') ??
      _defaults['viewplancontinue_inter'];

  /// View Plan / Continue Plan interstitial - iOS (returning user on home)
  static bool get viewPlanContinueInterIos =>
      _remoteConfig?.getBool('viewplancontinue_inter_ios') ??
      _defaults['viewplancontinue_inter_ios'];

  /// Pro button on home screen - Android (show subscription entry)
  static bool get subProButton =>
      _remoteConfig?.getBool('sub_probutton') ?? _defaults['sub_probutton'];

  /// Pro button on home screen - iOS (show subscription entry)
  static bool get subProButtonIos =>
      _remoteConfig?.getBool('sub_probutton_ios') ??
      _defaults['sub_probutton_ios'];

  /// Premium card in settings - Android
  static bool get subCard =>
      _remoteConfig?.getBool('sub_card') ?? _defaults['sub_card'];

  /// Premium card in settings - iOS
  static bool get subCardIos =>
      _remoteConfig?.getBool('sub_card_ios') ?? _defaults['sub_card_ios'];

  /// Scan/Camera limit - Android ('off'/'0'=unlimited, '1'/'2'/'3'=scan limit)
  static String get subScanCamera =>
      (_remoteConfig?.getString('sub_scancamera') ?? _defaults['sub_scancamera'] as String).trim();

  /// Scan/Camera limit - iOS
  static String get subScanCameraIos =>
      (_remoteConfig?.getString('sub_scancamera_ios') ?? _defaults['sub_scancamera_ios'] as String).trim();

  /// AI Meal Planner limit - Android ('off'/'0'=unlimited, '1'/'2'/etc=plan limit)
  static String get subMealPlan =>
      (_remoteConfig?.getString('sub_mealplan') ?? _defaults['sub_mealplan'] as String).trim();

  /// AI Meal Planner limit - iOS
  static String get subMealPlanIos =>
      (_remoteConfig?.getString('sub_mealplan_ios') ?? _defaults['sub_mealplan_ios'] as String).trim();

  /// AI Chat (Meal Generator) limit - Android ('off'/'0'=unlimited, '1'/'2'/etc=message limit)
  static String get subAiChat =>
      (_remoteConfig?.getString('sub_aichat') ?? _defaults['sub_aichat'] as String).trim();

  /// AI Chat limit - iOS
  static String get subAiChatIos =>
      (_remoteConfig?.getString('sub_aichat_ios') ?? _defaults['sub_aichat_ios'] as String).trim();

  /// Start Cooking with AI Chef / Generate Recipe btn limit - Android (separate count from scan)
  static String get subAiChef =>
      (_remoteConfig?.getString('sub_aichef') ?? _defaults['sub_aichef'] as String).trim();

  /// Start Cooking with AI Chef / Generate Recipe btn limit - iOS
  static String get subAiChefIos =>
      (_remoteConfig?.getString('sub_aichef_ios') ?? _defaults['sub_aichef_ios'] as String).trim();

  /// Show subscription after splash app open - Android ('off'/'0'=always, N=every Nth session)
  static String get subSplash =>
      (_remoteConfig?.getString('sub_splash') ?? _defaults['sub_splash'] as String).trim();

  /// Show subscription after splash app open - iOS
  static String get subSplashIos =>
      (_remoteConfig?.getString('sub_splash_ios') ?? _defaults['sub_splash_ios'] as String).trim();

  /// Discount popup on Pro close - Android (once per 24h)
  static bool get discountPopup =>
      _remoteConfig?.getBool('discount_popup') ?? _defaults['discount_popup'];

  /// Discount popup on Pro close - iOS
  static bool get discountPopupIos =>
      _remoteConfig?.getBool('discount_popup_ios') ?? _defaults['discount_popup_ios'];

  /// Bottom banner on bottom nav screens - Android (show only when true)
  static bool get bottomBanner =>
      _remoteConfig?.getBool('bottom_banner') ?? _defaults['bottom_banner'];

  /// Bottom banner on bottom nav screens - iOS (show only when true)
  static bool get bottomBannerIos =>
      _remoteConfig?.getBool('bottom_banner_ios') ?? _defaults['bottom_banner_ios'];

  // Interstitial ad configuration strings
  static String get bottomInter {
    if (_remoteConfig != null && _isInitialized) {
      try {
        final value = _remoteConfig!.getString('bottom_inter').trim();
        return value.isNotEmpty ? value : (_defaults['bottom_inter'] as String);
      } catch (e) {
        return _defaults['bottom_inter'] as String;
      }
    }
    return _defaults['bottom_inter'] as String;
  }

  static String get cardInter {
    if (_remoteConfig != null && _isInitialized) {
      try {
        final value = _remoteConfig!.getString('card_inter').trim();
        return value.isNotEmpty ? value : (_defaults['card_inter'] as String);
      } catch (e) {
        return _defaults['card_inter'] as String;
      }
    }
    return _defaults['card_inter'] as String;
  }

  static String get generatePlanInter {
    if (_remoteConfig != null && _isInitialized) {
      try {
        final value = _remoteConfig!.getString('generateplan_inter').trim();
        return value.isNotEmpty
            ? value
            : (_defaults['generateplan_inter'] as String);
      } catch (e) {
        return _defaults['generateplan_inter'] as String;
      }
    }
    return _defaults['generateplan_inter'] as String;
  }

  static String get cookingAiInter {
    if (_remoteConfig != null && _isInitialized) {
      try {
        final value = _remoteConfig!.getString('cookingai_inter').trim();
        return value.isNotEmpty
            ? value
            : (_defaults['cookingai_inter'] as String);
      } catch (e) {
        return _defaults['cookingai_inter'] as String;
      }
    }
    return _defaults['cookingai_inter'] as String;
  }

  static String get aiChef {
    if (_remoteConfig != null && _isInitialized) {
      try {
        final value = _remoteConfig!.getString('ai_chef').trim();
        return value.isNotEmpty ? value : (_defaults['ai_chef'] as String);
      } catch (e) {
        return _defaults['ai_chef'] as String;
      }
    }
    return _defaults['ai_chef'] as String;
  }

  // Helper methods to check if interstitial should be shown
  // Supports formats: "off", "1", "2", "3", or "1, 2, 3" (shows on any matching count)
  static bool shouldShowInterstitial(String configValue, int triggerCount) {
    final trimmed = configValue.trim().toLowerCase();
    if (trimmed == 'off' || trimmed.isEmpty) return false;

    // Handle comma-separated values like "1, 2, 3, 4"
    final parts = trimmed.split(',').map((s) => s.trim()).toList();
    if (parts.length > 1) {
      // Check if current count matches any value
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num != null && num == triggerCount) {
          return true;
        }
      }
      return false;
    }

    // Single value - treat as threshold (show every Nth time)
    try {
      final threshold = int.parse(trimmed);
      return threshold > 0 && triggerCount % threshold == 0;
    } catch (e) {
      return false;
    }
  }

  // Helper method to check card_inter pattern
  // Supports formats: "off", "open5", "back5" (single value only)
  // action should be "open" or "back"
  static bool shouldShowCardInterstitial(String action, int triggerCount) {
    final config = cardInter.trim().toLowerCase();
    if (config == 'off' || config.isEmpty) return false;

    final actionLower = action.toLowerCase();
    if (actionLower != 'open' && actionLower != 'back') {
      return false;
    }

    // Check if config starts with the action (e.g., "open5" or "back5")
    if (config.startsWith(actionLower)) {
      try {
        // Extract number after "open" or "back"
        final numStr = config.substring(actionLower.length);
        final threshold = int.parse(numStr);
        if (threshold > 0) {
          // Show ad when counter >= threshold
          return triggerCount >= threshold;
        }
      } catch (e) {
        // If parsing fails, don't show ad
        return false;
      }
    }

    return false;
  }

  static Future<void> fetchAndActivate() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_remoteConfig == null) {
      if (kDebugMode) {
        print('[RemoteConfig] ⚠️ Cannot fetch - Remote Config is null');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('[RemoteConfig] 🔄 Fetching and activating...');
      }

      final activated = await _remoteConfig!.fetchAndActivate();

      if (kDebugMode) {
        if (activated) {
          print('[RemoteConfig] ✅ Fetch successful - new values activated');
        } else {
          print(
            '[RemoteConfig] ℹ️ Fetch completed - using cached/default values',
          );
        }

        // Print all remote config values
        _printAllValues();
      }
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        print(
          '[RemoteConfig] ❌ Fetch error: [${e.plugin}/${e.code}] ${e.message}',
        );
        print('[RemoteConfig] 📋 Stack: $st');
        print(
          '[RemoteConfig] 📋 lastFetchStatus: ${_remoteConfig!.lastFetchStatus}',
        );
        print(
          '[RemoteConfig] 📋 lastFetchTime: ${_remoteConfig!.lastFetchTime}',
        );
        _printAllValues();
      }

      // One quick retry for transient internal errors (common during startup/network hiccups).
      if (e.code == 'internal') {
        try {
          if (kDebugMode) {
            print('[RemoteConfig] 🔁 Retrying fetch in 800ms...');
          }
          await Future.delayed(const Duration(milliseconds: 800));
          final activated = await _remoteConfig!.fetchAndActivate();
          if (kDebugMode) {
            print(
              activated
                  ? '[RemoteConfig] ✅ Retry fetch successful - new values activated'
                  : '[RemoteConfig] ℹ️ Retry fetch completed - using cached/default values',
            );
            _printAllValues();
          }
        } catch (retryError) {
          if (kDebugMode) {
            print('[RemoteConfig] ❌ Retry fetch error: $retryError');
            print('[RemoteConfig] 📋 Using default/cached values');
            _printAllValues();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[RemoteConfig] ❌ Fetch error: $e');
        print('[RemoteConfig] 📋 Using default/cached values');
        _printAllValues();
      }
    }
  }

  /// Print all remote config values with their source (REMOTE or DEFAULT)
  static void _printAllValues() {
    if (!kDebugMode || _remoteConfig == null) return;

    print('\n[RemoteConfig] 📊 Current Values:');
    print('─' * 60);

    // Boolean values
    final booleanKeys = [
      'weekly_sub',
      'weekly_sub_trial',
      'splash_inter',
      'app_open',
      'resume_appopen',
      'resume_appopen_ios',
      'splash_appopen_1sttime',
      'splash_appopen_1sttime_ios',
      'splash_appopen_2ndtime',
      'splash_appopen_2ndtime_ios',
      'language_native',
      'language_native_ios',
      'home_native',
      'recipe_native',
      'plan_native',
      'shop_native',
      'chat_native',
      'reciepedetaile_native',
      'camera_native',
      'onboarding_native',
      'onboarding_native_ios',
      'exit_inter',
      'exit_inter_ios',
      'chatreset_inter',
      'chatreset_inter_ios',
      'viewplancontinue_inter',
      'viewplancontinue_inter_ios',
      'sub_probutton',
      'sub_probutton_ios',
      'sub_card',
      'sub_card_ios',
      'show_ads',
      'show_premium_features',
      'enable_voice_feature',
      'enable_scanner_feature',
      'maintenance_mode',
      'discount_popup',
      'discount_popup_ios',
      'bottom_banner',
      'bottom_banner_ios',
    ];

    print('\n📌 Boolean Values:');
    for (final key in booleanKeys) {
      try {
        final configValue = _remoteConfig!.getValue(key);
        final value = configValue.asBool();
        final source = configValue.source == ValueSource.valueRemote
            ? 'REMOTE ✅'
            : configValue.source == ValueSource.valueDefault
            ? 'DEFAULT'
            : 'STATIC';
        print('  $key: $value ($source)');
      } catch (e) {
        final defaultValue = _defaults[key];
        print('  $key: $defaultValue (DEFAULT - Error: $e)');
      }
    }

    // String values
    final stringKeys = [
      'bottom_inter',
      'card_inter',
      'generateplan_inter',
      'cookingai_inter',
      'ai_chef',
      'sub_scancamera',
      'sub_scancamera_ios',
      'sub_mealplan',
      'sub_mealplan_ios',
      'sub_aichat',
      'sub_aichat_ios',
      'sub_aichef',
      'sub_aichef_ios',
      'sub_splash',
      'sub_splash_ios',
      'premium_product_id_weekly',
      'app_version_required',
    ];

    print('\n📌 String Values:');
    for (final key in stringKeys) {
      try {
        final configValue = _remoteConfig!.getValue(key);
        final value = configValue.asString();
        final source = configValue.source == ValueSource.valueRemote
            ? 'REMOTE ✅'
            : configValue.source == ValueSource.valueDefault
            ? 'DEFAULT'
            : 'STATIC';
        print('  $key: "$value" ($source)');
      } catch (e) {
        final defaultValue = _defaults[key];
        print('  $key: "$defaultValue" (DEFAULT - Error: $e)');
      }
    }

    // Integer values
    final intKeys = ['interstitial_ad_frequency', 'max_free_chats'];

    print('\n📌 Integer Values:');
    for (final key in intKeys) {
      try {
        final configValue = _remoteConfig!.getValue(key);
        final value = configValue.asInt();
        final source = configValue.source == ValueSource.valueRemote
            ? 'REMOTE ✅'
            : configValue.source == ValueSource.valueDefault
            ? 'DEFAULT'
            : 'STATIC';
        print('  $key: $value ($source)');
      } catch (e) {
        final defaultValue = _defaults[key];
        print('  $key: $defaultValue (DEFAULT - Error: $e)');
      }
    }

    // Count remote vs default
    int remoteCount = 0;
    int defaultCount = 0;
    for (final key in [...booleanKeys, ...stringKeys, ...intKeys]) {
      try {
        final configValue = _remoteConfig!.getValue(key);
        if (configValue.source == ValueSource.valueRemote) {
          remoteCount++;
        } else {
          defaultCount++;
        }
      } catch (e) {
        defaultCount++;
      }
    }

    print('\n📊 Summary:');
    print('  Remote values: $remoteCount');
    print('  Default/Cached values: $defaultCount');
    if (remoteCount == 0 && defaultCount > 0) {
      print('  ⚠️ Warning: No remote values fetched - check Firebase setup');
    }
    print('─' * 60);
  }

  static T getValue<T>(String key, T defaultValue) {
    if (!_isInitialized) return defaultValue;

    try {
      final value = _remoteConfig?.getValue(key);
      if (T == bool) {
        return (value?.asBool() ?? defaultValue) as T;
      } else if (T == int) {
        return (value?.asInt() ?? defaultValue) as T;
      } else if (T == double) {
        return (value?.asDouble() ?? defaultValue) as T;
      } else if (T == String) {
        return (value?.asString() ?? defaultValue) as T;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get string value from Remote Config (convenience method)
  /// Returns empty string if not found or not initialized
  static String getString(String key) {
    return getValue<String>(key, '');
  }

  /// Manually print all remote config values (useful for debugging)
  static void logAllValues() {
    if (!kDebugMode) return;
    _printAllValues();
  }
}
