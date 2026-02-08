import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/supplier_repository.dart';

final supplierRepositoryProvider = Provider((ref) => SupplierRepository());

final supplierListProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getSuppliers(outletId);
});
