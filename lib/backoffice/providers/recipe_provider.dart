import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/recipe_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final recipeRepositoryProvider = Provider((ref) => RecipeRepository());

final productsWithRecipesProvider =
    FutureProvider<List<ProductWithRecipes>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.getProductsWithRecipes(_outletId);
});

final ingredientListForRecipeProvider =
    FutureProvider<List<IngredientOption>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.getIngredients(_outletId);
});
