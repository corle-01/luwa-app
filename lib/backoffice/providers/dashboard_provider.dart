import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/order.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

// ─────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────

class DashboardStats {
  final double todaySales;
  final int todayOrders;
  final int activeProducts;
  final int lowStockCount;

  const DashboardStats({
    required this.todaySales,
    required this.todayOrders,
    required this.activeProducts,
    required this.lowStockCount,
  });
}

// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────

class DashboardRepository {
  final _supabase = Supabase.instance.client;

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// SUM(total) FROM orders WHERE status='completed' AND created_at >= today
  Future<double> getTodaySales(String outletId) async {
    final response = await _supabase
        .from('orders')
        .select('total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', _startOfToday.toIso8601String());

    final rows = response as List;
    double total = 0;
    for (final row in rows) {
      total += (row['total'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// COUNT(*) FROM orders WHERE status='completed' AND created_at >= today
  Future<int> getTodayOrderCount(String outletId) async {
    final response = await _supabase
        .from('orders')
        .select('id')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', _startOfToday.toIso8601String());

    return (response as List).length;
  }

  /// COUNT(*) FROM products WHERE is_active=true AND outlet_id=...
  Future<int> getActiveProductCount(String outletId) async {
    final response = await _supabase
        .from('products')
        .select('id')
        .eq('outlet_id', outletId)
        .eq('is_active', true);

    return (response as List).length;
  }

  /// COUNT(*) FROM ingredients WHERE current_stock <= min_stock AND outlet_id=...
  Future<int> getLowStockCount(String outletId) async {
    final response = await _supabase
        .from('ingredients')
        .select('id, current_stock, min_stock')
        .eq('outlet_id', outletId);

    final rows = response as List;
    int count = 0;
    for (final row in rows) {
      final current = (row['current_stock'] as num?)?.toDouble() ?? 0;
      final min = (row['min_stock'] as num?)?.toDouble() ?? 0;
      if (current <= min) count++;
    }
    return count;
  }

  /// Fetch all 4 stats in parallel
  Future<DashboardStats> getStats(String outletId) async {
    final results = await Future.wait([
      getTodaySales(outletId),
      getTodayOrderCount(outletId),
      getActiveProductCount(outletId),
      getLowStockCount(outletId),
    ]);

    return DashboardStats(
      todaySales: results[0] as double,
      todayOrders: results[1] as int,
      activeProducts: results[2] as int,
      lowStockCount: results[3] as int,
    );
  }

  /// Last N completed orders, most recent first
  Future<List<Order>> getRecentOrders(String outletId, {int limit = 5}) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Order.fromJson(json)).toList();
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

final dashboardRepositoryProvider = Provider((ref) => DashboardRepository());

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getStats(_outletId);
});

final recentOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getRecentOrders(_outletId, limit: 5);
});
