class GroceryItem {
  final String id;
  final String name;
  final String quantity;
  final String unit;
  final String category;
  final String? estimatedPrice;
  final String? notes;
  final bool checked;
  final bool? inPantry;

  GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.estimatedPrice,
    this.notes,
    required this.checked,
    this.inPantry,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        if (estimatedPrice != null) 'estimated_price': estimatedPrice,
        if (notes != null) 'notes': notes,
        'checked': checked,
        if (inPantry != null) 'inPantry': inPantry,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as String,
        unit: json['unit'] as String,
        category: json['category'] as String,
        estimatedPrice: json['estimated_price'] as String?,
        notes: json['notes'] as String?,
        checked: json['checked'] as bool? ?? false,
        inPantry: json['inPantry'] as bool?,
      );

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? unit,
    String? category,
    String? estimatedPrice,
    String? notes,
    bool? checked,
    bool? inPantry,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      notes: notes ?? this.notes,
      checked: checked ?? this.checked,
      inPantry: inPantry ?? this.inPantry,
    );
  }
}
