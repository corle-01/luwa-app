import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/discount_repository.dart';

final discountRepositoryProvider = Provider((ref) => DiscountRepository());

final discountListProvider = FutureProvider<List<DiscountModel>>((ref) async {
  final repo = ref.watch(discountRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getDiscounts(outletId);
});
