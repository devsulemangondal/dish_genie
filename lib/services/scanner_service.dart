import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../data/models/recipe.dart';
import 'supabase_service.dart';

class DetectedIngredient {
  final String name;
  final String quantity;
  final String category;
  final String freshness;
  final double confidence;

  DetectedIngredient({
    required this.name,
    required this.quantity,
    required this.category,
    required this.freshness,
    required this.confidence,
  });

  factory DetectedIngredient.fromJson(Map<String, dynamic> json) {
    return DetectedIngredient(
      name: json['name'] as String,
      quantity: json['quantity'] as String? ?? '1',
      category: json['category'] as String? ?? 'other',
      freshness: json['freshness'] as String? ?? 'good',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'category': category,
    'freshness': freshness,
    'confidence': confidence,
  };
}

class ScanResult {
  final List<DetectedIngredient> ingredients;
  final List<Recipe> recipes;
  final int totalIngredientsDetected;
  final int totalRecipesGenerated;

  ScanResult({
    required this.ingredients,
    required this.recipes,
    required this.totalIngredientsDetected,
    required this.totalRecipesGenerated,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    // Parse recipes - handle both formats (web returns instructions as List<String>)
    List<Recipe> parsedRecipes = [];
    if (json['recipes'] != null) {
      final recipesList = json['recipes'] as List<dynamic>;
      for (var recipeData in recipesList) {
        final recipeMap = recipeData as Map<String, dynamic>;

        // Convert instructions from List<String> to List<Instruction>
        List<dynamic> instructionsList = [];
        if (recipeMap['instructions'] is List) {
          instructionsList = recipeMap['instructions'] as List;
        }

        final instructions = instructionsList.asMap().entries.map((entry) {
          final index = entry.key;
          final instructionData = entry.value;
          if (instructionData is String) {
            return {'step': index + 1, 'text': instructionData};
          }
          return instructionData;
        }).toList();

        // Convert ingredients - handle both formats
        List<dynamic> ingredientsList = [];
        if (recipeMap['ingredients'] is List) {
          ingredientsList = recipeMap['ingredients'] as List;
        }

        final ingredients = ingredientsList.map((ing) {
          if (ing is Map) {
            // Already in correct format
            return ing;
          }
          // Fallback
          return {'name': ing.toString(), 'quantity': '1', 'unit': ''};
        }).toList();

        // Build recipe with converted data
        final convertedRecipe = Map<String, dynamic>.from(recipeMap);
        convertedRecipe['instructions'] = instructions;
        convertedRecipe['ingredients'] = ingredients;

        // Ensure all required fields
        convertedRecipe['id'] =
            convertedRecipe['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString();
        convertedRecipe['title'] =
            convertedRecipe['name'] ?? convertedRecipe['title'] ?? 'Recipe';
        convertedRecipe['time'] = '${convertedRecipe['cookingTime'] ?? 30} min';
        convertedRecipe['prepTime'] = 10;
        convertedRecipe['cookTime'] = convertedRecipe['cookingTime'] ?? 30;
        convertedRecipe['servings'] = convertedRecipe['servings'] ?? 2;
        convertedRecipe['cuisine'] =
            convertedRecipe['cuisine'] ?? 'International';
        convertedRecipe['difficulty'] =
            convertedRecipe['difficulty'] ?? 'Medium';
        convertedRecipe['description'] = convertedRecipe['description'] ?? '';
        convertedRecipe['tags'] = convertedRecipe['tags'] ?? [];

        // Nutrition
        final nutritionData = convertedRecipe['nutrition'];
        if (nutritionData != null && nutritionData is Map) {
          convertedRecipe['nutrition'] = nutritionData;
        } else {
          convertedRecipe['nutrition'] = {
            'calories': convertedRecipe['calories'] ?? 400,
            'protein': 20,
            'carbs': 40,
            'fat': 15,
            'fiber': 5,
          };
        }

        // Calories
        if (nutritionData != null && nutritionData is Map) {
          convertedRecipe['calories'] =
              (nutritionData['calories'] as num?)?.toInt() ?? 400;
        }

        try {
          parsedRecipes.add(Recipe.fromJson(convertedRecipe));
        } catch (e) {
          print('Error parsing recipe: $e');
        }
      }
    }

    return ScanResult(
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map(
                (e) => DetectedIngredient.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      recipes: parsedRecipes,
      totalIngredientsDetected:
          json['totalIngredientsDetected'] as int? ??
          (json['ingredients'] as List?)?.length ??
          0,
      totalRecipesGenerated:
          json['totalRecipesGenerated'] as int? ?? parsedRecipes.length,
    );
  }
}

class ScannerService {
  static Future<ScanResult?> analyzeImage({
    required String imageBase64,
    String? dietType,
    List<String>? allergies,
    int? calorieTarget,
    String? cookingSkill,
    int? cookingTime,
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
      final functionUrl = '$supabaseUrl/functions/v1/analyze-ingredients';

      final httpResponse = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey, // Required by Supabase Edge Functions
        },
        body: json.encode({
          'imageBase64': imageBase64,
          if (dietType != null) 'dietType': dietType,
          if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
          if (calorieTarget != null) 'calorieTarget': calorieTarget,
          if (cookingSkill != null) 'cookingSkill': cookingSkill,
          if (cookingTime != null) 'cookingTime': cookingTime,
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
      if (data['success'] == true) {
        return ScanResult.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error analyzing image: $e');
      return null;
    }
  }

  static String? imageToBase64(Uint8List imageBytes) {
    try {
      return base64Encode(imageBytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }
}
