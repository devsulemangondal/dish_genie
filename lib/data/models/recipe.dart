import 'ingredient.dart';
import 'instruction.dart';
import 'nutrition.dart';

class Recipe {
  final String id;
  final String title;
  final String image;
  final String time;
  final int prepTime;
  final int cookTime;
  final int servings;
  final int calories;
  final List<String> tags;
  final String cuisine;
  final String difficulty;
  final String description;
  final List<Ingredient> ingredients;
  final List<Instruction> instructions;
  final Nutrition nutrition;
  final String? tips;
  final String? slug;

  Recipe({
    required this.id,
    required this.title,
    required this.image,
    required this.time,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.calories,
    required this.tags,
    required this.cuisine,
    required this.difficulty,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.nutrition,
    this.tips,
    String? slug,
  }) : slug = slug ?? id;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image,
        'time': time,
        'prepTime': prepTime,
        'cookTime': cookTime,
        'servings': servings,
        'calories': calories,
        'tags': tags,
        'cuisine': cuisine,
        'difficulty': difficulty,
        'description': description,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'instructions': instructions.map((e) => e.toJson()).toList(),
        'nutrition': nutrition.toJson(),
        if (tips != null) 'tips': tips,
        if (slug != null) 'slug': slug,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase and snake_case field names (API may return either)
    final prepTime = (json['prepTime'] ?? json['prep_time'] ?? 0) as int;
    final cookTime = (json['cookTime'] ?? json['cook_time'] ?? 0) as int;
    final totalTime = prepTime + cookTime;
    
    // Calculate time string if not provided
    final timeString = json['time'] as String? ?? '$totalTime min';
    
    // Generate ID if not provided
    final id = json['id'] as String? ?? 
        DateTime.now().millisecondsSinceEpoch.toString();
    
    // Handle image - may be null or empty
    final image = json['image'] as String? ?? 
        json['image_url'] as String? ?? 
        '';
    
    // Handle tags - may be null or empty list
    final tagsList = json['tags'];
    final tags = tagsList is List
        ? tagsList.map((e) => e.toString()).toList()
        : <String>[];
    
    // Handle ingredients - may be null or empty list
    final ingredientsList = json['ingredients'];
    final ingredients = ingredientsList is List
        ? ingredientsList
            .map((e) {
              try {
                if (e is Map) {
                  return Ingredient.fromJson(e as Map<String, dynamic>);
                } else if (e is String) {
                  return Ingredient(name: e, quantity: '1', unit: '');
                }
                return Ingredient(name: e.toString(), quantity: '1', unit: '');
              } catch (err) {
                // Fallback for parsing errors
                return Ingredient(name: 'Unknown', quantity: '1', unit: '');
              }
            })
            .toList()
        : <Ingredient>[];
    
    // Handle instructions - may be null or empty list, and may be List<String> or List<Map>
    final instructionsList = json['instructions'];
    final instructions = instructionsList is List
        ? instructionsList.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            if (item is Map) {
              try {
                return Instruction.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                return Instruction(
                  step: index + 1,
                  text: item['text']?.toString() ?? item.toString(),
                );
              }
            } else if (item is String) {
              return Instruction(step: index + 1, text: item);
            }
            return Instruction(step: index + 1, text: item.toString());
          }).toList()
        : <Instruction>[];
    
    // Handle nutrition - may be null
    Nutrition nutrition;
    if (json['nutrition'] != null && json['nutrition'] is Map) {
      try {
        nutrition = Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>);
      } catch (e) {
        // Fallback nutrition
        final calories = (json['calories'] as num?)?.toInt() ?? 400;
        nutrition = Nutrition(
          calories: calories,
          protein: 20,
          carbs: 40,
          fat: 15,
          fiber: 5,
        );
      }
    } else {
      // Fallback nutrition from calories if available
      final calories = (json['calories'] as num?)?.toInt() ?? 400;
      nutrition = Nutrition(
        calories: calories,
        protein: 20,
        carbs: 40,
        fat: 15,
        fiber: 5,
      );
    }
    
    // Generate slug from title if not provided
    final title = json['title'] as String? ?? json['name'] as String? ?? 'Recipe';
    final slug = json['slug'] as String? ?? 
        (title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '').isNotEmpty
            ? title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')
            : id);
    
    return Recipe(
      id: id,
      title: title,
      image: image,
      time: timeString,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      calories: nutrition.calories,
      tags: tags,
      cuisine: json['cuisine'] as String? ?? 'International',
      difficulty: json['difficulty'] as String? ?? 
          json['skillLevel'] as String? ?? 
          'Medium',
      description: json['description'] as String? ?? '',
      ingredients: ingredients,
      instructions: instructions,
      nutrition: nutrition,
      tips: json['tips'] as String?,
      slug: slug,
    );
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? image,
    String? time,
    int? prepTime,
    int? cookTime,
    int? servings,
    int? calories,
    List<String>? tags,
    String? cuisine,
    String? difficulty,
    String? description,
    List<Ingredient>? ingredients,
    List<Instruction>? instructions,
    Nutrition? nutrition,
    String? tips,
    String? slug,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      image: image ?? this.image,
      time: time ?? this.time,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      tags: tags ?? this.tags,
      cuisine: cuisine ?? this.cuisine,
      difficulty: difficulty ?? this.difficulty,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      nutrition: nutrition ?? this.nutrition,
      tips: tips ?? this.tips,
      slug: slug ?? this.slug,
    );
  }
}
