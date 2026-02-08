import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/customer_repository.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository());

final customerListProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getCustomers(outletId);
});
