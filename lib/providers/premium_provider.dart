import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/billing_service.dart';
import '../services/remote_config_service.dart';
import '../services/storage_service.dart';

class PremiumProvider with ChangeNotifier {
  static const String _chatCountKey = 'dishgenie_chat_count';
  static const String _aiChefMessageCountKey = 'dishgenie_ai_chef_message_count';
  static const String _aiRecipeCountKey = 'dishgenie_ai_recipe_count';
  static const String _scanCountKey = 'dishgenie_scan_count';
  static const String _mealPlanCountKey = 'dishgenie_meal_plan_count';

  bool _isPremium = false;
  int _chatCount = 0;
  int _maxFreeChats = 5;
  int _aiChefMessageCount = 0;
  int _aiRecipeCount = 0;
  int _scanCount = 0;
  int _mealPlanCount = 0;
  bool _isInitialized = false;
  StreamSubscription? _billingSubscription;
  Timer? _subscriptionCheckTimer;

  bool get isPremium => _isPremium;
  int get chatCount => _chatCount;
  int get maxFreeChats => _maxFreeChats;
  bool get canUseChat => _isPremium || _chatCount < _maxFreeChats;
  int get aiChefMessageCount => _aiChefMessageCount;
  int get aiRecipeCount => _aiRecipeCount;
  int get scanCount => _scanCount;
  int get mealPlanCount => _mealPlanCount;

  PremiumProvider() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    // Load from storage
    final savedPremium = await StorageService.getIsPremium();
    final savedChatCount = await StorageService.getValue<int>(_chatCountKey, 0) ?? 0;
    final savedAiChefMessageCount = await StorageService.getValue<int>(_aiChefMessageCountKey, 0) ?? 0;
    final savedAiRecipeCount = await StorageService.getValue<int>(_aiRecipeCountKey, 0) ?? 0;
    final savedScanCount = await StorageService.getValue<int>(_scanCountKey, 0) ?? 0;
    final savedMealPlanCount = await StorageService.getValue<int>(_mealPlanCountKey, 0) ?? 0;
    
    // Get max free chats from remote config
    await RemoteConfigService.initialize();
    _maxFreeChats = Platform.isIOS
        ? RemoteConfigService.maxFreeChatsIos
        : RemoteConfigService.maxFreeChats;

    _isPremium = savedPremium;
    _chatCount = savedChatCount;
    _aiChefMessageCount = savedAiChefMessageCount;
    _aiRecipeCount = savedAiRecipeCount;
    _scanCount = savedScanCount;
    _mealPlanCount = savedMealPlanCount;

    // Initialize billing and check for active purchases
    await _checkBillingStatus();

