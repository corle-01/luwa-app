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

/// Monthly comparison data
class MonthlySalesData {
  final int year;
  final int month;
  final String monthLabel;
  final double totalSales;
  final int orderCount;
  final double avgOrderValue;

  MonthlySalesData({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.totalSales,
    required this.orderCount,
    required this.avgOrderValue,
  });
}

/// Growth metrics (current month vs previous month)
class GrowthMetrics {
  final double currentMonthSales;
  final double previousMonthSales;
  final double salesGrowthPercent;
  final int currentMonthOrders;
  final int previousMonthOrders;
  final double orderGrowthPercent;
  final double currentAvgOrder;
  final double previousAvgOrder;
  final double avgOrderGrowthPercent;

  GrowthMetrics({
    required this.currentMonthSales,
    required this.previousMonthSales,
    required this.salesGrowthPercent,
    required this.currentMonthOrders,
    required this.previousMonthOrders,
    required this.orderGrowthPercent,
    required this.currentAvgOrder,
    required this.previousAvgOrder,
    required this.avgOrderGrowthPercent,
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

  /// Get monthly sales data for the last N months
  Future<List<MonthlySalesData>> getMonthlySales(String outletId,
      {int months = 6}) async {
    final now = DateTime.now();
    final results = <MonthlySalesData>[];

    // Indonesian month names
    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];

    for (var i = months - 1; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);

      final response = await _supabase
          .from('orders')
          .select('total')
          .eq('outlet_id', outletId)
          .eq('status', 'completed')
          .gte('created_at', targetMonth.toIso8601String())
          .lt('created_at', nextMonth.toIso8601String());

      final rows = response as List;
      final totalSales = rows.fold<double>(
          0, (sum, r) => sum + ((r['total'] as num?)?.toDouble() ?? 0));
      final orderCount = rows.length;
      final avgOrder = orderCount > 0 ? totalSales / orderCount : 0.0;

      results.add(MonthlySalesData(
        year: targetMonth.year,
        month: targetMonth.month,
        monthLabel:
            '${monthNames[targetMonth.month]} ${targetMonth.year.toString().substring(2)}',
        totalSales: totalSales,
        orderCount: orderCount,
        avgOrderValue: avgOrder,
      ));
    }

    return results;
  }

  /// Get growth metrics (current month vs previous month)
  Future<GrowthMetrics> getGrowthMetrics(String outletId) async {
    final now = DateTime.now();
    final currentStart = DateTime(now.year, now.month, 1);
    final currentEnd = DateTime(now.year, now.month + 1, 1);
    final prevStart = DateTime(now.year, now.month - 1, 1);

    final currentReport =
        await getSalesReport(outletId, currentStart, currentEnd);
    final prevReport =
        await getSalesReport(outletId, prevStart, currentStart);

    double calcGrowth(double current, double previous) {
      if (previous == 0) return current > 0 ? 100 : 0;
      return ((current - previous) / previous) * 100;
    }

    return GrowthMetrics(
      currentMonthSales: currentReport.totalSales,
      previousMonthSales: prevReport.totalSales,
      salesGrowthPercent:
          calcGrowth(currentReport.totalSales, prevReport.totalSales),
      currentMonthOrders: currentReport.orderCount,
      previousMonthOrders: prevReport.orderCount,
      orderGrowthPercent: calcGrowth(
          currentReport.orderCount.toDouble(), prevReport.orderCount.toDouble()),
      currentAvgOrder: currentReport.avgOrderValue,
      previousAvgOrder: prevReport.avgOrderValue,
      avgOrderGrowthPercent:
          calcGrowth(currentReport.avgOrderValue, prevReport.avgOrderValue),
    );
  }

  /// Get HPP (Cost of Goods Sold) report for a date range.
  /// Joins order_items with orders and products to calculate cost vs revenue per product.
  Future<HppSummary> getHppReport(
    String outletId,
    DateTime from,
    DateTime to,
  ) async {
    // 1. Get completed order items with product info
    final response = await _supabase
        .from('order_items')
        .select(
            'product_id, product_name, quantity, unit_price, total, orders!inner(outlet_id, status, created_at)')
        .eq('orders.outlet_id', outletId)
        .eq('orders.status', 'completed')
        .gte('orders.created_at', from.toIso8601String())
        .lte('orders.created_at', to.toIso8601String());

    // 2. Get product costs
    final productsResponse = await _supabase
        .from('products')
        .select('id, cost_price, selling_price')
        .eq('outlet_id', outletId);

    final costMap = <String, double>{};
    final priceMap = <String, double>{};
    for (final p in productsResponse as List) {
      costMap[p['id']] = (p['cost_price'] as num?)?.toDouble() ?? 0;
      priceMap[p['id']] = (p['selling_price'] as num?)?.toDouble() ?? 0;
    }

    // 3. Aggregate by product
    final Map<String, _HppAgg> agg = {};
    for (final row in response as List) {
      final pid = row['product_id'] as String;
      final name = row['product_name'] as String? ?? 'Unknown';
      final qty = row['quantity'] as int? ?? 1;
      final revenue = (row['total'] as num?)?.toDouble() ?? 0;
      final cost = (costMap[pid] ?? 0) * qty;

      if (agg.containsKey(pid)) {
        agg[pid]!.qty += qty;
        agg[pid]!.revenue += revenue;
        agg[pid]!.cost += cost;
      } else {
        agg[pid] = _HppAgg(
          name: name,
          qty: qty,
          revenue: revenue,
          cost: cost,
          costPrice: costMap[pid] ?? 0,
          sellingPrice: priceMap[pid] ?? 0,
        );
      }
    }

    // 4. Build items
    final items = agg.entries.map((e) {
      final a = e.value;
      final profit = a.revenue - a.cost;
      final margin = a.revenue > 0 ? (profit / a.revenue) * 100 : 0.0;
      return HppReportItem(
        productId: e.key,
        productName: a.name,
        costPrice: a.costPrice,
        sellingPrice: a.sellingPrice,
        qtySold: a.qty,
        totalRevenue: a.revenue,
        totalCost: a.cost,
        grossProfit: profit,
        marginPercent: margin,
      );
    }).toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    // 5. Summary
    final totalRevenue = items.fold(0.0, (s, i) => s + i.totalRevenue);
    final totalCost = items.fold(0.0, (s, i) => s + i.totalCost);
    final grossProfit = totalRevenue - totalCost;
    final avgMargin =
        totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

    return HppSummary(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      grossProfit: grossProfit,
      avgMargin: avgMargin,
      items: items,
    );
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

// --- HPP (COGS) Models ---

class HppReportItem {
  final String productId;
  final String productName;
  final double costPrice;
  final double sellingPrice;
  final int qtySold;
  final double totalRevenue; // qty * selling_price
  final double totalCost; // qty * cost_price
  final double grossProfit; // totalRevenue - totalCost
  final double marginPercent; // (grossProfit / totalRevenue) * 100

  HppReportItem({
    required this.productId,
    required this.productName,
    required this.costPrice,
    required this.sellingPrice,
    required this.qtySold,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.marginPercent,
  });
}

class HppSummary {
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double avgMargin;
  final List<HppReportItem> items;

  HppSummary({
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.avgMargin,
    required this.items,
  });
}

class _HppAgg {
  String name;
  int qty;
  double revenue;
  double cost;
  double costPrice;
  double sellingPrice;

  _HppAgg({
    required this.name,
    required this.qty,
    required this.revenue,
    required this.cost,
    required this.costPrice,
    required this.sellingPrice,
  });
}
