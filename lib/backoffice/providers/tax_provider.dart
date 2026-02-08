import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/tax_repository.dart';

final taxRepositoryProvider = Provider((ref) => TaxRepository());

final taxListProvider = FutureProvider<List<TaxModel>>((ref) async {
  final repo = ref.watch(taxRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTaxes(outletId);
});
