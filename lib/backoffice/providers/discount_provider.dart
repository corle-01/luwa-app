import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/discount_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final discountRepositoryProvider = Provider((ref) => DiscountRepository());

final discountListProvider = FutureProvider<List<DiscountModel>>((ref) async {
  final repo = ref.watch(discountRepositoryProvider);
  return repo.getDiscounts(_outletId);
});
