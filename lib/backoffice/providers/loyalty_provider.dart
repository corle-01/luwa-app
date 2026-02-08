import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/loyalty_repository.dart';

final loyaltyRepositoryProvider = Provider((ref) => LoyaltyRepository());

final loyaltyProgramsProvider = FutureProvider((ref) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getPrograms(outletId);
});

final loyaltyTransactionsProvider = FutureProvider.family<List<LoyaltyTransaction>, String?>((ref, typeFilter) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTransactions(
    outletId,
    typeFilter: typeFilter,
  );
});