    // Refresh subscription status on initialization to verify active subscriptions
    await refreshSubscriptionStatus();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _checkBillingStatus() async {
    try {
      await BillingService.initialize();

      // If BillingService already detected an entitlement (from restore stream),
      // reflect it in local storage/provider state.
      if (BillingService.hasPremiumEntitlement && !_isPremium) {
        await setPremium(true);
      }

      // Keep listening for future purchase/restored events and update local flag.
      _billingSubscription?.cancel();
      _billingSubscription = BillingService.purchaseStream.listen((purchase) {
        if (!BillingService.isPremiumProductId(purchase.productID)) return;

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          setPremium(true);
        } else if (purchase.status == PurchaseStatus.canceled ||
                   purchase.status == PurchaseStatus.error) {
          // Subscription expired or canceled - revoke premium
          setPremium(false);
        }
      });

      // Start periodic subscription status check (every 24 hours)
      _startSubscriptionStatusCheck();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> setPremium(bool value) async {
    if (_isPremium == value) return;
    
    _isPremium = value;
    await StorageService.setIsPremium(value);
    
    if (value) {
      // Reset chat count, AI chef message count, and AI recipe count when becoming premium
      _chatCount = 0;
      _aiChefMessageCount = 0;
      _aiRecipeCount = 0;
      _scanCount = 0;
      _mealPlanCount = 0;
      await StorageService.setValue(_chatCountKey, 0);
      await StorageService.setValue(_aiChefMessageCountKey, 0);
      await StorageService.setValue(_aiRecipeCountKey, 0);
      await StorageService.setValue(_scanCountKey, 0);
      await StorageService.setValue(_mealPlanCountKey, 0);
    }
    
    notifyListeners();
  }

  /// Start periodic subscription status check
  /// Checks subscription status every 24 hours to handle expiry
  void _startSubscriptionStatusCheck() {
    _subscriptionCheckTimer?.cancel();
    _subscriptionCheckTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) async {
        if (_isPremium) {
          // Only check if user is currently premium
          await BillingService.checkSubscriptionStatus();
          
          // Update premium status based on billing service entitlement
          if (!BillingService.hasPremiumEntitlement && _isPremium) {
            await setPremium(false);
          }
        }
      },
    );
  }

  /// Manually check subscription status
  /// Useful to call on app start or when user returns to app
  Future<void> refreshSubscriptionStatus() async {
    await BillingService.checkSubscriptionStatus();
    
    // Update premium status based on billing service entitlement
    final shouldBePremium = BillingService.hasPremiumEntitlement;
    if (shouldBePremium != _isPremium) {
      await setPremium(shouldBePremium);
    }
  }

  @override
  void dispose() {
    _billingSubscription?.cancel();
    _subscriptionCheckTimer?.cancel();
    super.dispose();
  }

  bool incrementChatCount() {
    if (_isPremium) {
      // Premium users have unlimited chats
      return true;
    }

    if (_chatCount >= _maxFreeChats) {
      return false;
    }

    _chatCount++;
    StorageService.setValue(_chatCountKey, _chatCount);
    notifyListeners();
    return true;
  }

  void resetChatCount() {
    _chatCount = 0;
    StorageService.setValue(_chatCountKey, 0);
    notifyListeners();
  }

  /// Get AI Chat limit from remote config (sub_aichat / sub_aichat_ios).
  /// null = unlimited, else the message limit.
  int? getAiChatLimit() {
    final config = (Platform.isIOS
        ? RemoteConfigService.subAiChatIos
        : RemoteConfigService.subAiChat)
        .trim()
        .toLowerCase();
    if (config == 'off' || config.isEmpty) return null;
    if (config == '0') return null;
    final limit = int.tryParse(config);
    return (limit != null && limit >= 1) ? limit : null;
  }

  /// Check if free user can send AI chef messages (sub_aichat: off/0=unlimited, else count limit).
  bool canSendAiChefMessage() {
    if (_isPremium) return true;
    final limit = getAiChatLimit();
    if (limit == null) return true; // 'off' or '0' = unlimited
    return _aiChefMessageCount < limit;
  }

  /// Get the AI chef message limit (sub_aichat). null = unlimited.
  int? getAiChefMessageLimit() => getAiChatLimit();

  /// Increment AI chef message count for free users
  /// Returns true if message can be sent, false if limit reached
  bool incrementAiChefMessageCount() {
    // Premium users have unlimited messages
    if (_isPremium) {
      return true;
    }

    // Check if user can send message
    if (!canSendAiChefMessage()) {
      return false;
    }

    // Increment count
    _aiChefMessageCount++;
    StorageService.setValue(_aiChefMessageCountKey, _aiChefMessageCount);
    notifyListeners();
    return true;
  }

  /// Reset AI chef message count
  void resetAiChefMessageCount() {
    _aiChefMessageCount = 0;
    StorageService.setValue(_aiChefMessageCountKey, 0);
    notifyListeners();
  }

  /// Get Start Cooking with AI Chef / Generate Recipe limit (sub_aichef). Separate from scan count.
  /// null = unlimited, else the generation limit.
  int? getAiChefRecipeLimit() {
    final config = (Platform.isIOS
        ? RemoteConfigService.subAiChefIos
        : RemoteConfigService.subAiChef)
        .trim()
        .toLowerCase();
    if (config == 'off' || config.isEmpty) return null;
    if (config == '0') return null;
    final limit = int.tryParse(config);
    return (limit != null && limit >= 1) ? limit : null;
  }

  /// Check if free user can generate AI recipes via Generate Recipe btn (sub_aichef: off/0=unlimited).
  bool canGenerateAiRecipe() {
    if (_isPremium) return true;
    final limit = getAiChefRecipeLimit();
    if (limit == null) return true; // 'off' or '0' = unlimited
    return _aiRecipeCount < limit;
  }

  /// Get the Generate Recipe limit (sub_aichef). null = unlimited. Separate from scan (sub_scancamera).
  int? getAiRecipeLimit() => getAiChefRecipeLimit();

  /// Increment Generate Recipe count (sub_aichef). Separate from scan count (sub_scancamera).
  bool incrementAiRecipeCount() {
    // Premium users have unlimited recipes
    if (_isPremium) {
      return true;
    }

    // Check if user can generate recipe
    if (!canGenerateAiRecipe()) {
      return false;
    }

    // Increment count
    _aiRecipeCount++;
    StorageService.setValue(_aiRecipeCountKey, _aiRecipeCount);
    notifyListeners();
    return true;
  }

  /// Reset AI recipe generation count
  void resetAiRecipeCount() {
    _aiRecipeCount = 0;
    StorageService.setValue(_aiRecipeCountKey, 0);
    notifyListeners();
  }

  /// Get scan limit from remote config (null = unlimited).
  /// sub_scancamera / sub_scancamera_ios: 'off' or '0' = unlimited, '1'/'2'/'3' = limit.
  int? getScannerLimit() {
    final config = (Platform.isIOS
        ? RemoteConfigService.subScanCameraIos
        : RemoteConfigService.subScanCamera)
        .trim()
        .toLowerCase();
    if (config == 'off' || config.isEmpty) return null;
    if (config == '0') return null;
    final limit = int.tryParse(config);
    return (limit != null && limit >= 1 && limit <= 3) ? limit : null;
  }

  /// Check if user can use scanner (for returning non-premium users).
  /// Premium and first-time users always allowed. Returning + non-premium: apply limit.
  Future<bool> canUseScanner() async {
    if (_isPremium) return true;

    final isFirstLaunch = await StorageService.isFirstLaunch();
    if (isFirstLaunch) return true; // New users: no limit

    final limit = getScannerLimit();
    if (limit == null) return true; // 'off' or '0' = unlimited
    return _scanCount < limit;
  }

  /// Sync check for scanner access (uses sub_scancamera). Use inside scan screen.
  /// Same logic as canUseScanner but sync; first-launch users have scanCount 0 so pass when under limit.
  bool canUseScannerSync() {
    if (_isPremium) return true;
    final limit = getScannerLimit();
    if (limit == null) return true; // 'off' or '0' = unlimited
    return _scanCount < limit;
  }

  /// Increment scan count (call when user opens scanner). Returns true if incremented.
  bool incrementScanCount() {
    if (_isPremium) return true;

    final limit = getScannerLimit();
    if (limit == null) return true; // Unlimited, no need to track
    if (_scanCount >= limit) return false;

    _scanCount++;
    StorageService.setValue(_scanCountKey, _scanCount);
    notifyListeners();
    return true;
  }

  /// Get meal plan limit from remote config (null = unlimited).
  /// sub_mealplan / sub_mealplan_ios: 'off' or '0' = unlimited, '1'/'2'/etc = limit.
  int? getMealPlanLimit() {
    final config = (Platform.isIOS
        ? RemoteConfigService.subMealPlanIos
        : RemoteConfigService.subMealPlan)
        .trim()
        .toLowerCase();
    if (config == 'off' || config.isEmpty) return null;
    if (config == '0') return null;
    final limit = int.tryParse(config);
    return (limit != null && limit >= 1) ? limit : null;
  }

  /// Check if user can create a new AI meal plan.
  bool canCreateMealPlan() {
    if (_isPremium) return true;
    final limit = getMealPlanLimit();
    if (limit == null) return true; // 'off' or '0' = unlimited
    return _mealPlanCount < limit;
  }

  /// Increment meal plan count (call after successfully creating a plan).
  bool incrementMealPlanCount() {
    if (_isPremium) return true;

    final limit = getMealPlanLimit();
    if (limit == null) return true; // Unlimited, no need to track
    if (_mealPlanCount >= limit) return false;

    _mealPlanCount++;
    StorageService.setValue(_mealPlanCountKey, _mealPlanCount);
    notifyListeners();
    return true;
  }

  bool checkPremiumFeature(String feature) {
    // Check if feature requires premium
    switch (feature) {
      case 'unlimited_chat':
      case 'advanced_recipes':
      case 'meal_planning':
      case 'grocery_lists':
      case 'ingredient_scanner':
      case 'ad_free':
        return _isPremium;
      default:
        return true; // Free features
    }
  }
}
