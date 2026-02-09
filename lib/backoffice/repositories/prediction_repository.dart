import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/date_utils.dart';

// ─── Models ─────────────────────────────────────────────────────────

class DailySalesPoint {
  final DateTime date;
  final double totalSales;
  final int orderCount;

  DailySalesPoint({
    required this.date,
    required this.totalSales,
    required this.orderCount,
  });
}

class ProductDemandPoint {
  final DateTime date;
  final String productId;
  final String productName;
  final int qtySold;
  final double revenue;

  ProductDemandPoint({
    required this.date,
    required this.productId,
    required this.productName,
    required this.qtySold,
    required this.revenue,
  });
}

class PredictionPoint {
  final DateTime date;
  final double value;
  final bool isPrediction;
  final double? confidenceLow;
  final double? confidenceHigh;

  PredictionPoint({
    required this.date,
    required this.value,
    required this.isPrediction,
    this.confidenceLow,
    this.confidenceHigh,
  });
}

class ProductDemandForecast {
  final String productId;
  final String productName;
  final double avgDailySales;
  final double predictedNextWeek;
  final double trend; // positive = growing, negative = declining
  final String trendLabel;

  ProductDemandForecast({
    required this.productId,
    required this.productName,
    required this.avgDailySales,
    required this.predictedNextWeek,
    required this.trend,
    required this.trendLabel,
  });
}

class RestockSuggestion {
  final String productId;
  final String productName;
  final int currentStock;
  final int minStock;
  final double dailyVelocity; // avg items sold per day
  final int daysUntilStockout; // -1 means no tracking
  final int suggestedRestock;
  final String urgency; // 'critical', 'warning', 'info'

  RestockSuggestion({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minStock,
    required this.dailyVelocity,
    required this.daysUntilStockout,
    required this.suggestedRestock,
    required this.urgency,
  });
}

class DayOfWeekPrediction {
  final int weekday; // 1=Monday .. 7=Sunday
  final String dayName;
  final double predictedRevenue;
  final int predictedOrders;
  final bool isBestDay;
  final bool isWorstDay;

  DayOfWeekPrediction({
    required this.weekday,
    required this.dayName,
    required this.predictedRevenue,
    required this.predictedOrders,
    required this.isBestDay,
    required this.isWorstDay,
  });
}

class PredictionSummary {
  final double predictedRevenueNextWeek;
  final double revenueGrowthPercent;
  final int productsNeedingRestock;
  final String bestDayName;
  final String worstDayName;
  final double avgDailyRevenue;
  final double confidenceScore; // 0-100

  PredictionSummary({
    required this.predictedRevenueNextWeek,
    required this.revenueGrowthPercent,
    required this.productsNeedingRestock,
    required this.bestDayName,
    required this.worstDayName,
    required this.avgDailyRevenue,
    required this.confidenceScore,
  });
}

// ─── Repository ─────────────────────────────────────────────────────

class PredictionRepository {
  final _client = Supabase.instance.client;

  // ─── 1. Daily Sales Trend ─────────────────────────────────────────
  /// Fetch daily sales totals for the last N days.
  Future<List<DailySalesPoint>> getDailySalesTrend(
    String outletId, {
    int days = 30,
  }) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    final response = await _client
        .from('orders')
        .select('created_at, total')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .gte('created_at', DateTimeUtils.toUtcIso(from))
        .lte('created_at', DateTimeUtils.toUtcIso(now))
        .order('created_at', ascending: true);

    final rows = response as List;

    // Group by date
    final Map<String, _DayAgg> daily = {};
    for (final row in rows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final dateKey =
          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      if (daily.containsKey(dateKey)) {
        daily[dateKey]!.totalSales += total;
        daily[dateKey]!.orderCount += 1;
      } else {
        daily[dateKey] = _DayAgg(totalSales: total, orderCount: 1);
      }
    }

    // Fill in zero-days so there are no gaps
    final results = <DailySalesPoint>[];
    for (var i = 0; i < days; i++) {
      final date = from.add(Duration(days: i + 1));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final agg = daily[dateKey];

      results.add(DailySalesPoint(
        date: DateTime(date.year, date.month, date.day),
        totalSales: agg?.totalSales ?? 0,
        orderCount: agg?.orderCount ?? 0,
      ));
    }

