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
    'splash_inter': true,
    'app_open': true,
    // Native ad flags
    'language_native': true,
    'home_native': true,
    'recipe_native': true,
    'plan_native': true,
    'shop_native': true,
    'chat_native': true,
    'reciepedetaile_native': true,
    'camera_native': true,
    // Interstitial ad configuration
    'bottom_inter': '5',
    'card_inter': 'open5',
    'generateplan_inter': '5',
    'cookingai_inter': 'off',
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

  // Splash interstitial ad
  static bool get splashInter =>
      _remoteConfig?.getBool('splash_inter') ?? _defaults['splash_inter'];

  // App open ad
  static bool get appOpen =>
      _remoteConfig?.getBool('app_open') ?? _defaults['app_open'];

  // Native ad flags
  static bool get languageNative =>
      _remoteConfig?.getBool('language_native') ?? _defaults['language_native'];

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
      'splash_inter',
      'app_open',
      'language_native',
      'home_native',
      'recipe_native',
      'plan_native',
      'shop_native',
      'chat_native',
      'reciepedetaile_native',
      'camera_native',
      'show_ads',
      'show_premium_features',
      'enable_voice_feature',
      'enable_scanner_feature',
      'maintenance_mode',
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
