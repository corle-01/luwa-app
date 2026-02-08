class RecipeWithStock {
  final String productId;
  final String ingredientId;
  final String ingredientName;
  final double recipeQty;
  final String recipeUnit;
  final double currentStock;
  final String stockUnit;

  RecipeWithStock({
    required this.productId,
    required this.ingredientId,
    required this.ingredientName,
    required this.recipeQty,
    required this.recipeUnit,
    required this.currentStock,
    required this.stockUnit,
  });

  factory RecipeWithStock.fromJson(Map<String, dynamic> json) {
    final ingredient = json['ingredients'] as Map<String, dynamic>?;
    return RecipeWithStock(
      productId: json['product_id'] as String,
      ingredientId: ingredient?['id'] as String? ?? json['ingredient_id'] as String? ?? '',
      ingredientName: ingredient?['name'] as String? ?? '',
      recipeQty: (json['quantity'] as num?)?.toDouble() ?? 0,
      recipeUnit: json['unit'] as String? ?? '',
      currentStock: (ingredient?['current_stock'] as num?)?.toDouble() ?? 0,
      stockUnit: ingredient?['unit'] as String? ?? '',
    );
  }
}

class StockAvailabilityMap {
  final Map<String, int> availability;
  final DateTime calculatedAt;
  final bool isAutoMode;

  StockAvailabilityMap({
    required this.availability,
    required this.calculatedAt,
    required this.isAutoMode,
  });
}
