import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/billing_service.dart';
import '../services/remote_config_service.dart';
import '../services/storage_service.dart';

class PremiumProvider with ChangeNotifier {
  static const String _chatCountKey = 'dishgenie_chat_count';
  static const String _aiChefMessageCountKey = 'dishgenie_ai_chef_message_count';
  static const String _aiRecipeCountKey = 'dishgenie_ai_recipe_count';

  bool _isPremium = false;
  int _chatCount = 0;
  int _maxFreeChats = 5;
  int _aiChefMessageCount = 0;
  int _aiRecipeCount = 0;
  bool _isInitialized = false;
  StreamSubscription? _billingSubscription;
  Timer? _subscriptionCheckTimer;

  bool get isPremium => _isPremium;
  int get chatCount => _chatCount;
  int get maxFreeChats => _maxFreeChats;
  bool get canUseChat => _isPremium || _chatCount < _maxFreeChats;
  int get aiChefMessageCount => _aiChefMessageCount;
  int get aiRecipeCount => _aiRecipeCount;

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
    
    // Get max free chats from remote config
    await RemoteConfigService.initialize();
    _maxFreeChats = RemoteConfigService.maxFreeChats;

    _isPremium = savedPremium;
    _chatCount = savedChatCount;
    _aiChefMessageCount = savedAiChefMessageCount;
    _aiRecipeCount = savedAiRecipeCount;

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
      await StorageService.setValue(_chatCountKey, 0);
      await StorageService.setValue(_aiChefMessageCountKey, 0);
      await StorageService.setValue(_aiRecipeCountKey, 0);
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

  /// Check if free user can send AI chef messages based on remote config
  /// Returns true if user can send, false otherwise
  bool canSendAiChefMessage() {
    // Premium users can always send messages
    if (_isPremium) {
      return true;
    }

    // Get ai_chef config from remote config
    final aiChefConfig = RemoteConfigService.aiChef.trim().toLowerCase();
    
    // If config is "off", free users cannot send messages
    if (aiChefConfig == 'off' || aiChefConfig.isEmpty) {
      return false;
    }

    // Parse the limit (should be a string integer like "1", "2", "3", etc.)
    try {
      final limit = int.parse(aiChefConfig);
      // If limit is 0 or negative, don't allow
      if (limit <= 0) {
        return false;
      }
      // Check if user has reached the limit
      return _aiChefMessageCount < limit;
    } catch (e) {
      // If parsing fails, don't allow (safety default)
      return false;
    }
  }

  /// Get the AI chef message limit from remote config
  int? getAiChefMessageLimit() {
    final aiChefConfig = RemoteConfigService.aiChef.trim().toLowerCase();
    
    if (aiChefConfig == 'off' || aiChefConfig.isEmpty) {
      return null; // No limit (disabled)
    }

    try {
      final limit = int.parse(aiChefConfig);
      return limit > 0 ? limit : null;
    } catch (e) {
      return null;
    }
  }

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

  /// Check if free user can generate AI recipes based on remote config
  /// Returns true if user can generate, false otherwise
  bool canGenerateAiRecipe() {
    // Premium users can always generate recipes
    if (_isPremium) {
      return true;
    }

    // Get ai_chef config from remote config (same config used for chat)
    final aiChefConfig = RemoteConfigService.aiChef.trim().toLowerCase();
    
    // If config is "off", free users cannot generate recipes
    if (aiChefConfig == 'off' || aiChefConfig.isEmpty) {
      return false;
    }

    // Parse the limit (should be a string integer like "1", "2", "3", etc.)
    try {
      final limit = int.parse(aiChefConfig);
      // If limit is 0 or negative, don't allow
      if (limit <= 0) {
        return false;
      }
      // Check if user has reached the limit
      return _aiRecipeCount < limit;
    } catch (e) {
      // If parsing fails, don't allow (safety default)
      return false;
    }
  }

  /// Get the AI recipe generation limit from remote config
  int? getAiRecipeLimit() {
    final aiChefConfig = RemoteConfigService.aiChef.trim().toLowerCase();
    
    if (aiChefConfig == 'off' || aiChefConfig.isEmpty) {
      return null; // No limit (disabled)
    }

    try {
      final limit = int.parse(aiChefConfig);
      return limit > 0 ? limit : null;
    } catch (e) {
      return null;
    }
  }

  /// Increment AI recipe generation count for free users
  /// Returns true if recipe can be generated, false if limit reached
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
