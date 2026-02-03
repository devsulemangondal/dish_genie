import '../services/storage_service.dart';

/// Service to track card open and back actions for interstitial ad display
class CardAdTracker {
  static const String _openCountKey = 'dishgenie_card_open_count';
  static const String _backCountKey = 'dishgenie_card_back_count';
  static const String _bottomNavCountKey = 'dishgenie_bottom_nav_count';
  static const String _generatePlanCountKey = 'dishgenie_generate_plan_count';
  static const String _cookingAiCountKey = 'dishgenie_cooking_ai_count';

  /// Track when a card is opened
  static Future<int> trackCardOpen() async {
    final currentCount = await StorageService.getValue<int>(_openCountKey, 0) ?? 0;
    final newCount = currentCount + 1;
    await StorageService.setValue(_openCountKey, newCount);
    return newCount;
  }

  /// Track when user goes back from a card
  static Future<int> trackCardBack() async {
    final currentCount = await StorageService.getValue<int>(_backCountKey, 0) ?? 0;
    final newCount = currentCount + 1;
    await StorageService.setValue(_backCountKey, newCount);
    return newCount;
  }

  /// Track when user taps on bottom navigation
  static Future<int> trackBottomNavTap() async {
    final currentCount = await StorageService.getValue<int>(_bottomNavCountKey, 0) ?? 0;
    final newCount = currentCount + 1;
    await StorageService.setValue(_bottomNavCountKey, newCount);
    return newCount;
  }

  /// Track when user generates a meal plan
  static Future<int> trackGeneratePlan() async {
    final currentCount = await StorageService.getValue<int>(_generatePlanCountKey, 0) ?? 0;
    final newCount = currentCount + 1;
    await StorageService.setValue(_generatePlanCountKey, newCount);
    return newCount;
  }

  /// Track when user starts cooking AI chat (first message)
  static Future<int> trackCookingAiStart() async {
    final currentCount = await StorageService.getValue<int>(_cookingAiCountKey, 0) ?? 0;
    final newCount = currentCount + 1;
    await StorageService.setValue(_cookingAiCountKey, newCount);
    return newCount;
  }

  /// Get current open count
  static Future<int> getOpenCount() async {
    return await StorageService.getValue<int>(_openCountKey, 0) ?? 0;
  }

  /// Get current back count
  static Future<int> getBackCount() async {
    return await StorageService.getValue<int>(_backCountKey, 0) ?? 0;
  }

  /// Get current bottom nav count
  static Future<int> getBottomNavCount() async {
    return await StorageService.getValue<int>(_bottomNavCountKey, 0) ?? 0;
  }

  /// Get current generate plan count
  static Future<int> getGeneratePlanCount() async {
    return await StorageService.getValue<int>(_generatePlanCountKey, 0) ?? 0;
  }

  /// Get current cooking AI count
  static Future<int> getCookingAiCount() async {
    return await StorageService.getValue<int>(_cookingAiCountKey, 0) ?? 0;
  }

  /// Reset bottom nav count
  static Future<void> resetBottomNavCount() async {
    await StorageService.setValue(_bottomNavCountKey, 0);
  }

  /// Reset generate plan count
  static Future<void> resetGeneratePlanCount() async {
    await StorageService.setValue(_generatePlanCountKey, 0);
  }

  /// Reset cooking AI count
  static Future<void> resetCookingAiCount() async {
    await StorageService.setValue(_cookingAiCountKey, 0);
  }

  /// Reset card open count
  static Future<void> resetCardOpenCount() async {
    await StorageService.setValue(_openCountKey, 0);
  }

  /// Reset card back count
  static Future<void> resetCardBackCount() async {
    await StorageService.setValue(_backCountKey, 0);
  }

  /// Reset counts (useful for testing or reset)
  static Future<void> resetCounts() async {
    await StorageService.setValue(_openCountKey, 0);
    await StorageService.setValue(_backCountKey, 0);
    await StorageService.setValue(_bottomNavCountKey, 0);
    await StorageService.setValue(_generatePlanCountKey, 0);
    await StorageService.setValue(_cookingAiCountKey, 0);
  }
}
