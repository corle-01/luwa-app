import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/discount.dart';
import '../repositories/pos_discount_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final posDiscountRepositoryProvider = Provider((ref) => PosDiscountRepository());

final posActiveTaxesProvider = FutureProvider<List<Tax>>((ref) async {
  final repo = ref.watch(posDiscountRepositoryProvider);
  return repo.getActiveTaxes(_outletId);
});
