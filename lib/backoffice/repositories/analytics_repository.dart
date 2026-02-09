import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/date_utils.dart';

// ─── Models ─────────────────────────────────────────────────────────

class PeakHourData {
  final int hour;
  final int orderCount;
  final double revenue;

  PeakHourData({
    required this.hour,
    required this.orderCount,
    required this.revenue,
  });
}

class DayOfWeekData {
  final int day; // 1=Monday ... 7=Sunday (ISO)
  final String dayName;
  final int orderCount;
  final double revenue;

  DayOfWeekData({
    required this.day,
    required this.dayName,
    required this.orderCount,
    required this.revenue,
  });
}

class TopCustomerData {
  final String id;
  final String name;
  final String? phone;
  final double totalSpent;
  final int totalVisits;
  final int loyaltyPoints;

  TopCustomerData({
    required this.id,
    required this.name,
    this.phone,
    required this.totalSpent,
    required this.totalVisits,
    required this.loyaltyPoints,
  });
}

class ProductPerformanceData {
  final String productId;
  final String productName;
  final int qtySold;
  final double revenue;
  final double revenuePercent;
  final double cumulativePercent;
  final String abcCategory; // 'A', 'B', or 'C'

  ProductPerformanceData({
    required this.productId,
    required this.productName,
    required this.qtySold,
    required this.revenue,
    required this.revenuePercent,
    required this.cumulativePercent,
    required this.abcCategory,
  });
}

class OrderSourceData {
  final String source;
  final String sourceLabel;
  final int orderCount;
  final double revenue;
  final double percentage;

  OrderSourceData({
    required this.source,
    required this.sourceLabel,
    required this.orderCount,
    required this.revenue,
    required this.percentage,
  });
}

class AovTrendData {
  final DateTime date;
  final double avgOrderValue;
  final int orderCount;
  final double totalRevenue;

  AovTrendData({
    required this.date,
    required this.avgOrderValue,
    required this.orderCount,
    required this.totalRevenue,
  });
}

class CustomerRetentionData {
  final int newCustomers;
  final int returningCustomers;
  final int totalCustomers;
  final double retentionRate; // percentage

  CustomerRetentionData({
    required this.newCustomers,
    required this.returningCustomers,
    required this.totalCustomers,
    required this.retentionRate,
  });
}

class StaffPerformanceData {
  final String staffId;
  final String staffName;
  final String role;
  final int totalOrders;
  final double totalRevenue;
  final double avgOrderValue;

  StaffPerformanceData({
    required this.staffId,
    required this.staffName,
    required this.role,
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgOrderValue,
  });
}

// ─── Repository ─────────────────────────────────────────────────────

class AnalyticsRepository {
  final _client = Supabase.instance.client;

  // ─── 1. Peak Hours Analysis ─────────────────────────────────────
  /// Orders grouped by hour of day (last 30 days).
  /// Returns list of PeakHourData for hours 0-23.
  Future<List<PeakHourData>> getPeakHours(String outletId) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    final response = await _client
        .from('orders')
        .select('created_at, total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', DateTimeUtils.toUtcIso(from))
        .lte('created_at', DateTimeUtils.toUtcIso(now));

    final rows = response as List;

    // Initialize all 24 hours
    final Map<int, _HourAgg> hourly = {
      for (var h = 0; h < 24; h++) h: _HourAgg(),
    };

    for (final row in rows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final hour = createdAt.hour;
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      hourly[hour]!.count += 1;
      hourly[hour]!.revenue += total;
    }

