import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class StorageService {
  /// Premium entitlement (local-only).
  ///
  /// Note: This is intentionally local storage (as requested). Without server-side
  /// verification, this can be lost on reinstall or tampered with on rooted devices.
  static const String premiumKey = 'dishgenie_is_premium';

  static const String _languageSelectedKey = 'dishgenie_language_selected';
  static const String _languageKey = 'app_language';
  static const String _onboardingKey = 'dishgenie_onboarding_complete';
  static const String _groceryListKey = 'dishgenie_grocery_list';
  static const String _favoritesKey = 'dishgenie_favorites';
  static const String _firstLaunchKey = 'dishgenie_first_launch';

  // Cache SharedPreferences instance to avoid repeated getInstance() calls
  static SharedPreferences? _cachedPrefs;
  static bool _isInitializing = false;
  
  // Pre-initialize SharedPreferences to speed up app startup
  static Future<void> initialize() async {
    if (_cachedPrefs != null || _isInitializing) return;
    _isInitializing = true;
    try {
      _cachedPrefs = await SharedPreferences.getInstance();
    } finally {
      _isInitializing = false;
    }
  }
  
  static Future<SharedPreferences> get _prefs async {
    if (_cachedPrefs != null) {
      return _cachedPrefs!;
    }
    // If not cached, get it (shouldn't happen if initialize() was called)
    _cachedPrefs = await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  // Language
  static Future<bool> isLanguageSelected() async {
    final prefs = await _prefs;
    return prefs.getBool(_languageSelectedKey) ?? false;
  }

  static Future<void> setLanguageSelected(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_languageSelectedKey, value);
  }

  static Future<String?> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_languageKey);
  }

  static Future<void> setLanguage(String language) async {
    final prefs = await _prefs;
    await prefs.setString(_languageKey, language);
  }

  // First Launch
  static Future<bool> isFirstLaunch() async {
    final prefs = await _prefs;
    return prefs.getBool(_firstLaunchKey) ?? true; // Default to true for first launch
  }

  static Future<void> setFirstLaunchComplete() async {
    final prefs = await _prefs;
    await prefs.setBool(_firstLaunchKey, false);
  }

  // Onboarding
  static Future<bool> isOnboardingComplete() async {
    final prefs = await _prefs;
    return prefs.getBool(_onboardingKey) ?? false;
  }

  static Future<void> setOnboardingComplete(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_onboardingKey, value);
  }

  // Grocery List
  static Future<void> saveGroceryList(String json) async {
    final prefs = await _prefs;
    await prefs.setString(_groceryListKey, json);
  }

  static Future<String?> getGroceryList() async {
    final prefs = await _prefs;
    return prefs.getString(_groceryListKey);
  }

  static Future<void> clearGroceryList() async {
    final prefs = await _prefs;
    await prefs.remove(_groceryListKey);
  }

  // Favorites
  static Future<void> saveFavorites(List<String> recipeIds) async {
    final prefs = await _prefs;
    await prefs.setStringList(_favoritesKey, recipeIds);
  }

  static Future<List<String>> getFavorites() async {
    final prefs = await _prefs;
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  static Future<void> addFavorite(String recipeId) async {
    final favorites = await getFavorites();
    if (!favorites.contains(recipeId)) {
      favorites.add(recipeId);
      await saveFavorites(favorites);
    }
  }

  static Future<void> removeFavorite(String recipeId) async {
    final favorites = await getFavorites();
    favorites.remove(recipeId);
    await saveFavorites(favorites);
  }

  static Future<bool> isFavorite(String recipeId) async {
    final favorites = await getFavorites();
    return favorites.contains(recipeId);
  }

  // Saved Recipes
  static const String _savedRecipesKey = 'dishgenie_saved_recipes';

  static Future<void> saveSavedRecipes(List<String> recipeIds) async {
    final prefs = await _prefs;
    await prefs.setStringList(_savedRecipesKey, recipeIds);
  }

  static Future<List<String>> getSavedRecipes() async {
    final prefs = await _prefs;
    return prefs.getStringList(_savedRecipesKey) ?? [];
  }

  // Meal Plan
  static const String _mealPlanKey = 'dishgenie_saved_meal_plan';

  static Future<void> saveMealPlan(String json) async {
    final prefs = await _prefs;
    await prefs.setString(_mealPlanKey, json);
  }

  static Future<String?> getMealPlan() async {
    final prefs = await _prefs;
    return prefs.getString(_mealPlanKey);
  }

  static Future<void> clearMealPlan() async {
    final prefs = await _prefs;
    await prefs.remove(_mealPlanKey);
  }

  // Chat History - Last Active Chat (matching web app CHAT_HISTORY_KEY)
  static const String _chatHistoryKey = 'dishgenie_chat_history';
  
  // Saved Chats - All Conversations (matching web app SAVED_CHATS_KEY)
  static const String _savedChatsKey = 'dishgenie_saved_chats';

  // Last Active Chat (web app format: { messages: [], chatId: null })
  static Future<void> saveChatHistory(String json) async {
    final prefs = await _prefs;
    await prefs.setString(_chatHistoryKey, json);
  }

  static Future<String?> getChatHistory() async {
    final prefs = await _prefs;
    return prefs.getString(_chatHistoryKey);
  }

  static Future<void> clearChatHistory() async {
    final prefs = await _prefs;
    await prefs.remove(_chatHistoryKey);
  }

  // All Saved Conversations (web app format: [{ id, name, messages, createdAt, updatedAt }])
  static Future<List<Map<String, dynamic>>> getChatConversations() async {
    try {
      final prefs = await _prefs;
      final json = prefs.getString(_savedChatsKey);
      if (json != null) {
        final data = jsonDecode(json) as List<dynamic>;
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      print('Error loading chat conversations: $e');
    }
    return [];
  }

  static Future<void> saveChatConversations(
    List<Map<String, dynamic>> conversations,
  ) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_savedChatsKey, jsonEncode(conversations));
    } catch (e) {
      print('Error saving chat conversations: $e');
    }
  }

  // Saved Grocery Lists
  static const String _savedGroceryListsKey = 'dishgenie_saved_grocery_lists';

  static Future<void> saveSavedGroceryLists(String json) async {
    final prefs = await _prefs;
    await prefs.setString(_savedGroceryListsKey, json);
  }

  static Future<String?> getSavedGroceryLists() async {
    final prefs = await _prefs;
    return prefs.getString(_savedGroceryListsKey);
  }

  // Theme Mode
  static const String _themeModeKey = 'dishgenie_theme_mode';

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setString(_themeModeKey, mode.toString());
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await _prefs;
    final modeString = prefs.getString(_themeModeKey);
    if (modeString == null) return ThemeMode.system;

    switch (modeString) {
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  // Generic value storage
  static Future<void> setValue(String key, dynamic value) async {
    final prefs = await _prefs;
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  static Future<T?> getValue<T>(String key, T? defaultValue) async {
    final prefs = await _prefs;
    if (T == bool) {
      return (prefs.getBool(key) ?? defaultValue) as T?;
    } else if (T == int) {
      return (prefs.getInt(key) ?? defaultValue) as T?;
    } else if (T == double) {
      return (prefs.getDouble(key) ?? defaultValue) as T?;
    } else if (T == String) {
      return (prefs.getString(key) ?? defaultValue) as T?;
    } else if (T == List<String>) {
      return (prefs.getStringList(key) ?? defaultValue) as T?;
    }
    return defaultValue;
  }

  static Future<bool> getIsPremium() async {
    return await getValue<bool>(premiumKey, false) ?? false;
  }

  static Future<void> setIsPremium(bool value) async {
    await setValue(premiumKey, value);
  }
}
