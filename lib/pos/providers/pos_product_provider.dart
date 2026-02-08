import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/product.dart';
import '../repositories/pos_product_repository.dart';
import '../repositories/pos_stock_repository.dart';
import 'pos_automation_provider.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final posProductRepositoryProvider = Provider((ref) => PosProductRepository());
final posStockRepositoryProvider = Provider((ref) => PosStockRepository());

final posStockAvailabilityProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(posStockRepositoryProvider);
  return repo.getStockAvailability(_outletId);
});

final posCategoriesProvider = FutureProvider<List<ProductCategory>>((ref) async {
  final repo = ref.watch(posProductRepositoryProvider);
  return repo.getCategories(_outletId);
});

final posProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(posProductRepositoryProvider);
  final products = await repo.getProducts(_outletId);
  final isAuto = ref.watch(posAutomationProvider);

  if (isAuto) {
    try {
      final stockMap = await ref.watch(posStockAvailabilityProvider.future);
      for (final p in products) {
        p.calculatedAvailableQty = stockMap[p.id] ?? 0;
      }
    } catch (_) {
      // Stock calculation failed, show products without stock info
    }
  }
  return products;
});

final posSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final posSearchQueryProvider = StateProvider<String>((ref) => '');

final posFilteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(posProductsProvider);
  final selectedCategory = ref.watch(posSelectedCategoryProvider);
  final searchQuery = ref.watch(posSearchQueryProvider).toLowerCase();

  return productsAsync.whenData((products) {
    var filtered = products;
    if (selectedCategory != null) {
      filtered = filtered.where((p) => p.categoryId == selectedCategory).toList();
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(searchQuery)).toList();
    }
    return filtered;
  });
});