    return hourly.entries.map((e) {
      return PeakHourData(
        hour: e.key,
        orderCount: e.value.count,
        revenue: e.value.revenue,
      );
    }).toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
  }

  // ─── 2. Day of Week Analysis ────────────────────────────────────
  /// Which days are busiest (last 30 days).
  Future<List<DayOfWeekData>> getDayOfWeekAnalysis(String outletId) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    final response = await _client
        .from('orders')
        .select('created_at, total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', DateTimeUtils.toUtcIso(from))
        .lte('created_at', DateTimeUtils.toUtcIso(now));

    final rows = response as List;

    const dayNames = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    // Initialize all 7 days (1=Monday to 7=Sunday)
    final Map<int, _DayAgg> daily = {
      for (var d = 1; d <= 7; d++) d: _DayAgg(),
    };

    for (final row in rows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final weekday = createdAt.weekday; // 1=Monday, 7=Sunday
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      daily[weekday]!.count += 1;
      daily[weekday]!.revenue += total;
    }

    return daily.entries.map((e) {
      return DayOfWeekData(
        day: e.key,
        dayName: dayNames[e.key],
        orderCount: e.value.count,
        revenue: e.value.revenue,
      );
    }).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  // ─── 3. Top Customers ──────────────────────────────────────────
  /// Top customers by total_spent.
  Future<List<TopCustomerData>> getTopCustomers(
    String outletId, {
    int limit = 10,
  }) async {
    final response = await _client
        .from('customers')
        .select('id, name, phone, total_spent, total_visits, loyalty_points')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .gt('total_spent', 0)
        .order('total_spent', ascending: false)
        .limit(limit);

    final rows = response as List;

    return rows.map((row) {
      return TopCustomerData(
        id: row['id'] as String,
        name: row['name'] as String? ?? 'Unknown',
        phone: row['phone'] as String?,
        totalSpent: (row['total_spent'] as num?)?.toDouble() ?? 0,
        totalVisits: row['total_visits'] as int? ?? 0,
        loyaltyPoints: row['loyalty_points'] as int? ?? 0,
      );
    }).toList();
  }

  // ─── 4. Product Performance (ABC Analysis) ─────────────────────
  /// ABC analysis: A = top 80% revenue, B = next 15%, C = bottom 5%.
  Future<List<ProductPerformanceData>> getProductPerformance(
    String outletId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _client
        .from('order_items')
        .select(
            'product_id, product_name, quantity, total, orders!inner(outlet_id, status, created_at)')
        .eq('orders.outlet_id', outletId)
        .eq('orders.status', 'completed')
        .gte('orders.created_at', DateTimeUtils.toUtcIso(from))
        .lte('orders.created_at', DateTimeUtils.toUtcIso(to));

    final rows = response as List;

    // Aggregate by product
    final Map<String, _ProductAgg> agg = {};
    for (final row in rows) {
      final pid = row['product_id'] as String;
      final name = row['product_name'] as String? ?? 'Unknown';
      final qty = row['quantity'] as int? ?? 1;
      final rev = (row['total'] as num?)?.toDouble() ?? 0;

      if (agg.containsKey(pid)) {
        agg[pid]!.quantity += qty;
        agg[pid]!.revenue += rev;
      } else {
        agg[pid] = _ProductAgg(name: name, quantity: qty, revenue: rev);
      }
    }

    // Sort by revenue descending
    final sorted = agg.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    final totalRevenue =
        sorted.fold<double>(0, (sum, e) => sum + e.value.revenue);

    // Calculate ABC categories
    double cumulativePercent = 0;
    final results = <ProductPerformanceData>[];

    for (final entry in sorted) {
      final revenuePercent =
          totalRevenue > 0 ? (entry.value.revenue / totalRevenue) * 100 : 0.0;
      cumulativePercent += revenuePercent;

      String category;
      if (cumulativePercent <= 80) {
        category = 'A';
      } else if (cumulativePercent <= 95) {
        category = 'B';
      } else {
        category = 'C';
      }

      results.add(ProductPerformanceData(
        productId: entry.key,
        productName: entry.value.name,
        qtySold: entry.value.quantity,
        revenue: entry.value.revenue,
        revenuePercent: revenuePercent,
        cumulativePercent: cumulativePercent,
        abcCategory: category,
      ));
    }

    return results;
  }

  // ─── 5. Order Source Breakdown ──────────────────────────────────
  /// Group orders by source column (pos, self_order, gofood, etc.)
  Future<List<OrderSourceData>> getOrderSourceBreakdown(
    String outletId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _client
        .from('orders')
        .select('source, total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', DateTimeUtils.toUtcIso(from))
        .lte('created_at', DateTimeUtils.toUtcIso(to));

    final rows = response as List;

    // Aggregate by source
    final Map<String, _SourceAgg> agg = {};
    for (final row in rows) {
      final source = row['source'] as String? ?? 'pos';
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      if (agg.containsKey(source)) {
        agg[source]!.count += 1;
        agg[source]!.revenue += total;
      } else {
        agg[source] = _SourceAgg(count: 1, revenue: total);
      }
    }

    final totalOrders = rows.length;

    // Build sorted results
    final sorted = agg.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    return sorted.map((entry) {
      return OrderSourceData(
        source: entry.key,
        sourceLabel: _sourceLabel(entry.key),
        orderCount: entry.value.count,
        revenue: entry.value.revenue,
        percentage:
            totalOrders > 0 ? (entry.value.count / totalOrders) * 100 : 0,
      );
    }).toList();
  }

  // ─── 6. Average Order Value Trend ──────────────────────────────
  /// Daily AOV for last 30 days.
  Future<List<AovTrendData>> getAovTrend(String outletId) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    final response = await _client
        .from('orders')
        .select('created_at, total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', DateTimeUtils.toUtcIso(from))
        .lte('created_at', DateTimeUtils.toUtcIso(now))
        .order('created_at', ascending: true);

    final rows = response as List;

    // Group by date (day granularity)
    final Map<String, _AovAgg> daily = {};
    for (final row in rows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final dateKey =
          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      if (daily.containsKey(dateKey)) {
        daily[dateKey]!.totalRevenue += total;
        daily[dateKey]!.orderCount += 1;
      } else {
        daily[dateKey] = _AovAgg(totalRevenue: total, orderCount: 1);
      }
    }

    // Build results sorted by date
    final sorted = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted.map((entry) {
      final parts = entry.key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final aov = entry.value.orderCount > 0
          ? entry.value.totalRevenue / entry.value.orderCount
          : 0.0;

      return AovTrendData(
        date: date,
        avgOrderValue: aov,
        orderCount: entry.value.orderCount,
        totalRevenue: entry.value.totalRevenue,
      );
    }).toList();
  }

  // ─── 7. Customer Retention ─────────────────────────────────────
  /// New vs returning customers analysis.
  Future<CustomerRetentionData> getCustomerRetention(String outletId) async {
    final response = await _client
        .from('customers')
        .select('id, total_visits, created_at')
        .eq('outlet_id', outletId)
        .eq('is_active', true);

    final rows = response as List;

    int newCustomers = 0;
    int returningCustomers = 0;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (final row in rows) {
      final visits = row['total_visits'] as int? ?? 0;
      final createdAt = row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toLocal()
          : null;

      // A customer is "new" if created in the last 30 days
      if (createdAt != null && createdAt.isAfter(thirtyDaysAgo)) {
        newCustomers += 1;
      }

      // A customer is "returning" if they have more than 1 visit
      if (visits > 1) {
        returningCustomers += 1;
      }
    }

    final totalCustomers = rows.length;
    final retentionRate =
        totalCustomers > 0 ? (returningCustomers / totalCustomers) * 100 : 0.0;

    return CustomerRetentionData(
      newCustomers: newCustomers,
      returningCustomers: returningCustomers,
      totalCustomers: totalCustomers,
      retentionRate: retentionRate,
    );
  }

  // ─── 8. Staff Performance ──────────────────────────────────────
  /// Orders and revenue per cashier.
  Future<List<StaffPerformanceData>> getStaffPerformance(
    String outletId,
    DateTime from,
    DateTime to,
  ) async {
    // Fetch completed orders with cashier_id
    final ordersResponse = await _client
        .from('orders')
        .select('cashier_id, total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', DateTimeUtils.toUtcIso(from))
        .lte('created_at', DateTimeUtils.toUtcIso(to));

    final orderRows = ordersResponse as List;

    // Aggregate by cashier_id
    final Map<String, _StaffAgg> agg = {};
    for (final row in orderRows) {
      final cashierId = row['cashier_id'] as String?;
      if (cashierId == null) continue;
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      if (agg.containsKey(cashierId)) {
        agg[cashierId]!.orderCount += 1;
        agg[cashierId]!.revenue += total;
      } else {
        agg[cashierId] = _StaffAgg(orderCount: 1, revenue: total);
      }
    }

    if (agg.isEmpty) return [];

    // Fetch staff profiles
    final staffResponse = await _client
        .from('profiles')
        .select('id, full_name, role')
        .eq('outlet_id', outletId)
        .eq('is_active', true);

    final staffRows = staffResponse as List;
    final staffMap = <String, Map<String, String>>{};
    for (final s in staffRows) {
      staffMap[s['id'] as String] = {
        'name': s['full_name'] as String? ?? 'Unknown',
        'role': s['role'] as String? ?? 'cashier',
      };
    }

    // Build results
    final results = agg.entries.map((entry) {
      final staff = staffMap[entry.key];
      final totalOrders = entry.value.orderCount;
      final totalRevenue = entry.value.revenue;
      final avgOrder = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

      return StaffPerformanceData(
        staffId: entry.key,
        staffName: staff?['name'] ?? 'Unknown',
        role: staff?['role'] ?? 'cashier',
        totalOrders: totalOrders,
        totalRevenue: totalRevenue,
        avgOrderValue: avgOrder,
      );
    }).toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return results;
  }

  // ─── Helpers ───────────────────────────────────────────────────

  static String _sourceLabel(String source) {
    switch (source) {
      case 'pos':
        return 'POS (Kasir)';
      case 'self_order':
        return 'Self Order';
      case 'gofood':
        return 'GoFood';
      case 'grabfood':
        return 'GrabFood';
      case 'shopeefood':
        return 'ShopeeFood';
      default:
        return source
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) =>
                w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }
}

// ─── Private Aggregation Helpers ──────────────────────────────────

class _HourAgg {
  int count = 0;
  double revenue = 0;
}

class _DayAgg {
  int count = 0;
  double revenue = 0;
}

class _ProductAgg {
  String name;
  int quantity;
  double revenue;

  _ProductAgg({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

class _SourceAgg {
  int count;
  double revenue;

  _SourceAgg({required this.count, required this.revenue});
}

class _AovAgg {
  double totalRevenue;
  int orderCount;

  _AovAgg({required this.totalRevenue, required this.orderCount});
}

class _StaffAgg {
  int orderCount;
  double revenue;

  _StaffAgg({required this.orderCount, required this.revenue});
}
