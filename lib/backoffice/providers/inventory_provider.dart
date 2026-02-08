import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/inventory_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

final ingredientsProvider = FutureProvider<List<IngredientModel>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getIngredients(_outletId);
});

final stockMovementsProvider =
    FutureProvider<List<StockMovement>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getRecentMovements(_outletId, limit: 50);
});
