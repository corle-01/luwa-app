import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order.dart';
import '../../core/providers/outlet_provider.dart';
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

// --- Order Filter System ---

class OrderFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? paymentMethod;
  final String? searchQuery;

  OrderFilter({
    this.startDate,
    this.endDate,
    this.status,
    this.paymentMethod,
    this.searchQuery,
  });

  OrderFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? paymentMethod,
    String? searchQuery,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearStatus = false,
    bool clearPaymentMethod = false,
    bool clearSearch = false,
  }) {
    return OrderFilter(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: clearStatus ? null : (status ?? this.status),
      paymentMethod: clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }

  bool get hasFilters =>
      startDate != null ||
      endDate != null ||
      status != null ||
      paymentMethod != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);
}

final posOrderFilterProvider = StateProvider<OrderFilter>((ref) => OrderFilter());

final posFilteredOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final filter = ref.watch(posOrderFilterProvider);
  final repo = ref.watch(posOrderRepositoryProvider);

  // Default to today if no date filter
  final now = DateTime.now();
  final startDate = filter.startDate ?? DateTime(now.year, now.month, now.day);
  final endDate = filter.endDate;

  final outletId = ref.watch(currentOutletIdProvider);

  return repo.getOrders(
    outletId: outletId,
    startDate: startDate,
    endDate: endDate,
    status: filter.status,
    paymentMethod: filter.paymentMethod,
    searchQuery: filter.searchQuery,
  );
});

final posFilteredOrderCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(posFilteredOrdersProvider);
  return ordersAsync.when(data: (o) => o.length, loading: () => 0, error: (_, _) => 0);
});

final posFilteredSalesProvider = Provider<double>((ref) {
  final ordersAsync = ref.watch(posFilteredOrdersProvider);
  return ordersAsync.when(
    data: (orders) => orders
        .where((o) => o.status == 'completed')
        .fold(0.0, (sum, o) => sum + o.totalAmount),
    loading: () => 0,
    error: (_, _) => 0,
  );
});
