import 'grocery_item.dart';

class GroceryList {
  final String name;
  final String estimatedCost;
  final List<GroceryItem> items;
  final Map<String, int> categoriesSummary;
  final List<String> budgetTips;
  final List<String> mealPrepOrder;
  final String? id;
  final DateTime? createdAt;

  GroceryList({
    required this.name,
    required this.estimatedCost,
    required this.items,
    required this.categoriesSummary,
    required this.budgetTips,
    required this.mealPrepOrder,
    this.id,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_cost': estimatedCost,
        'items': items.map((e) => e.toJson()).toList(),
        'categories_summary': categoriesSummary,
        'budget_tips': budgetTips,
        'meal_prep_order': mealPrepOrder,
        if (id != null) 'id': id,
        if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      };

  factory GroceryList.fromJson(Map<String, dynamic> json) => GroceryList(
        name: json['name'] as String,
        estimatedCost: json['estimated_cost'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => GroceryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        categoriesSummary: Map<String, int>.from(
          json['categories_summary'] as Map<String, dynamic>,
        ),
        budgetTips: (json['budget_tips'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        mealPrepOrder: (json['meal_prep_order'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        id: json['id'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  GroceryList copyWith({
    String? name,
    String? estimatedCost,
    List<GroceryItem>? items,
    Map<String, int>? categoriesSummary,
    List<String>? budgetTips,
    List<String>? mealPrepOrder,
    String? id,
    DateTime? createdAt,
  }) {
    return GroceryList(
      name: name ?? this.name,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      items: items ?? this.items,
      categoriesSummary: categoriesSummary ?? this.categoriesSummary,
      budgetTips: budgetTips ?? this.budgetTips,
      mealPrepOrder: mealPrepOrder ?? this.mealPrepOrder,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
