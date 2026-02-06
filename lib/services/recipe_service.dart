import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models/ingredient.dart';
import '../data/models/instruction.dart';
import '../data/models/nutrition.dart';
import '../data/models/recipe.dart';
import 'supabase_service.dart';

class RecipeService {
  static String _normalizeImageUrl(String? raw) {
    if (raw == null) return '';
    final s = raw.trim();
    if (s.isEmpty) return '';

    // Already absolute http(s)
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // Protocol-relative URL
    if (s.startsWith('//')) return 'https:$s';

    // Supabase storage / relative paths → make absolute using Supabase base URL.
    final base = SupabaseService.url?.trim();
    if (base != null && base.isNotEmpty) {
      // Common cases:
      // - "/storage/v1/object/public/..."
      // - "storage/v1/object/public/..."
      // - "/images/..." (custom path)
      if (s.startsWith('/')) return '$base$s';
      if (s.startsWith('storage/') || s.startsWith('storage/v1/')) {
        return '$base/$s';
      }
    }

    // Fallback: if it looks like a domain without scheme, assume https.
    if (s.startsWith('www.')) return 'https://$s';

    return s;
  }

  // Generate recipe using Supabase Edge Function
  static Future<Recipe?> generateRecipe({
    required String ingredients,
    int? cookingTime,
    int? targetCalories,
    String? skillLevel,
    int? servings,
    String? cuisine,
    String? dietType,
    String? healthGoal,
    String? mood,
    String? language,
    String?
    imageBase64, // Support image-based recipe generation (matching web app)
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
      final functionUrl = '$supabaseUrl/functions/v1/generate-recipe';

      // Match web app exactly: include imageBase64 if provided (for image-based recipe generation)
      // Strip data URI prefix if present (some APIs expect just base64, others expect data URI)
      String? imageToSend = imageBase64;
      if (imageToSend != null && imageToSend.startsWith('data:')) {
        // Extract just the base64 part after the comma
        final commaIndex = imageToSend.indexOf(',');
        if (commaIndex != -1) {
          imageToSend = imageToSend.substring(commaIndex + 1);
        }
      }

      final httpResponse = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey, // Required by Supabase Edge Functions
        },
        body: json.encode({
          'ingredients': ingredients,
          if (imageToSend != null)
            'imageBase64':
                imageToSend, // Send base64 string (without data URI prefix)
          if (cookingTime != null)
            'cookingTime': cookingTime, // Match web app: camelCase
          if (targetCalories != null)
            'targetCalories': targetCalories, // Match web app: camelCase
          if (skillLevel != null)
            'skillLevel': skillLevel, // Match web app: camelCase
          if (servings != null) 'servings': servings,
          if (cuisine != null) 'cuisine': cuisine,
          if (dietType != null)
            'dietType': dietType, // Match web app: camelCase
          if (healthGoal != null)
            'healthGoal': healthGoal, // Match web app: camelCase
          if (mood != null) 'mood': mood,
        }),
      );

      if (httpResponse.statusCode != 200) {
        final errorBody =
            json.decode(httpResponse.body) as Map<String, dynamic>?;
        final errorMessage =
            errorBody?['error']?.toString() ?? 'Request failed';
        throw Exception(errorMessage);
      }

      final data = json.decode(httpResponse.body) as Map<String, dynamic>;

      // Check if there's an error
      if (data['error'] != null) {
        final errorMsg = data['error'].toString();
        print('Recipe generation API error: $errorMsg');
        throw Exception(errorMsg);
      }

