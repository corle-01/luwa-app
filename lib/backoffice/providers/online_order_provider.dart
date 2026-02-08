import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/online_order_repository.dart';

// ============================================================
// Repository provider
// ============================================================
final onlineOrderRepositoryProvider = Provider<OnlineOrderRepository>((ref) {
  return OnlineOrderRepository();
});

// ============================================================
// Platform Configs provider
// ============================================================
final platformConfigsProvider =
    FutureProvider<List<PlatformConfig>>((ref) async {
  final repo = ref.watch(onlineOrderRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getPlatformConfigs(outletId);
});

// ============================================================
// Online Order Filter provider
// ============================================================
final onlineOrderFilterProvider =
    StateProvider<OnlineOrderFilter>((ref) => const OnlineOrderFilter());

// ============================================================
// Online Orders provider — today's orders, auto-refresh every 15s
// ============================================================
final onlineOrdersProvider =
    FutureProvider<List<OnlineOrder>>((ref) async {
  final repo = ref.watch(onlineOrderRepositoryProvider);
  final filter = ref.watch(onlineOrderFilterProvider);
  final outletId = ref.watch(currentOutletIdProvider);

  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);

  final orders = await repo.getOnlineOrders(
    outletId: outletId,
    platform: filter.platform,
    status: filter.status,
    dateFrom: startOfDay,
  );

  // Auto-refresh: invalidate self after 15 seconds so new incoming
  // orders are picked up without manual pull-to-refresh.
  final timer = Timer(const Duration(seconds: 15), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return orders;
});

// ============================================================
// Online Order Detail provider (by orderId)
// ============================================================
final onlineOrderDetailProvider =
    FutureProvider.family<OnlineOrder?, String>((ref, orderId) async {
  final repo = ref.watch(onlineOrderRepositoryProvider);
  return repo.getOnlineOrderDetail(orderId);
});

// ============================================================
// Online Order Stats provider — today's stats
// ============================================================
final onlineOrderStatsProvider =
    FutureProvider<OnlineOrderStats>((ref) async {
  final repo = ref.watch(onlineOrderRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);

  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);

  return repo.getOnlineOrderStats(outletId, startOfDay, today);
});

// ============================================================
// Incoming Order Count provider
// Derived from onlineOrdersProvider — counts orders with status='incoming'
// ============================================================
final incomingOrderCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(onlineOrdersProvider);

  return ordersAsync.when(
    data: (orders) =>
        orders.where((o) => o.status == 'incoming').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
