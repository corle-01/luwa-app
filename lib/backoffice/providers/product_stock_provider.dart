import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/product_stock_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final productStockRepositoryProvider =
    Provider((ref) => ProductStockRepository());

final productStockListProvider =
    FutureProvider<List<ProductStockModel>>((ref) async {
  final repo = ref.watch(productStockRepositoryProvider);
  return repo.getProductStock(_outletId);
});

final productStockMovementsProvider =
    FutureProvider.family<List<ProductStockMovement>, String?>(
        (ref, productId) async {
  final repo = ref.watch(productStockRepositoryProvider);
  return repo.getStockMovements(_outletId, productId: productId, limit: 50);
});

/// All movements (no product filter) for the "Riwayat" tab.
final allProductStockMovementsProvider =
    FutureProvider<List<ProductStockMovement>>((ref) async {
  final repo = ref.watch(productStockRepositoryProvider);
  return repo.getStockMovements(_outletId, limit: 50);
});
