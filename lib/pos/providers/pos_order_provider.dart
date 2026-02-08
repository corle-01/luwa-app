import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order.dart';
import 'pos_checkout_provider.dart';

final posOrdersByStatusProvider = Provider.family<List<Order>, String?>((ref, status) {
  final ordersAsync = ref.watch(posTodayOrdersProvider);
  return ordersAsync.when(
    data: (orders) {
      if (status == null) return orders;
      return orders.where((o) => o.status == status).toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

final posOrderCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(posTodayOrdersProvider);
  return ordersAsync.when(data: (o) => o.length, loading: () => 0, error: (_, _) => 0);
});

final posTodaySalesProvider = Provider<double>((ref) {
  final ordersAsync = ref.watch(posTodayOrdersProvider);
  return ordersAsync.when(
    data: (orders) => orders
        .where((o) => o.status == 'completed')
        .fold(0.0, (sum, o) => sum + o.totalAmount),
    loading: () => 0,
    error: (_, _) => 0,
  );
});
