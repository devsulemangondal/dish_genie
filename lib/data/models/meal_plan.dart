class MealPlanMeal {
  final String id;
  final String recipeId;
  final String recipeTitle;
  final String? recipeImage;
  final String? description;
  final String mealType; // breakfast, lunch, dinner, snack
  final DateTime date;
  final int? servings;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final int? prepTime; // in minutes

  MealPlanMeal({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    this.recipeImage,
    this.description,
    required this.mealType,
    required this.date,
    this.servings,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.prepTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'recipe_title': recipeTitle,
        if (recipeImage != null) 'recipe_image': recipeImage,
        if (description != null) 'description': description,
        'meal_type': mealType,
        'date': date.toIso8601String(),
        if (servings != null) 'servings': servings,
        if (calories != null) 'calories': calories,
        if (protein != null) 'protein': protein,
        if (carbs != null) 'carbs': carbs,
        if (fat != null) 'fat': fat,
        if (prepTime != null) 'prep_time': prepTime,
      };

  factory MealPlanMeal.fromJson(Map<String, dynamic> json) => MealPlanMeal(
        id: json['id'] as String,
        recipeId: json['recipe_id'] as String,
        recipeTitle: json['recipe_title'] as String,
        recipeImage: json['recipe_image'] as String?,
        description: json['description'] as String?,
        mealType: json['meal_type'] as String,
        date: DateTime.parse(json['date'] as String),
        servings: json['servings'] as int?,
        calories: json['calories'] as int?,
        protein: json['protein'] as int?,
        carbs: json['carbs'] as int?,
        fat: json['fat'] as int?,
        prepTime: json['prep_time'] as int?,
      );
}

class MealPlan {
  final String id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyCalories;
  final List<MealPlanMeal> meals;
  final Map<String, int>? macros;
  final List<String>? mealPrepTips;
  final String? budget;
  final String? skillLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MealPlan({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.dailyCalories,
    required this.meals,
    this.macros,
    this.mealPrepTips,
    this.budget,
    this.skillLevel,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'daily_calories': dailyCalories,
        'meals': meals.map((e) => e.toJson()).toList(),
        if (macros != null) 'macros': macros,
        if (mealPrepTips != null) 'meal_prep_tips': mealPrepTips,
        if (budget != null) 'budget': budget,
        if (skillLevel != null) 'skill_level': skillLevel,
        if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
      };

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        dailyCalories: json['daily_calories'] as int,
        meals: (json['meals'] as List<dynamic>)
            .map((e) => MealPlanMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
        macros: json['macros'] != null
            ? Map<String, int>.from(json['macros'] as Map<String, dynamic>)
            : null,
        mealPrepTips: json['meal_prep_tips'] != null
            ? (json['meal_prep_tips'] as List<dynamic>).map((e) => e.toString()).toList()
            : (json['mealPrepTips'] != null
                ? (json['mealPrepTips'] as List<dynamic>).map((e) => e.toString()).toList()
                : null),
        budget: json['budget'] as String?,
        skillLevel: json['skill_level'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  MealPlan copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? dailyCalories,
    List<MealPlanMeal>? meals,
    Map<String, int>? macros,
    List<String>? mealPrepTips,
    String? budget,
    String? skillLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      meals: meals ?? this.meals,
      macros: macros ?? this.macros,
      mealPrepTips: mealPrepTips ?? this.mealPrepTips,
      budget: budget ?? this.budget,
      skillLevel: skillLevel ?? this.skillLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
