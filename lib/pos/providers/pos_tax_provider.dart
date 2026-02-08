import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/discount.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/pos_discount_repository.dart';

final posDiscountRepositoryProvider = Provider((ref) => PosDiscountRepository());

final posActiveTaxesProvider = FutureProvider<List<Tax>>((ref) async {
  final repo = ref.watch(posDiscountRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getActiveTaxes(outletId);
});
