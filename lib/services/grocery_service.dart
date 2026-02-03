import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/grocery_list.dart';
import '../data/models/meal_plan.dart';
import 'supabase_service.dart';

class GroceryService {
  // Generate grocery list using Supabase Edge Function
  // Matches web app: accepts mealPlan, recipes, pantryItems, budgetMode, budget, country
  static Future<GroceryList?> generateGroceryList({
    MealPlan? mealPlan,
    List<Map<String, dynamic>>? recipes,
    List<String>? pantryItems,
    bool? budgetMode,
    String? budget,
    String? country,
    // Legacy support: if recipeIds provided, convert to recipes format
    List<String>? recipeIds,
  }) async {
    try {
      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        print('Error: Supabase is not initialized');
        return null;
      }

      // Get Supabase URL and key
      final supabaseUrl = SupabaseService.url;
      final supabaseKey = SupabaseService.anonKey;

      if (supabaseUrl == null || supabaseKey == null) {
        return null;
      }

      // Use direct HTTP call (matching web app pattern)
      // Web app uses: supabase.functions.invoke which automatically adds apikey header
      final functionUrl = '$supabaseUrl/functions/v1/generate-grocery-list';
      
      // Match web app exactly: send mealPlan, recipes, pantryItems, budgetMode, budget, country
      final requestBody = <String, dynamic>{};
      
      if (mealPlan != null) {
        // Send mealPlan object (matching web app)
        requestBody['mealPlan'] = mealPlan.toJson();
      } else if (recipes != null && recipes.isNotEmpty) {
        // Send recipes array (matching web app format: Array<{title, ingredients}>)
        requestBody['recipes'] = recipes;
      } else if (recipeIds != null && recipeIds.isNotEmpty) {
        // Legacy: Convert recipeIds to recipes format if needed
        // Note: This is a fallback - ideally should pass mealPlan or recipes
        requestBody['recipes'] = recipeIds.map((id) => {
          'title': 'Recipe $id',
          'ingredients': <String>[],
        }).toList();
      }
      
      if (pantryItems != null && pantryItems.isNotEmpty) {
        requestBody['pantryItems'] = pantryItems;
      }
      if (budgetMode != null) {
        requestBody['budgetMode'] = budgetMode;
      }
      if (budget != null) {
        requestBody['budget'] = budget;
      }
      if (country != null) {
        requestBody['country'] = country;
      }
      
      final httpResponse = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey, // Required by Supabase Edge Functions (SDK adds this automatically)
        },
        body: json.encode(requestBody),
      );

      if (httpResponse.statusCode != 200) {
        final errorBody = json.decode(httpResponse.body) as Map<String, dynamic>?;
        final errorMessage = errorBody?['error']?.toString() ?? 
            errorBody?['message']?.toString() ?? 
            'Request failed with status ${httpResponse.statusCode}';
        print('❌ [GroceryService] HTTP Error: $errorMessage');
        print('❌ [GroceryService] Response body: ${httpResponse.body}');
        throw Exception(errorMessage);
      }

      final data = json.decode(httpResponse.body) as Map<String, dynamic>;
      
      if (data['groceryList'] != null) {
        final groceryListData = data['groceryList'] as Map<String, dynamic>;
        
        // Match web app: generate IDs for items if missing (API might not return IDs)
        if (groceryListData['items'] != null) {
          final items = groceryListData['items'] as List<dynamic>;
          if (items.isEmpty) {
            print('⚠️ [GroceryService] Warning: Grocery list has no items');
          }
          groceryListData['items'] = items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            // Generate ID if missing (matching web app pattern)
            if (item['id'] == null) {
              item['id'] = 'item-$index-${DateTime.now().millisecondsSinceEpoch}';
            }
            // Ensure checked is false by default
            if (item['checked'] == null) {
              item['checked'] = false;
            }
            return item;
          }).toList();
        } else {
          print('⚠️ [GroceryService] Warning: Grocery list has no items field');
          groceryListData['items'] = [];
        }
        
        print('✅ [GroceryService] Successfully generated grocery list with ${(groceryListData['items'] as List).length} items');
        return GroceryList.fromJson(groceryListData);
      }
      
      print('⚠️ [GroceryService] Warning: Response has no groceryList field');
      return null;
    } catch (e, stackTrace) {
      print('Error generating grocery list: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  // Detect category for an item
  static String detectCategory(String itemName) {
    final name = itemName.toLowerCase();
    
    final categories = {
      'Produce': ['apple', 'banana', 'orange', 'tomato', 'potato', 'onion',
        'garlic', 'lettuce', 'spinach', 'carrot', 'broccoli', 'pepper',
        'cucumber', 'mango', 'grapes', 'lemon', 'ginger', 'coriander',
        'mint', 'cilantro', 'cabbage', 'cauliflower', 'eggplant',
        'zucchini', 'mushroom', 'avocado', 'peas', 'beans', 'vegetable',
        'fruit', 'salad'],
      'Dairy': ['milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg',
        'paneer', 'ghee', 'dahi', 'curd'],
      'Meat & Protein': ['chicken', 'beef', 'mutton', 'lamb', 'fish',
        'shrimp', 'salmon', 'turkey', 'meat', 'mince', 'kebab', 'tikka'],
      'Grains & Bread': ['rice', 'bread', 'flour', 'pasta', 'naan', 'roti',
        'chapati', 'paratha', 'wheat', 'oats', 'cereal'],
      'Spices': ['salt', 'pepper', 'masala', 'turmeric', 'cumin', 'chili',
        'paprika', 'cinnamon', 'curry', 'spice'],
      'Pantry': ['oil', 'sugar', 'honey', 'vinegar', 'sauce', 'ketchup',
        'soy', 'nuts', 'lentils', 'daal', 'dal'],
      'Beverages': ['water', 'juice', 'tea', 'coffee', 'soda', 'drink'],
    };
    
    for (final entry in categories.entries) {
      if (entry.value.any((keyword) => name.contains(keyword))) {
        return entry.key;
      }
    }
    
    return 'Other';
  }
}
