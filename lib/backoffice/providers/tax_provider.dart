import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/tax_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final taxRepositoryProvider = Provider((ref) => TaxRepository());

final taxListProvider = FutureProvider<List<TaxModel>>((ref) async {
  final repo = ref.watch(taxRepositoryProvider);
  return repo.getTaxes(_outletId);
});
