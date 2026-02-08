import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/product_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final productRepositoryProvider = Provider((ref) => ProductRepository());

final boProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts(_outletId);
});

final boCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getCategories(_outletId);
});