      // Web app returns { recipe }, so extract it
      if (data['recipe'] != null) {
        try {
          final recipe = Recipe.fromJson(
            data['recipe'] as Map<String, dynamic>,
          );

          // If imageBase64 was provided, always use it for AI-generated recipes
          // This ensures scanned images are displayed for recipes generated from images
          if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
            // Ensure imageBase64 is in data URI format
            String imageDataUri = imageBase64.trim();
            if (!imageDataUri.startsWith('data:image/')) {
              // Assume JPEG if no format specified
              imageDataUri = 'data:image/jpeg;base64,$imageDataUri';
            }

            // Validate that it's a proper data URI with base64 content
            if (imageDataUri.contains(',') && imageDataUri.length > 50) {
              // Update recipe with the provided image
              final updatedRecipe = recipe.copyWith(image: imageDataUri);
              if (kDebugMode) {
                print(
                  '✅ [RecipeService] Added imageBase64 to recipe: ${updatedRecipe.title}',
                );
                print(
                  '   Image format: ${imageDataUri.substring(0, imageDataUri.length > 50 ? 50 : imageDataUri.length)}...',
                );
                print('   Image length: ${imageDataUri.length}');
              }
              return updatedRecipe;
            } else {
              if (kDebugMode) {
                print(
                  '⚠️ [RecipeService] Invalid imageBase64 format, using recipe image or placeholder',
                );
              }
            }
          }

          return recipe;
        } catch (e) {
          print('Error parsing recipe JSON: $e');
          print('Recipe data: ${data['recipe']}');
          throw Exception('Failed to parse recipe: $e');
        }
      }

      // If no recipe in response, log the full response for debugging
      print('No recipe in API response. Response: $data');
      return null;
    } catch (e) {
      print('Error generating recipe: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow; // Re-throw to allow caller to handle the error
    }
  }

  // Get recipe by slug
  static Recipe? getRecipeBySlug(String slug, List<Recipe> recipes) {
    try {
      return recipes.firstWhere(
        (recipe) => recipe.slug == slug || recipe.id == slug,
      );
    } catch (e) {
      return null;
    }
  }

  // Search recipes
  static List<Recipe> searchRecipes(List<Recipe> recipes, String query) {
    if (query.isEmpty) return recipes;

    final lowerQuery = query.toLowerCase();
    return recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowerQuery) ||
          recipe.description.toLowerCase().contains(lowerQuery) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)) ||
          recipe.cuisine.toLowerCase().contains(lowerQuery) ||
          recipe.ingredients.any(
            (ing) => ing.name.toLowerCase().contains(lowerQuery),
          );
    }).toList();
  }

  // Filter recipes by category (must match the same logic used for category counts in recipe_generator_screen)
  static List<Recipe> filterByCategory(List<Recipe> recipes, String? category) {
    if (category == null || category.isEmpty) return recipes;

    final cat = category.toLowerCase();
    return recipes.where((Recipe r) {
      switch (cat) {
        case 'quick':
          return r.tags.any((t) => t.toLowerCase().contains('quick')) ||
              (r.prepTime + r.cookTime) <= 20;
        case 'protein':
          return r.tags.any((t) => t.toLowerCase().contains('high protein'));
        case 'chicken':
          return r.title.toLowerCase().contains('chicken') ||
              r.ingredients.any(
                (i) => i.name.toLowerCase().contains('chicken'),
              );
        case 'fish':
          return r.title.toLowerCase().contains('fish') ||
              r.title.toLowerCase().contains('salmon') ||
              r.title.toLowerCase().contains('seafood');
        case 'eggs':
          return r.ingredients.any((i) => i.name.toLowerCase().contains('egg'));
        case 'veggie':
          return r.tags.any((t) {
            final lower = t.toLowerCase();
            return lower.contains('vegan') ||
                lower.contains('vegetarian') ||
                lower.contains('healthy');
          });
        case 'kids':
          return r.difficulty == 'Easy' ||
              r.tags.any((t) => t.toLowerCase().contains('kid'));
        case 'budget':
          return r.tags.any((t) => t.toLowerCase().contains('budget'));
        case 'grilled':
          return r.tags.any((t) => t.toLowerCase().contains('grill'));
        default:
          return r.cuisine.toLowerCase() == cat ||
              r.tags.any((t) => t.toLowerCase() == cat);
      }
    }).toList();
  }

  // Fetch recipes from Supabase recipes table
  static Future<List<Recipe>> fetchRecipes() async {
    try {
      // Check if Supabase is initialized
      if (!SupabaseService.isInitialized) {
        print('Error: Supabase is not initialized');
        return [];
      }

      final response = await SupabaseService.client
          .from('recipes')
          .select()
          .eq(
            'is_ai_generated',
            false,
          ) // Only fetch authentic recipes, not AI-generated ones
          .order('created_at', ascending: false);

      // Supabase select() returns a List<Map<String, dynamic>>
      final responseList = response as List<dynamic>;
      return responseList
          .map(
            (json) => _mapSupabaseRecipeToRecipe(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error fetching recipes from API: $e');
      return [];
    }
  }

  // Map Supabase recipe format to our Recipe model
  static Recipe _mapSupabaseRecipeToRecipe(Map<String, dynamic> json) {
    // Calculate total time
    final prepTime = json['prep_time'] as int? ?? 0;
    final cookTime = json['cook_time'] as int? ?? 0;
    final totalTime = prepTime + cookTime;
    final timeString = '$totalTime min';

    // Calculate calories from nutrition if available
    int calories = 0;
    if (json['nutrition'] != null && json['nutrition'] is Map) {
      final nutrition = json['nutrition'] as Map<String, dynamic>;
      calories = nutrition['calories'] as int? ?? 0;
    }

    // Parse ingredients
    List<Ingredient> ingredients = [];
    if (json['ingredients'] != null && json['ingredients'] is List) {
      ingredients = (json['ingredients'] as List)
          .map((item) {
            if (item is Map) {
              return Ingredient.fromJson(item as Map<String, dynamic>);
            }
            return null;
          })
          .whereType<Ingredient>()
          .toList();
    }

    // Parse instructions
    List<Instruction> instructions = [];
    if (json['instructions'] != null && json['instructions'] is List) {
      instructions = (json['instructions'] as List)
          .asMap()
          .entries
          .map((entry) {
            final item = entry.value;
            if (item is Map) {
              return Instruction(
                step: entry.key + 1,
                text: item['text'] as String? ?? '',
                timeMinutes: item['timeMinutes'] as int?,
              );
            } else if (item is String) {
              return Instruction(step: entry.key + 1, text: item);
            }
            return null;
          })
          .whereType<Instruction>()
          .toList();
    }

    // Parse nutrition
    Nutrition nutrition = Nutrition(
      calories: calories,
      protein: 0,
      carbs: 0,
      fat: 0,
      fiber: 0,
    );
    if (json['nutrition'] != null && json['nutrition'] is Map) {
      final nutritionData = json['nutrition'] as Map<String, dynamic>;
      nutrition = Nutrition(
        calories: nutritionData['calories'] as int? ?? calories,
        protein: nutritionData['protein'] as int? ?? 0,
        carbs: nutritionData['carbs'] as int? ?? 0,
        fat: nutritionData['fat'] as int? ?? 0,
        fiber: nutritionData['fiber'] as int? ?? 0,
      );
    }

    // Parse tags
    List<String> tags = [];
    if (json['tags'] != null && json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => e.toString()).toList();
    }

    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      image: _normalizeImageUrl(json['image_url'] as String?),
      time: timeString,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: json['servings'] as int? ?? 4,
      calories: calories,
      tags: tags,
      cuisine: json['cuisine'] as String? ?? 'American',
      difficulty: json['difficulty'] as String? ?? 'Easy',
      description: json['description'] as String? ?? '',
      ingredients: ingredients,
      instructions: instructions,
      nutrition: nutrition,
      tips: null,
      slug: json['id'] as String,
    );
  }
}
