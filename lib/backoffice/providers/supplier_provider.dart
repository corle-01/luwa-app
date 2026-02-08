import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/supplier_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final supplierRepositoryProvider = Provider((ref) => SupplierRepository());

final supplierListProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSuppliers(_outletId);
});
