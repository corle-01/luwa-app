import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/customer_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final customerRepositoryProvider = Provider((ref) => CustomerRepository());

final customerListProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomers(_outletId);
});
