import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/product.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/pos_product_repository.dart';
import '../repositories/pos_stock_repository.dart';
import 'pos_automation_provider.dart';

final posProductRepositoryProvider = Provider((ref) => PosProductRepository());
final posStockRepositoryProvider = Provider((ref) => PosStockRepository());

final posStockAvailabilityProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(posStockRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getStockAvailability(outletId);
});

final posCategoriesProvider = FutureProvider<List<ProductCategory>>((ref) async {
  final repo = ref.watch(posProductRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getCategories(outletId);
});

final posProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(posProductRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  final products = await repo.getProducts(outletId);
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
  final categoriesAsync = ref.watch(posCategoriesProvider);

  return productsAsync.whenData((products) {
    var filtered = products;
    if (selectedCategory != null) {
      // Check if selected category is featured → filter by junction table
      final categories = categoriesAsync.valueOrNull ?? [];
      final isFeatured = categories.any((c) => c.id == selectedCategory && c.isFeatured);

      if (isFeatured) {
        filtered = filtered.where((p) => p.featuredCategoryIds.contains(selectedCategory)).toList();
      } else {
        filtered = filtered.where((p) => p.categoryId == selectedCategory).toList();
      }
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(searchQuery)).toList();
    }
    return filtered;
  });
});
