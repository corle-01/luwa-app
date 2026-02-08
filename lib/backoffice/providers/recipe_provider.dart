import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/recipe_repository.dart';

final recipeRepositoryProvider = Provider((ref) => RecipeRepository());

final productsWithRecipesProvider =
    FutureProvider<List<ProductWithRecipes>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getProductsWithRecipes(outletId);
});

final ingredientListForRecipeProvider =
    FutureProvider<List<IngredientOption>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getIngredients(outletId);
});
