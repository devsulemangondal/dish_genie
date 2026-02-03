import 'package:flutter/foundation.dart';
import '../data/models/recipe.dart';
import '../data/models/ingredient.dart';
import '../data/models/instruction.dart';
import '../data/models/nutrition.dart';
import '../services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _recipe;
  bool _isLoading = false;
  List<Recipe> _authenticRecipes = [];
  bool _recipesLoaded = false;

  Recipe? get recipe => _recipe;
  bool get isLoading => _isLoading;
  List<Recipe> get authenticRecipes => _authenticRecipes;

  RecipeProvider() {
    _loadAuthenticRecipes();
  }

  Future<void> _loadAuthenticRecipes() async {
    if (_recipesLoaded) return;
    try {
      // Try to fetch recipes from API first
      _authenticRecipes = await RecipeService.fetchRecipes();
      
      // If no recipes from API, fall back to sample recipes
      if (_authenticRecipes.isEmpty) {
        _authenticRecipes = _createSampleRecipes();
      }
      
      _recipesLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading recipes: $e');
      // Fall back to sample recipes on error
      _authenticRecipes = _createSampleRecipes();
      _recipesLoaded = true;
      notifyListeners();
    }
  }

  List<Recipe> _createSampleRecipes() {
    return [
      Recipe(
        id: '1',
        title: 'Hearty Vegetable Soup',
        slug: 'hearty-vegetable-soup',
        description: 'Comforting homemade soup with fresh vegetables and herbs',
        image: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800',
        prepTime: 15,
        cookTime: 25,
        servings: 6,
        difficulty: 'Easy',
        cuisine: 'American',
        calories: 180,
        tags: ['Soup', 'Comfort Food', 'Vegetarian', 'Healthy'],
        time: '40 min',
        ingredients: [
          Ingredient(name: 'Carrots', quantity: '2 cups', unit: 'chopped'),
          Ingredient(name: 'Potatoes', quantity: '2', unit: 'medium'),
          Ingredient(name: 'Onion', quantity: '1', unit: 'large'),
          Ingredient(name: 'Celery', quantity: '2', unit: 'stalks'),
          Ingredient(name: 'Vegetable broth', quantity: '4 cups', unit: ''),
          Ingredient(name: 'Herbs', quantity: '1 tbsp', unit: 'fresh'),
        ],
        instructions: [
          Instruction(step: 1, text: 'Chop all vegetables into bite-sized pieces'),
          Instruction(step: 2, text: 'Heat oil in a large pot and sauté onions until translucent'),
          Instruction(step: 3, text: 'Add carrots, potatoes, and celery. Cook for 5 minutes'),
          Instruction(step: 4, text: 'Pour in vegetable broth and bring to a boil'),
          Instruction(step: 5, text: 'Reduce heat and simmer for 20 minutes until vegetables are tender'),
          Instruction(step: 6, text: 'Season with salt, pepper, and fresh herbs. Serve hot'),
        ],
        nutrition: Nutrition(
          calories: 180,
          protein: 5,
          carbs: 35,
          fat: 3,
          fiber: 6,
        ),
      ),
      Recipe(
        id: '2',
        title: 'Grilled Chicken Breast',
        slug: 'grilled-chicken-breast',
        description: 'Juicy and tender grilled chicken with herbs and spices',
        image: 'https://images.unsplash.com/photo-1528607929212-2636ec44253e?w=800',
        prepTime: 10,
        cookTime: 15,
        servings: 4,
        difficulty: 'Easy',
        cuisine: 'American',
        calories: 250,
        tags: ['Chicken', 'High Protein', 'Quick', 'Grilled'],
        time: '25 min',
        ingredients: [
          Ingredient(name: 'Chicken breast', quantity: '4', unit: 'pieces'),
          Ingredient(name: 'Olive oil', quantity: '2 tbsp', unit: ''),
          Ingredient(name: 'Garlic', quantity: '3', unit: 'cloves'),
          Ingredient(name: 'Lemon', quantity: '1', unit: 'juiced'),
          Ingredient(name: 'Herbs', quantity: '2 tbsp', unit: 'mixed'),
        ],
        instructions: [
          Instruction(step: 1, text: 'Marinate chicken with olive oil, garlic, lemon, and herbs for 30 minutes'),
          Instruction(step: 2, text: 'Preheat grill to medium-high heat'),
          Instruction(step: 3, text: 'Grill chicken for 6-7 minutes per side'),
          Instruction(step: 4, text: 'Let rest for 5 minutes before serving'),
        ],
        nutrition: Nutrition(
          calories: 250,
          protein: 35,
          carbs: 2,
          fat: 10,
          fiber: 0,
        ),
      ),
      Recipe(
        id: '3',
        title: 'Salmon Teriyaki',
        slug: 'salmon-teriyaki',
        description: 'Sweet and savory teriyaki glazed salmon',
        image: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800',
        prepTime: 10,
        cookTime: 12,
        servings: 4,
        difficulty: 'Medium',
        cuisine: 'Japanese',
        calories: 320,
        tags: ['Fish', 'Seafood', 'High Protein', 'Asian'],
        time: '22 min',
        ingredients: [
          Ingredient(name: 'Salmon fillets', quantity: '4', unit: 'pieces'),
          Ingredient(name: 'Soy sauce', quantity: '3 tbsp', unit: ''),
          Ingredient(name: 'Honey', quantity: '2 tbsp', unit: ''),
          Ingredient(name: 'Ginger', quantity: '1 tbsp', unit: 'grated'),
          Ingredient(name: 'Garlic', quantity: '2', unit: 'cloves'),
        ],
        instructions: [
          Instruction(step: 1, text: 'Mix soy sauce, honey, ginger, and garlic for teriyaki sauce'),
          Instruction(step: 2, text: 'Marinate salmon in sauce for 20 minutes'),
          Instruction(step: 3, text: 'Pan-sear salmon skin-side down for 4 minutes'),
          Instruction(step: 4, text: 'Flip and cook for 3 more minutes'),
          Instruction(step: 5, text: 'Brush with remaining sauce and serve'),
        ],
        nutrition: Nutrition(
          calories: 320,
          protein: 28,
          carbs: 15,
          fat: 16,
          fiber: 0,
        ),
      ),
      Recipe(
        id: '4',
        title: 'Mediterranean Quinoa Bowl',
        slug: 'mediterranean-quinoa-bowl',
        description: 'Fresh and healthy quinoa bowl with vegetables and feta',
        image: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
        prepTime: 15,
        cookTime: 20,
        servings: 2,
        difficulty: 'Easy',
        cuisine: 'Mediterranean',
        calories: 380,
        tags: ['Healthy', 'Vegetarian', 'Quinoa', 'Mediterranean'],
        time: '35 min',
        ingredients: [
          Ingredient(name: 'Quinoa', quantity: '1 cup', unit: 'cooked'),
          Ingredient(name: 'Cherry tomatoes', quantity: '1 cup', unit: 'halved'),
          Ingredient(name: 'Cucumber', quantity: '1', unit: 'diced'),
          Ingredient(name: 'Feta cheese', quantity: '1/2 cup', unit: 'crumbled'),
          Ingredient(name: 'Olives', quantity: '1/4 cup', unit: ''),
          Ingredient(name: 'Olive oil', quantity: '2 tbsp', unit: ''),
        ],
        instructions: [
          Instruction(step: 1, text: 'Cook quinoa according to package directions'),
          Instruction(step: 2, text: 'Let quinoa cool to room temperature'),
          Instruction(step: 3, text: 'Mix quinoa with tomatoes, cucumber, and olives'),
          Instruction(step: 4, text: 'Top with feta cheese and drizzle with olive oil'),
        ],
        nutrition: Nutrition(
          calories: 380,
          protein: 14,
          carbs: 45,
          fat: 16,
          fiber: 6,
        ),
      ),
      Recipe(
        id: '5',
        title: 'Chocolate Chip Cookies',
        slug: 'chocolate-chip-cookies',
        description: 'Classic homemade chocolate chip cookies',
        image: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800',
        prepTime: 15,
        cookTime: 12,
        servings: 24,
        difficulty: 'Easy',
        cuisine: 'American',
        calories: 150,
        tags: ['Dessert', 'Sweet', 'Baking', 'Comfort Food'],
        time: '27 min',
        ingredients: [
          Ingredient(name: 'Flour', quantity: '2 1/4 cups', unit: ''),
          Ingredient(name: 'Butter', quantity: '1 cup', unit: 'softened'),
          Ingredient(name: 'Brown sugar', quantity: '3/4 cup', unit: ''),
          Ingredient(name: 'White sugar', quantity: '3/4 cup', unit: ''),
          Ingredient(name: 'Eggs', quantity: '2', unit: 'large'),
          Ingredient(name: 'Chocolate chips', quantity: '2 cups', unit: ''),
        ],
        instructions: [
          Instruction(step: 1, text: 'Preheat oven to 375°F'),
          Instruction(step: 2, text: 'Cream butter and sugars until fluffy'),
          Instruction(step: 3, text: 'Beat in eggs and vanilla'),
          Instruction(step: 4, text: 'Mix in flour and chocolate chips'),
          Instruction(step: 5, text: 'Drop rounded tablespoons onto baking sheet'),
          Instruction(step: 6, text: 'Bake for 9-11 minutes until golden'),
        ],
        nutrition: Nutrition(
          calories: 150,
          protein: 2,
          carbs: 20,
          fat: 7,
          fiber: 1,
        ),
      ),
      Recipe(
        id: '6',
        title: 'Beef Stir Fry',
        slug: 'beef-stir-fry',
        description: 'Quick and flavorful beef stir fry with vegetables',
        image: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800',
        prepTime: 15,
        cookTime: 10,
        servings: 4,
        difficulty: 'Medium',
        cuisine: 'Asian',
        calories: 350,
        tags: ['Beef', 'Quick', 'High Protein', 'Stir Fry'],
        time: '25 min',
        ingredients: [
          Ingredient(name: 'Beef strips', quantity: '1 lb', unit: ''),
          Ingredient(name: 'Bell peppers', quantity: '2', unit: 'sliced'),
          Ingredient(name: 'Broccoli', quantity: '2 cups', unit: 'florets'),
          Ingredient(name: 'Soy sauce', quantity: '3 tbsp', unit: ''),
          Ingredient(name: 'Ginger', quantity: '1 tbsp', unit: 'grated'),
        ],
        instructions: [
          Instruction(step: 1, text: 'Heat oil in a large wok or pan'),
          Instruction(step: 2, text: 'Stir-fry beef until browned, remove and set aside'),
          Instruction(step: 3, text: 'Add vegetables and cook until crisp-tender'),
          Instruction(step: 4, text: 'Return beef to pan with soy sauce and ginger'),
          Instruction(step: 5, text: 'Toss everything together and serve hot'),
        ],
        nutrition: Nutrition(
          calories: 350,
          protein: 30,
          carbs: 12,
          fat: 18,
          fiber: 3,
        ),
      ),
    ];
  }

  Future<Recipe?> generateRecipe({
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
    String? imageBase64, // Support image-based recipe generation
  }) async {
    _isLoading = true;
    _recipe = null;
    notifyListeners();

    try {
      final generated = await RecipeService.generateRecipe(
        ingredients: ingredients,
        cookingTime: cookingTime,
        targetCalories: targetCalories,
        skillLevel: skillLevel,
        servings: servings,
        cuisine: cuisine,
        dietType: dietType,
        healthGoal: healthGoal,
        mood: mood,
        language: language,
        imageBase64: imageBase64, // Pass image if provided
      );

      _recipe = generated;
      _isLoading = false;
      notifyListeners();
      return generated;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void setRecipe(Recipe? recipe) {
    _recipe = recipe;
    notifyListeners();
  }

  Recipe? getRecipeBySlug(String slug) {
    // First check if the current AI-generated recipe matches the slug
    if (_recipe != null) {
      final recipeSlug = _recipe!.slug ?? 
          _recipe!.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      if (recipeSlug == slug || _recipe!.id == slug) {
        return _recipe;
      }
    }
    
    // Then check authentic recipes
    return RecipeService.getRecipeBySlug(slug, _authenticRecipes);
  }

  List<Recipe> searchRecipes(String query) {
    return RecipeService.searchRecipes(_authenticRecipes, query);
  }

  List<Recipe> filterByCategory(String? category) {
    return RecipeService.filterByCategory(_authenticRecipes, category);
  }
}
