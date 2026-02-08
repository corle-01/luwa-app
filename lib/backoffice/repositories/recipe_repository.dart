import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeItem {
  final String id;
  final String productId;
  final String productName;
  final String ingredientId;
  final String ingredientName;
  final String ingredientUnit;
  final double quantity;
  final String unit;
  final String? notes;
  final double costPerUnit;

  RecipeItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientUnit,
    required this.quantity,
    required this.unit,
    this.notes,
    required this.costPerUnit,
  });

  double get totalCost => quantity * costPerUnit;

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>? ?? {};
    final ingredient = json['ingredients'] as Map<String, dynamic>? ?? {};

    return RecipeItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: product['name'] as String? ?? '',
      ingredientId: json['ingredient_id'] as String,
      ingredientName: ingredient['name'] as String? ?? '',
      ingredientUnit: ingredient['unit'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'gram',
      notes: json['notes'] as String?,
      costPerUnit: (ingredient['cost_per_unit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProductWithRecipes {
  final String productId;
  final String productName;
  final double sellingPrice;
  final List<RecipeItem> recipes;

  ProductWithRecipes({
    required this.productId,
    required this.productName,
    required this.sellingPrice,
    required this.recipes,
  });

  double get totalCost =>
      recipes.fold(0.0, (sum, item) => sum + item.totalCost);

  double get marginAmount => sellingPrice - totalCost;

  double get marginPercent =>
      sellingPrice > 0 ? (marginAmount / sellingPrice) * 100 : 0;
}

class IngredientOption {
  final String id;
  final String name;
  final String unit;
  final double costPerUnit;

  IngredientOption({
    required this.id,
    required this.name,
    required this.unit,
    required this.costPerUnit,
  });

  factory IngredientOption.fromJson(Map<String, dynamic> json) {
    return IngredientOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      costPerUnit: (json['cost_per_unit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RecipeRepository {
  final _supabase = Supabase.instance.client;

  /// Get all products with their recipes (join products + recipes + ingredients)
  Future<List<ProductWithRecipes>> getProductsWithRecipes(
      String outletId) async {
    // 1. Get all active products for this outlet
    final productsResponse = await _supabase
        .from('products')
        .select('id, name, selling_price')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name', ascending: true);

    // 2. Get all recipes with ingredient details for those products
    final productIds =
        (productsResponse as List).map((p) => p['id'] as String).toList();

    if (productIds.isEmpty) return [];

    final recipesResponse = await _supabase
        .from('recipes')
        .select(
            'id, product_id, ingredient_id, quantity, unit, notes, products(name), ingredients(name, unit, cost_per_unit)')
        .inFilter('product_id', productIds)
        .order('created_at', ascending: true);

    // 3. Group recipes by product
    final recipesByProduct = <String, List<RecipeItem>>{};
    for (final json in recipesResponse as List) {
      final item = RecipeItem.fromJson(json);
      recipesByProduct.putIfAbsent(item.productId, () => []).add(item);
    }

    // 4. Build ProductWithRecipes list
    return (productsResponse as List).map((p) {
      final productId = p['id'] as String;
      return ProductWithRecipes(
        productId: productId,
        productName: p['name'] as String? ?? '',
        sellingPrice: (p['selling_price'] as num?)?.toDouble() ?? 0,
        recipes: recipesByProduct[productId] ?? [],
      );
    }).toList();
  }

  /// Get recipes for a specific product
  Future<List<RecipeItem>> getRecipesForProduct(String productId) async {
    final response = await _supabase
        .from('recipes')
        .select(
            'id, product_id, ingredient_id, quantity, unit, notes, products(name), ingredients(name, unit, cost_per_unit)')
        .eq('product_id', productId)
        .order('created_at', ascending: true);

    return (response as List).map((json) => RecipeItem.fromJson(json)).toList();
  }

  /// List available ingredients for dropdown
  Future<List<IngredientOption>> getIngredients(String outletId) async {
    final response = await _supabase
        .from('ingredients')
        .select('id, name, unit, cost_per_unit')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => IngredientOption.fromJson(json))
        .toList();
  }

  /// Add ingredient to recipe
  Future<void> addRecipeItem({
    required String productId,
    required String ingredientId,
    required double quantity,
    required String unit,
    String? notes,
  }) async {
    await _supabase.from('recipes').insert({
      'product_id': productId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
    });
  }

  /// Update recipe item
  Future<void> updateRecipeItem({
    required String id,
    required double quantity,
    required String unit,
    String? notes,
  }) async {
    await _supabase.from('recipes').update({
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Delete recipe item
  Future<void> deleteRecipeItem(String id) async {
    await _supabase.from('recipes').delete().eq('id', id);
  }
}
