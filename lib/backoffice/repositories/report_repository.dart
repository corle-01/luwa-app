import 'package:supabase_flutter/supabase_flutter.dart';

// --- Models ---

class SalesReport {
  final double totalSales;
  final int orderCount;
  final double avgOrderValue;
  final Map<String, double> paymentBreakdown;
  final double totalDiscount;
  final double totalTax;
  final double totalServiceCharge;

  SalesReport({
    required this.totalSales,
    required this.orderCount,
    required this.avgOrderValue,
    required this.paymentBreakdown,
    this.totalDiscount = 0,
    this.totalTax = 0,
    this.totalServiceCharge = 0,
  });

  factory SalesReport.empty() => SalesReport(
        totalSales: 0,
        orderCount: 0,
        avgOrderValue: 0,
        paymentBreakdown: {},
      );
}

class TopProduct {
  final String productName;
  final int quantity;
  final double revenue;

  TopProduct({
    required this.productName,
    required this.quantity,
    required this.revenue,
  });
}

class HourlySales {
  final int hour;
  final double total;
  final int orderCount;

  HourlySales({
    required this.hour,
    required this.total,
    this.orderCount = 0,
  });
}

// --- Repository ---

class ReportRepository {
  final _supabase = Supabase.instance.client;

  /// Get sales summary for a date range.
  /// Queries completed orders, aggregates totals, and breaks down by payment method.
  Future<SalesReport> getSalesReport(
    String outletId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _supabase
        .from('orders')
        .select('total, payment_method, discount_amount, tax_amount, service_charge_amount')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String());

    final rows = response as List;

    if (rows.isEmpty) {
      return SalesReport.empty();
    }

    double totalSales = 0;
    double totalDiscount = 0;
    double totalTax = 0;
    double totalServiceCharge = 0;
    final Map<String, double> paymentBreakdown = {};

    for (final row in rows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      final method = row['payment_method'] as String? ?? 'cash';

      totalSales += total;
      totalDiscount += (row['discount_amount'] as num?)?.toDouble() ?? 0;
      totalTax += (row['tax_amount'] as num?)?.toDouble() ?? 0;
      totalServiceCharge +=
          (row['service_charge_amount'] as num?)?.toDouble() ?? 0;

      paymentBreakdown[method] = (paymentBreakdown[method] ?? 0) + total;
    }

    final orderCount = rows.length;
    final avgOrderValue = orderCount > 0 ? totalSales / orderCount : 0.0;

    return SalesReport(
      totalSales: totalSales,
      orderCount: orderCount,
      avgOrderValue: avgOrderValue,
      paymentBreakdown: paymentBreakdown,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      totalServiceCharge: totalServiceCharge,
    );
  }

  /// Get top-selling products for a date range.
  /// Joins order_items with orders to filter by outlet and date,
  /// then groups by product_name, summing quantity and revenue.
  Future<List<TopProduct>> getTopProducts(
    String outletId,
    DateTime from,
    DateTime to, {
    int limit = 10,
  }) async {
    final response = await _supabase
        .from('order_items')
        .select('product_name, quantity, total, orders!inner(outlet_id, status, created_at)')
        .eq('orders.outlet_id', outletId)
        .eq('orders.status', 'completed')
        .gte('orders.created_at', from.toIso8601String())
        .lte('orders.created_at', to.toIso8601String());

    final rows = response as List;

    // Aggregate in-memory by product_name
    final Map<String, _ProductAgg> agg = {};
    for (final row in rows) {
      final name = row['product_name'] as String? ?? 'Unknown';
      final qty = row['quantity'] as int? ?? 1;
      final rev = (row['total'] as num?)?.toDouble() ?? 0;

      if (agg.containsKey(name)) {
        agg[name]!.quantity += qty;
        agg[name]!.revenue += rev;
      } else {
        agg[name] = _ProductAgg(quantity: qty, revenue: rev);
      }
    }

    // Sort by quantity descending, take top N
    final sorted = agg.entries.toList()
      ..sort((a, b) => b.value.quantity.compareTo(a.value.quantity));

    return sorted.take(limit).map((e) {
      return TopProduct(
        productName: e.key,
        quantity: e.value.quantity,
        revenue: e.value.revenue,
      );
    }).toList();
  }

  /// Get hourly sales distribution for a single date.
  /// Groups completed orders by hour of created_at.
  Future<List<HourlySales>> getHourlySales(
    String outletId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _supabase
        .from('orders')
        .select('total, created_at')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String());

    final rows = response as List;

    // Initialize all 24 hours
    final Map<int, _HourAgg> hourly = {
      for (var h = 0; h < 24; h++) h: _HourAgg(),
    };

    for (final row in rows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final hour = createdAt.hour;
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      hourly[hour]!.total += total;
      hourly[hour]!.count += 1;
    }

    return hourly.entries.map((e) {
      return HourlySales(
        hour: e.key,
        total: e.value.total,
        orderCount: e.value.count,
      );
    }).toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
  }
}

// Private aggregation helpers
class _ProductAgg {
  int quantity;
  double revenue;

  _ProductAgg({required this.quantity, required this.revenue});
}

class _HourAgg {
  double total = 0;
  int count = 0;
}