    return results;
  }

  // ─── 2. Product Demand Trend ──────────────────────────────────────
  /// Daily demand for a specific product (or all products if null).
  Future<Map<String, List<ProductDemandPoint>>> getProductDemandTrends(
    String outletId, {
    int days = 30,
  }) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    final response = await _client
        .from('order_items')
        .select(
            'product_id, product_name, quantity, total, orders!inner(outlet_id, status, created_at)')
        .eq('orders.outlet_id', outletId)
        .eq('orders.status', 'completed')
        .gte('orders.created_at', DateTimeUtils.toUtcIso(from))
        .lte('orders.created_at', DateTimeUtils.toUtcIso(now));

    final rows = response as List;

    // Group by product_id -> date -> aggregation
    final Map<String, Map<String, _ProductDayAgg>> productDaily = {};
    final Map<String, String> productNames = {};

    for (final row in rows) {
      final pid = row['product_id'] as String;
      final name = row['product_name'] as String? ?? 'Unknown';
      final qty = row['quantity'] as int? ?? 1;
      final rev = (row['total'] as num?)?.toDouble() ?? 0;
      final orderData = row['orders'] as Map<String, dynamic>;
      final createdAt =
          DateTime.parse(orderData['created_at'] as String).toLocal();
      final dateKey =
          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

      productNames[pid] = name;

      if (!productDaily.containsKey(pid)) {
        productDaily[pid] = {};
      }
      if (productDaily[pid]!.containsKey(dateKey)) {
        productDaily[pid]![dateKey]!.qty += qty;
        productDaily[pid]![dateKey]!.revenue += rev;
      } else {
        productDaily[pid]![dateKey] = _ProductDayAgg(qty: qty, revenue: rev);
      }
    }

    // Build result map
    final Map<String, List<ProductDemandPoint>> result = {};
    for (final pid in productDaily.keys) {
      final dayMap = productDaily[pid]!;
      final points = <ProductDemandPoint>[];

      for (var i = 0; i < days; i++) {
        final date = from.add(Duration(days: i + 1));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final agg = dayMap[dateKey];

        points.add(ProductDemandPoint(
          date: DateTime(date.year, date.month, date.day),
          productId: pid,
          productName: productNames[pid] ?? 'Unknown',
          qtySold: agg?.qty ?? 0,
          revenue: agg?.revenue ?? 0,
        ));
      }

      result[pid] = points;
    }

    return result;
  }

  // ─── 3. Prediction Algorithm ──────────────────────────────────────
  /// Predict next N days using weighted moving average + linear regression.
  /// All client-side math, no external API needed.
  List<PredictionPoint> predictNextDays(
    List<DailySalesPoint> historicalData, {
    int daysToPredict = 7,
  }) {
    if (historicalData.isEmpty) return [];

    final values = historicalData.map((d) => d.totalSales).toList();
    final n = values.length;

    // --- Linear regression: y = a + b*x ---
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (var i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final meanX = sumX / n;
    final meanY = sumY / n;
    final b = (n > 1)
        ? (sumXY - n * meanX * meanY) / (sumX2 - n * meanX * meanX)
        : 0.0;
    final a = meanY - b * meanX;

    // --- Weighted Moving Average (last 7 days weighted more) ---
    final windowSize = min(7, n);
    double wma = 0;
    double weightSum = 0;
    for (var i = 0; i < windowSize; i++) {
      final weight = (i + 1).toDouble(); // more recent = higher weight
      wma += values[n - windowSize + i] * weight;
      weightSum += weight;
    }
    wma = weightSum > 0 ? wma / weightSum : meanY;

    // --- Day-of-week seasonality factor ---
    final Map<int, List<double>> dowValues = {};
    for (var i = 0; i < n; i++) {
      final dow = historicalData[i].date.weekday;
      dowValues.putIfAbsent(dow, () => []);
      dowValues[dow]!.add(values[i]);
    }
    final Map<int, double> dowAvg = {};
    for (final entry in dowValues.entries) {
      dowAvg[entry.key] = entry.value.isNotEmpty
          ? entry.value.reduce((a, b) => a + b) / entry.value.length
          : 0;
    }
    final overallAvg = meanY > 0 ? meanY : 1;

    // --- Standard deviation for confidence interval ---
    double sumSqDiff = 0;
    for (final v in values) {
      sumSqDiff += (v - meanY) * (v - meanY);
    }
    final stdDev = n > 1 ? sqrt(sumSqDiff / (n - 1)) : 0.0;

    // --- Generate predictions ---
    final lastDate = historicalData.last.date;
    final predictions = <PredictionPoint>[];

    for (var i = 1; i <= daysToPredict; i++) {
      final predDate = lastDate.add(Duration(days: i));
      final x = n + i - 1;

      // Linear regression component
      final lrValue = a + b * x;

      // Blend: 60% WMA + 40% LR, then adjust for day-of-week
      final blended = 0.6 * wma + 0.4 * lrValue;

      // Day-of-week adjustment
      final dow = predDate.weekday;
      final dowFactor = (dowAvg[dow] ?? overallAvg) / overallAvg;
      final predicted = (blended * dowFactor).clamp(0, double.infinity);

      // Confidence interval widens further out
      final uncertainty = stdDev * (0.5 + 0.15 * i);
      final confidenceLow = (predicted - uncertainty).clamp(0, double.infinity);
      final confidenceHigh = predicted + uncertainty;

      predictions.add(PredictionPoint(
        date: predDate,
        value: predicted.toDouble(),
        isPrediction: true,
        confidenceLow: confidenceLow.toDouble(),
        confidenceHigh: confidenceHigh.toDouble(),
      ));
    }

    return predictions;
  }

  // ─── 4. Product Demand Forecasts ──────────────────────────────────
  /// Predict demand for top N products for the next 7 days.
  List<ProductDemandForecast> getProductDemandForecasts(
    Map<String, List<ProductDemandPoint>> productTrends, {
    int topN = 10,
  }) {
    final forecasts = <ProductDemandForecast>[];

    for (final entry in productTrends.entries) {
      final points = entry.value;
      if (points.isEmpty) continue;

      final totalQty = points.fold<int>(0, (sum, p) => sum + p.qtySold);
      final n = points.length;
      final avgDaily = n > 0 ? totalQty / n : 0.0;

      // Simple linear regression on qty
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (var i = 0; i < n; i++) {
        final y = points[i].qtySold.toDouble();
        sumX += i;
        sumY += y;
        sumXY += i * y;
        sumX2 += i * i;
      }
      final meanX = n > 0 ? sumX / n : 0.0;
      final meanY = n > 0 ? sumY / n : 0.0;
      final b = (n > 1 && (sumX2 - n * meanX * meanX) != 0)
          ? (sumXY - n * meanX * meanY) / (sumX2 - n * meanX * meanX)
          : 0.0;

      // Predicted total for next 7 days
      double predictedWeek = 0;
      for (var i = 1; i <= 7; i++) {
        final x = n + i - 1;
        final predicted = (meanY + b * (x - meanX)).clamp(0, double.infinity);
        predictedWeek += predicted;
      }

      // Trend label
      String trendLabel;
      if (b > 0.1) {
        trendLabel = 'Naik';
      } else if (b < -0.1) {
        trendLabel = 'Turun';
      } else {
        trendLabel = 'Stabil';
      }

      forecasts.add(ProductDemandForecast(
        productId: entry.key,
        productName: points.first.productName,
        avgDailySales: avgDaily,
        predictedNextWeek: predictedWeek,
        trend: b,
        trendLabel: trendLabel,
      ));
    }

    // Sort by predicted demand descending, take top N
    forecasts.sort((a, b) => b.predictedNextWeek.compareTo(a.predictedNextWeek));
    return forecasts.take(topN).toList();
  }

  // ─── 5. Restock Suggestions ───────────────────────────────────────
  /// Based on sales velocity vs current product stock.
  Future<List<RestockSuggestion>> getRestockSuggestions(
    String outletId, {
    int lookbackDays = 14,
  }) async {
    // Fetch products with stock tracking
    final productsResp = await _client
        .from('products')
        .select('id, name, track_stock, stock_quantity, min_stock')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .eq('track_stock', true);

    final products = productsResp as List;

    if (products.isEmpty) return [];

    // Fetch recent order items to compute velocity
    final now = DateTime.now();
    final from = now.subtract(Duration(days: lookbackDays));

    final itemsResp = await _client
        .from('order_items')
        .select(
            'product_id, quantity, orders!inner(outlet_id, status, created_at)')
        .eq('orders.outlet_id', outletId)
        .eq('orders.status', 'completed')
        .gte('orders.created_at', DateTimeUtils.toUtcIso(from))
        .lte('orders.created_at', DateTimeUtils.toUtcIso(now));

    final items = itemsResp as List;

    // Calculate daily velocity per product
    final Map<String, int> totalSold = {};
    for (final item in items) {
      final pid = item['product_id'] as String;
      final qty = item['quantity'] as int? ?? 1;
      totalSold[pid] = (totalSold[pid] ?? 0) + qty;
    }

    final suggestions = <RestockSuggestion>[];

    for (final product in products) {
      final pid = product['id'] as String;
      final name = product['name'] as String? ?? 'Unknown';
      final currentStock = product['stock_quantity'] as int? ?? 0;
      final minStock = product['min_stock'] as int? ?? 0;
      final sold = totalSold[pid] ?? 0;
      final dailyVelocity = lookbackDays > 0 ? sold / lookbackDays : 0.0;

      // Days until stockout
      int daysUntilStockout;
      if (dailyVelocity <= 0) {
        daysUntilStockout = 999; // No sales, won't run out
      } else {
        daysUntilStockout = (currentStock / dailyVelocity).floor();
      }

      // Suggested restock: enough for 14 days of supply, minus current stock
      final targetStock = (dailyVelocity * 14).ceil();
      final suggestedRestock = max(0, targetStock - currentStock);

      // Urgency
      String urgency;
      if (currentStock <= 0) {
        urgency = 'critical';
      } else if (daysUntilStockout <= 3) {
        urgency = 'critical';
      } else if (daysUntilStockout <= 7 || currentStock <= minStock) {
        urgency = 'warning';
      } else {
        urgency = 'info';
      }

      // Only include products that need action
      if (suggestedRestock > 0 || currentStock <= minStock) {
        suggestions.add(RestockSuggestion(
          productId: pid,
          productName: name,
          currentStock: currentStock,
          minStock: minStock,
          dailyVelocity: dailyVelocity,
          daysUntilStockout: daysUntilStockout,
          suggestedRestock: suggestedRestock,
          urgency: urgency,
        ));
      }
    }

    // Sort by urgency then by days until stockout
    final urgencyOrder = {'critical': 0, 'warning': 1, 'info': 2};
    suggestions.sort((a, b) {
      final urgCmp =
          (urgencyOrder[a.urgency] ?? 3).compareTo(urgencyOrder[b.urgency] ?? 3);
      if (urgCmp != 0) return urgCmp;
      return a.daysUntilStockout.compareTo(b.daysUntilStockout);
    });

    return suggestions;
  }

  // ─── 6. Day of Week Predictions ───────────────────────────────────
  /// Predict which days next week will be busiest/slowest.
  List<DayOfWeekPrediction> getDayOfWeekPredictions(
    List<DailySalesPoint> historicalData,
  ) {
    if (historicalData.isEmpty) return [];

    const dayNames = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];

    // Group by day of week
    final Map<int, List<double>> revenueByDow = {};
    final Map<int, List<int>> ordersByDow = {};

    for (final point in historicalData) {
      final dow = point.date.weekday;
      revenueByDow.putIfAbsent(dow, () => []);
      ordersByDow.putIfAbsent(dow, () => []);
      revenueByDow[dow]!.add(point.totalSales);
      ordersByDow[dow]!.add(point.orderCount);
    }

    // Weight recent weeks more (last week 3x, week before 2x, rest 1x)
    final predictions = <DayOfWeekPrediction>[];
    double maxRevenue = 0;
    double minRevenue = double.infinity;
    int bestDow = 1;
    int worstDow = 1;

    for (var dow = 1; dow <= 7; dow++) {
      final revenues = revenueByDow[dow] ?? [];
      final orders = ordersByDow[dow] ?? [];

      if (revenues.isEmpty) {
        predictions.add(DayOfWeekPrediction(
          weekday: dow,
          dayName: dayNames[dow],
          predictedRevenue: 0,
          predictedOrders: 0,
          isBestDay: false,
          isWorstDay: false,
        ));
        continue;
      }

      // Weighted average (more recent = higher weight)
      double weightedRevSum = 0;
      double weightedOrdSum = 0;
      double weightSum = 0;

      for (var i = 0; i < revenues.length; i++) {
        final weight = (i + 1).toDouble();
        weightedRevSum += revenues[i] * weight;
        weightedOrdSum += orders[i] * weight;
        weightSum += weight;
      }

      final predRev = weightSum > 0 ? weightedRevSum / weightSum : 0.0;
      final predOrd = weightSum > 0 ? (weightedOrdSum / weightSum).round() : 0;

      if (predRev > maxRevenue) {
        maxRevenue = predRev;
        bestDow = dow;
      }
      if (predRev < minRevenue) {
        minRevenue = predRev;
        worstDow = dow;
      }

      predictions.add(DayOfWeekPrediction(
        weekday: dow,
        dayName: dayNames[dow],
        predictedRevenue: predRev,
        predictedOrders: predOrd,
        isBestDay: false,
        isWorstDay: false,
      ));
    }

    // Mark best and worst
    return predictions.map((p) {
      return DayOfWeekPrediction(
        weekday: p.weekday,
        dayName: p.dayName,
        predictedRevenue: p.predictedRevenue,
        predictedOrders: p.predictedOrders,
        isBestDay: p.weekday == bestDow,
        isWorstDay: p.weekday == worstDow,
      );
    }).toList();
  }

  // ─── 7. Build Summary ─────────────────────────────────────────────
  PredictionSummary buildSummary({
    required List<DailySalesPoint> historical,
    required List<PredictionPoint> predictions,
    required List<RestockSuggestion> restockSuggestions,
    required List<DayOfWeekPrediction> dowPredictions,
  }) {
    // Predicted revenue next week
    final predictedRevenue =
        predictions.fold<double>(0, (sum, p) => sum + p.value);

    // Average daily revenue from historical
    final historicalTotal =
        historical.fold<double>(0, (sum, d) => sum + d.totalSales);
    final avgDaily =
        historical.isNotEmpty ? historicalTotal / historical.length : 0;
    final lastWeekRevenue = avgDaily * 7;

    // Growth percent
    final growthPercent = lastWeekRevenue > 0
        ? ((predictedRevenue - lastWeekRevenue) / lastWeekRevenue) * 100
        : 0.0;

    // Products needing restock
    final restockCount = restockSuggestions
        .where((s) => s.urgency == 'critical' || s.urgency == 'warning')
        .length;

    // Best/worst day
    final bestDay = dowPredictions.firstWhere(
      (d) => d.isBestDay,
      orElse: () => DayOfWeekPrediction(
        weekday: 1,
        dayName: '-',
        predictedRevenue: 0,
        predictedOrders: 0,
        isBestDay: true,
        isWorstDay: false,
      ),
    );
    final worstDay = dowPredictions.firstWhere(
      (d) => d.isWorstDay,
      orElse: () => DayOfWeekPrediction(
        weekday: 1,
        dayName: '-',
        predictedRevenue: 0,
        predictedOrders: 0,
        isBestDay: false,
        isWorstDay: true,
      ),
    );

    // Confidence score based on data quantity
    final dataPoints = historical.length;
    final nonZeroDays = historical.where((d) => d.totalSales > 0).length;
    final confidence =
        min(100.0, (nonZeroDays / max(1, dataPoints)) * 100 * 0.8 + 20);

    return PredictionSummary(
      predictedRevenueNextWeek: predictedRevenue,
      revenueGrowthPercent: growthPercent,
      productsNeedingRestock: restockCount,
      bestDayName: bestDay.dayName,
      worstDayName: worstDay.dayName,
      avgDailyRevenue: avgDaily.toDouble(),
      confidenceScore: confidence,
    );
  }
}

// ─── Private Aggregation Helpers ──────────────────────────────────

class _DayAgg {
  double totalSales;
  int orderCount;

  _DayAgg({required this.totalSales, required this.orderCount});
}

class _ProductDayAgg {
  int qty;
  double revenue;

  _ProductDayAgg({required this.qty, required this.revenue});
}
