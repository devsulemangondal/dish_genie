class Nutrition {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;

  Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        fiber: (json['fiber'] as num?)?.toInt() ?? 0,
      );
}
