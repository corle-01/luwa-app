import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/stock_availability.dart';

class PosStockRepository {
  final _supabase = Supabase.instance.client;

  Future<List<RecipeWithStock>> getAllRecipesWithStock(String outletId) async {
    final response = await _supabase
        .from('recipes')
        .select('product_id, quantity, unit, ingredients(id, name, current_stock, unit)');

    final List<RecipeWithStock> result = [];
    for (final row in response as List) {
      final ingredient = row['ingredients'];
      if (ingredient == null) continue;
      result.add(RecipeWithStock(
        productId: row['product_id'] as String,
        ingredientId: ingredient['id'] as String? ?? '',
        ingredientName: ingredient['name'] as String? ?? '',
        recipeQty: (row['quantity'] as num).toDouble(),
        recipeUnit: row['unit'] as String? ?? '',
        currentStock: (ingredient['current_stock'] as num?)?.toDouble() ?? 0,
        stockUnit: ingredient['unit'] as String? ?? '',
      ));
    }
    return result;
  }

  Map<String, int> calculateAvailability(List<RecipeWithStock> recipes) {
    final byProduct = <String, List<RecipeWithStock>>{};
    for (final r in recipes) {
      byProduct.putIfAbsent(r.productId, () => []).add(r);
    }

    final result = <String, int>{};
    for (final entry in byProduct.entries) {
      int minServings = 999999;
      for (final recipe in entry.value) {
        if (recipe.recipeQty <= 0) continue;
        final servings = (recipe.currentStock / recipe.recipeQty).floor();
        minServings = min(minServings, servings);
      }
      result[entry.key] = minServings == 999999 ? 0 : max(0, minServings);
    }
    return result;
  }

  Future<Map<String, int>> getStockAvailability(String outletId) async {
    try {
      final recipes = await getAllRecipesWithStock(outletId);
      return calculateAvailability(recipes);
    } catch (_) {
      return {};
    }
  }
}
