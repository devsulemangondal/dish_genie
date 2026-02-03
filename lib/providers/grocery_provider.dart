import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/grocery_list.dart';
import '../data/models/grocery_item.dart';
import '../data/models/meal_plan.dart';
import '../services/storage_service.dart';
import '../services/grocery_service.dart';
import 'dart:convert';

class GroceryProvider with ChangeNotifier {
  GroceryList? _groceryList;
  bool _isLoading = false;
  bool _isLoadingFromStorage = false;
  final _uuid = const Uuid();

  GroceryList? get groceryList => _groceryList;
  bool get isLoading => _isLoading;
  bool get isLoadingFromStorage => _isLoadingFromStorage;
  
  GroceryProvider() {
    // Load from storage asynchronously without blocking UI
    // Use microtask to ensure it runs after the current frame
    // Don't notify listeners during load to avoid blocking UI render
    Future.microtask(() => _loadFromStorage());
  }

  Future<void> _loadFromStorage() async {
    if (_isLoadingFromStorage) return; // Prevent duplicate loads
    _isLoadingFromStorage = true;
    // Don't notify listeners here - let UI render first with null list
    
    try {
      final json = await StorageService.getGroceryList();
      if (json != null) {
        // Parse JSON - for very large lists, this could be optimized with compute()
        // but for typical grocery lists, direct parsing is fast enough
        final data = jsonDecode(json) as Map<String, dynamic>;
        _groceryList = GroceryList.fromJson(data);
        // Ensure all items have prices and recalculate total (in case it was wrong or zero)
        _recalculateEstimatedCost();
      }
    } catch (e) {
      print('Error loading grocery list: $e');
    } finally {
      _isLoadingFromStorage = false;
      // Only notify after load completes - UI will update smoothly
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    if (_groceryList != null) {
      try {
        await StorageService.saveGroceryList(
          jsonEncode(_groceryList!.toJson()),
        );
      } catch (e) {
        print('Error saving grocery list to storage: $e');
        rethrow; // Let caller handle the error
      }
    }
  }

  Future<GroceryList?> generateGroceryList({
    MealPlan? mealPlan,
    List<Map<String, dynamic>>? recipes,
    List<String>? recipeIds, // Legacy support
    String? budget,
    bool? budgetMode,
    List<String>? pantryItems,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Match web app: send mealPlan if available, otherwise use recipes or recipeIds (legacy)
      final list = await GroceryService.generateGroceryList(
        mealPlan: mealPlan,
        recipes: recipes,
        recipeIds: recipeIds, // Legacy fallback
        budget: budget,
        budgetMode: budgetMode,
        pantryItems: pantryItems,
      );

      if (list != null) {
        _groceryList = list;
        // Ensure all items have prices and recalculate total
        _recalculateEstimatedCost();
        await _saveToStorage();
      }

      _isLoading = false;
      notifyListeners();
      return _groceryList;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> addItem(GroceryItem item) async {
    if (_groceryList != null) {
      final items = List<GroceryItem>.from(_groceryList!.items)..add(item);
      _groceryList = _groceryList!.copyWith(items: items);
      _recalculateEstimatedCost();
      try {
        await _saveToStorage();
      } catch (e) {
        print('Error saving after adding item: $e');
        // Continue to update UI even if save fails
      }
      notifyListeners();
    }
  }

  Future<void> addItemsByName(List<String> names) async {
    if (_groceryList == null) {
      _groceryList = GroceryList(
        name: 'Grocery List',
        estimatedCost: '\$0',
        items: [],
        categoriesSummary: {},
        budgetTips: [],
        mealPrepOrder: [],
      );
    }

    final newItems = names.map((name) {
      // Generate estimated price for the item
      final estimatedPrice = _generatePriceRangeForItem(name);
      return GroceryItem(
        id: _uuid.v4(),
        name: name,
        quantity: '1',
        unit: '',
        category: GroceryService.detectCategory(name),
        estimatedPrice: estimatedPrice,
        checked: false,
      );
    }).toList();

    final items = List<GroceryItem>.from(_groceryList!.items)..addAll(newItems);
    _groceryList = _groceryList!.copyWith(items: items);
    _recalculateEstimatedCost();
    try {
      await _saveToStorage();
    } catch (e) {
      print('Error saving after adding items: $e');
      // Continue to update UI even if save fails
    }
    notifyListeners();
  }

  /// Generate price range for an item based on its name
  /// Matches the logic from grocery_list_screen.dart
  String _generatePriceRangeForItem(String itemName) {
    final name = itemName.toLowerCase();
    if (name.contains('chicken') ||
        name.contains('meat') ||
        name.contains('beef')) {
      return '\$2-5';
    } else if (name.contains('milk') ||
        name.contains('cheese') ||
        name.contains('yogurt')) {
      return '\$3-6';
    } else if (name.contains('bread') ||
        name.contains('rice') ||
        name.contains('pasta')) {
      return '\$1-3';
    } else if (name.contains('vegetable') ||
        name.contains('fruit') ||
        name.contains('produce')) {
      return '\$1-4';
    } else {
      return '\$2-5';
    }
  }

  Future<void> removeItem(String itemId) async {
    if (_groceryList != null) {
      final items = _groceryList!.items.where((item) => item.id != itemId).toList();
      _groceryList = _groceryList!.copyWith(items: items);
      _recalculateEstimatedCost();
      try {
        await _saveToStorage();
      } catch (e) {
        print('Error saving after removing item: $e');
        // Continue to update UI even if save fails
      }
      notifyListeners();
    }
  }

  Future<void> toggleItem(String itemId) async {
    if (_groceryList != null) {
      final items = _groceryList!.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(checked: !item.checked);
        }
        return item;
      }).toList();
      _groceryList = _groceryList!.copyWith(items: items);
      try {
        await _saveToStorage();
      } catch (e) {
        print('Error saving after toggling item: $e');
        // Continue to update UI even if save fails
      }
      notifyListeners();
    }
  }

