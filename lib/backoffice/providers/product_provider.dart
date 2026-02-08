import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/product_repository.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository());

final boProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getProducts(outletId);
});

final boCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getCategories(outletId);
});
