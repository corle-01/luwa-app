import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/product_stock_repository.dart';

final productStockRepositoryProvider =
    Provider((ref) => ProductStockRepository());

final productStockListProvider =
    FutureProvider<List<ProductStockModel>>((ref) async {
  final repo = ref.watch(productStockRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getProductStock(outletId);
});

final productStockMovementsProvider =
    FutureProvider.family<List<ProductStockMovement>, String?>(
        (ref, productId) async {
  final repo = ref.watch(productStockRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getStockMovements(outletId, productId: productId, limit: 50);
});

/// All movements (no product filter) for the "Riwayat" tab.
final allProductStockMovementsProvider =
    FutureProvider<List<ProductStockMovement>>((ref) async {
  final repo = ref.watch(productStockRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getStockMovements(outletId, limit: 50);
});