  Map<String, List<GroceryItem>> getItemsByCategory() {
    if (_groceryList == null) return {};
    
    final Map<String, List<GroceryItem>> grouped = {};
    for (final item in _groceryList!.items) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }
    return grouped;
  }

  double getProgress() {
    if (_groceryList == null || _groceryList!.items.isEmpty) return 0.0;
    final checked = _groceryList!.items.where((item) => item.checked).length;
    return checked / _groceryList!.items.length;
  }

  double get calculatedTotal {
    if (_groceryList == null) return 0.0;
    // Parse estimated cost
    final costStr = _groceryList!.estimatedCost.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(costStr) ?? 0.0;
  }

  /// Calculate estimated total from all items' estimated prices
  /// Handles both single prices (e.g., "$5") and price ranges (e.g., "$2-5")
  String _calculateEstimatedTotal(List<GroceryItem> items) {
    if (items.isEmpty) return '\$0';

    double total = 0.0;

    for (final item in items) {
      // Skip items with invalid prices (null, empty, or $0)
      if (item.estimatedPrice != null && 
          item.estimatedPrice!.isNotEmpty && 
          item.estimatedPrice != '\$0' &&
          item.estimatedPrice != '0') {
        final price = item.estimatedPrice!;
        
        // Handle price ranges like "$2-5" or "$10-15"
        if (price.contains('-')) {
          final parts = price.split('-');
          if (parts.length == 2) {
            // Extract numbers from both parts
            final minStr = parts[0].replaceAll(RegExp(r'[^\d.]'), '');
            final maxStr = parts[1].replaceAll(RegExp(r'[^\d.]'), '');
            final min = double.tryParse(minStr) ?? 0.0;
            final max = double.tryParse(maxStr) ?? 0.0;
            // Only add if both min and max are valid (not 0)
            if (min > 0 && max > 0) {
              // Use average of min and max
              total += (min + max) / 2;
              continue; // Skip the fallback calculation
            }
          }
        } else {
          // Handle single price like "$5" or "$10.50"
          final priceStr = price.replaceAll(RegExp(r'[^\d.]'), '');
          final priceValue = double.tryParse(priceStr) ?? 0.0;
          if (priceValue > 0) {
            total += priceValue;
            continue; // Skip the fallback calculation
          }
        }
      }
      
      // Fallback: calculate based on item name if price is invalid or missing
      {
        // If no estimated price, use a default estimate based on item name
        // This matches the _generatePriceRange logic from grocery_list_screen.dart
        final name = item.name.toLowerCase();
        if (name.contains('chicken') ||
            name.contains('meat') ||
            name.contains('beef')) {
          total += 3.5; // Average of $2-5
        } else if (name.contains('milk') ||
            name.contains('cheese') ||
            name.contains('yogurt')) {
          total += 4.5; // Average of $3-6
        } else if (name.contains('bread') ||
            name.contains('rice') ||
            name.contains('pasta')) {
          total += 2.0; // Average of $1-3
        } else if (name.contains('vegetable') ||
            name.contains('fruit') ||
            name.contains('produce')) {
          total += 2.5; // Average of $1-4
        } else {
          total += 3.5; // Default average of $2-5
        }
      }
    }

    // Format as currency
    return '\$${total.toStringAsFixed(2)}';
  }

  /// Ensure all items have estimated prices set
  List<GroceryItem> _ensureItemsHavePrices(List<GroceryItem> items) {
    return items.map((item) {
      // If no price or empty or "$0", generate a price based on item name
      if (item.estimatedPrice == null || 
          item.estimatedPrice!.isEmpty || 
          item.estimatedPrice == '\$0' ||
          item.estimatedPrice == '0') {
        return item.copyWith(
          estimatedPrice: _generatePriceRangeForItem(item.name),
        );
      }
      return item;
    }).toList();
  }

  /// Recalculate and update the estimated cost based on current items
  void _recalculateEstimatedCost() {
    if (_groceryList != null && _groceryList!.items.isNotEmpty) {
      // First ensure all items have prices
      final itemsWithPrices = _ensureItemsHavePrices(_groceryList!.items);
      _groceryList = _groceryList!.copyWith(items: itemsWithPrices);
      
      // Then calculate the total
      final newEstimatedCost = _calculateEstimatedTotal(_groceryList!.items);
      _groceryList = _groceryList!.copyWith(estimatedCost: newEstimatedCost);
    } else if (_groceryList != null && _groceryList!.items.isEmpty) {
      // If no items, set to $0
      _groceryList = _groceryList!.copyWith(estimatedCost: '\$0');
    }
  }

  Future<void> clearList() async {
    _groceryList = null;
    await StorageService.clearGroceryList();
    notifyListeners();
  }

  Future<void> setGroceryList(GroceryList list) async {
    _groceryList = list;
    try {
      await _saveToStorage();
    } catch (e) {
      print('Error saving after setting grocery list: $e');
      // Continue to update UI even if save fails
    }
    notifyListeners();
  }

  // Saved Lists
  List<Map<String, dynamic>> _savedLists = [];

  List<Map<String, dynamic>> get savedLists => _savedLists;

  Future<void> loadSavedLists() async {
    try {
      final json = await StorageService.getSavedGroceryLists();
      if (json != null) {
        final data = jsonDecode(json) as List<dynamic>;
        _savedLists = data.map((e) => e as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading saved lists: $e');
    }
  }

  Future<void> saveCurrentList(String name) async {
    if (_groceryList == null) {
      throw Exception('No grocery list to save');
    }

    try {
      // Load existing saved lists
      final savedListsJson = await StorageService.getSavedGroceryLists();
      List<Map<String, dynamic>> lists = [];
      
      if (savedListsJson != null) {
        try {
          final data = jsonDecode(savedListsJson) as List<dynamic>;
          lists = data.map((e) => e as Map<String, dynamic>).toList();
        } catch (e) {
          print('Error parsing saved lists, starting fresh: $e');
          lists = [];
        }
      }

      // Check for duplicate name and remove if exists (update behavior)
      final existingIndex = lists.indexWhere((l) => l['name'] == name);
      if (existingIndex != -1) {
        // Remove existing list with same name to avoid duplicates
        lists.removeAt(existingIndex);
      }

      // Limit saved lists to prevent storage bloat (keep last 50)
      const maxSavedLists = 50;
      if (lists.length >= maxSavedLists) {
        // Remove oldest lists (first in list)
        lists.removeRange(0, lists.length - maxSavedLists + 1);
      }

      // Create new list entry - use complete GroceryList structure
      // This ensures all required fields (categories_summary, budget_tips, meal_prep_order) are included
      final listToSave = _groceryList!.copyWith(
        id: _uuid.v4(),
        name: name,
        createdAt: DateTime.now(),
      );
      
      // Convert to JSON using the model's toJson method to ensure all fields are included
      final newList = listToSave.toJson();
      // Add created_at if not already in toJson (for backward compatibility)
      if (!newList.containsKey('created_at')) {
        newList['created_at'] = DateTime.now().toIso8601String();
      }

      // Add new list (at the end, so most recent is last)
      lists.add(newList);
      
      // Save to storage
      await StorageService.saveSavedGroceryLists(jsonEncode(lists));
      
      // Update in-memory state
      _savedLists = lists;
      notifyListeners();
      
      // Reload to ensure consistency
      await loadSavedLists();
    } catch (e) {
      print('Error saving list: $e');
      rethrow; // Re-throw to let UI handle the error
    }
  }
}
