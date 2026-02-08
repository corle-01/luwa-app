import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kds_repository.dart';
import '../models/kds_order.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final kdsRepositoryProvider = Provider((ref) => KdsRepository());

/// Active kitchen orders - fetched from Supabase.
/// Invalidated every 10 seconds by kdsAutoRefreshProvider.
final kdsOrdersProvider = FutureProvider<List<KdsOrder>>((ref) async {
  final repo = ref.watch(kdsRepositoryProvider);
  return repo.getActiveKitchenOrders(_outletId);
});

/// Auto-refresh timer: invalidates kdsOrdersProvider every 10 seconds
/// so the kitchen display stays up-to-date without manual refresh.
final kdsAutoRefreshProvider = StreamProvider<void>((ref) {
  return Stream.periodic(const Duration(seconds: 10), (_) {
    ref.invalidate(kdsOrdersProvider);
  });
});

/// Count of orders with kitchen_status == 'waiting'
final kdsWaitingCountProvider = Provider<int>((ref) {
  final orders = ref.watch(kdsOrdersProvider);
  return orders.when(
    data: (list) => list.where((o) => o.kitchenStatus == 'waiting').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Count of orders with kitchen_status == 'in_progress'
final kdsInProgressCountProvider = Provider<int>((ref) {
  final orders = ref.watch(kdsOrdersProvider);
  return orders.when(
    data: (list) => list.where((o) => o.kitchenStatus == 'in_progress').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Count of orders with kitchen_status == 'ready'
final kdsReadyCountProvider = Provider<int>((ref) {
  final orders = ref.watch(kdsOrdersProvider);
  return orders.when(
    data: (list) => list.where((o) => o.kitchenStatus == 'ready').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Total active orders (waiting + in_progress + ready, not served)
final kdsTotalActiveCountProvider = Provider<int>((ref) {
  final orders = ref.watch(kdsOrdersProvider);
  return orders.when(
    data: (list) => list.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Count of overdue orders (elapsed > 15 minutes)
final kdsOverdueCountProvider = Provider<int>((ref) {
  final orders = ref.watch(kdsOrdersProvider);
  return orders.when(
    data: (list) => list.where((o) => o.isOverdue).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
