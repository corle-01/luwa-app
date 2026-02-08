import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

final ingredientsProvider = FutureProvider<List<IngredientModel>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getIngredients(outletId);
});

final stockMovementsProvider =
    FutureProvider<List<StockMovement>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getRecentMovements(outletId, limit: 50);
});
