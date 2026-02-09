import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/purchase.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/purchase_repository.dart';

final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository());

final purchaseListProvider = FutureProvider<List<Purchase>>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getPurchases(outletId);
});

// Stats for current month
final purchaseStatsProvider = FutureProvider<PurchaseStats>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(purchaseRepositoryProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0);
  return repo.getPurchaseStats(outletId, from, to);
});
