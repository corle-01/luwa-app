import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/loyalty_repository.dart';

final loyaltyRepositoryProvider = Provider((ref) => LoyaltyRepository());

final loyaltyProgramsProvider = FutureProvider((ref) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  return repo.getPrograms('a0000000-0000-0000-0000-000000000001');
});

final loyaltyTransactionsProvider = FutureProvider.family<List<LoyaltyTransaction>, String?>((ref, typeFilter) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  return repo.getTransactions(
    'a0000000-0000-0000-0000-000000000001',
    typeFilter: typeFilter,
  );
});
