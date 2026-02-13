import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:luwa_app/core/config/app_constants.dart';
import 'package:luwa_app/core/repositories/ai_insight_repository.dart';
import 'package:luwa_app/core/services/ai/ai_memory_service.dart';
import 'package:luwa_app/core/services/ai/ai_prediction_service.dart';
import 'package:luwa_app/core/utils/date_utils.dart';

/// Builds rich context data for AI conversations.
///
/// Integrates the three AI personas:
/// - Memory: Business insights from past conversations
/// - Action Center: Real-time business data for action decisions
/// - Business Intelligence: Business mood and forecasts
class AiContextBuilder {
  final SupabaseClient _client;
  final AiInsightRepository _insightRepo;
  final AiMemoryService _memoryService;
  final AiPredictionService _predictionService;

  AiContextBuilder({
    SupabaseClient? client,
    AiInsightRepository? insightRepo,
    AiMemoryService? memoryService,
    AiPredictionService? predictionService,
    String outletId = 'a0000000-0000-0000-0000-000000000001',
  })  : _client = client ?? Supabase.instance.client,
        _insightRepo = insightRepo ?? AiInsightRepository(),
        _memoryService = memoryService ?? AiMemoryService(),
        _predictionService = predictionService ?? AiPredictionService(outletId: outletId);

  Future<Map<String, dynamic>> buildContext(String outletId) async {
    final results = await Future.wait([
      _getOutletInfo(outletId),
      _getCurrentShift(outletId),
      _getRecentOrders(outletId),
      _getTopProducts(outletId),
      _getLowStockItems(outletId),
      _getActiveInsightCount(outletId),
      _predictionService.assessBusinessMood(),
      _predictionService.generatePredictions(),
      _getOperationalCosts(outletId),
      _getComparativeMetrics(outletId), // NEW: WoW comparison
      _getProfitMargins(outletId), // NEW: Profit analysis
      _getCustomerSegmentation(outletId), // NEW: Customer insights
      _getHourlyPatterns(outletId), // NEW: Hourly patterns
    ]);

    // Build memory context from Memory persona
    final memoryContext = _memoryService.buildMemoryContext();

    // Cast prediction results
    final mood = results[6] as BusinessMoodData;
    final prediction = results[7] as BusinessPrediction;
    final opCosts = results[8] as Map<String, dynamic>;
    final comparative = results[9] as Map<String, dynamic>;
    final profitMargins = results[10] as Map<String, dynamic>;
    final customerSegments = results[11] as Map<String, dynamic>;
    final hourlyPatterns = results[12] as Map<String, dynamic>;

    return {
      'outlet': results[0],
      'current_shift': results[1],
      'recent_orders': results[2],
      'top_products': results[3],
      'low_stock_items': results[4],
      'active_insights_count': results[5],
      'timestamp': DateTime.now().toIso8601String(),
      // Memory persona context
      'ai_memories': memoryContext,
      // Business Intelligence persona context
      'business_mood': {
        'mood': mood.moodEmoji,
        'text': mood.moodText,
        'today_revenue': mood.todayRevenue,
        'today_orders': mood.todayOrders,
        'projected_revenue': mood.projectedRevenue,
        'avg_daily_revenue': mood.avgDailyRevenue,
        'avg_daily_orders': mood.avgDailyOrders,
        'warnings': mood.warnings,
      },
      'predictions': {
        'busy_hours': prediction.predictedBusyHours,
        'estimated_revenue': prediction.estimatedRevenue,
        'stock_warnings': prediction.stockWarnings,
        'forecast': prediction.forecastText,
        'day_type': prediction.dayType,
      },
      // Operational costs & bonus
      'operational_costs': opCosts,
      // NEW: Deep analytics
      'comparative_metrics': comparative,
      'profit_margins': profitMargins,
      'customer_segmentation': customerSegments,
      'hourly_patterns': hourlyPatterns,
    };
  }

  Future<Map<String, dynamic>?> _getOutletInfo(String outletId) async {
    try {
      return await _client
          .from(AppConstants.tableOutlets)
          .select('id, name, address, phone')
          .eq('id', outletId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getCurrentShift(String outletId) async {
    try {
      return await _client
          .from(AppConstants.tableShifts)
          .select('id, started_at, opening_balance')
          .eq('outlet_id', outletId)
          .isFilter('ended_at', null)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Get recent orders with item details - the core data AI needs
  Future<Map<String, dynamic>> _getRecentOrders(String outletId) async {
    try {
      // Get today's orders with items
      final orders = await _client
          .from(AppConstants.tableOrders)
          .select('id, order_number, status, payment_method, total, subtotal, tax_amount, discount_amount, created_at, order_items(product_name, quantity, unit_price, subtotal)')
          .eq('outlet_id', outletId)
          .gte('created_at', DateTimeUtils.startOfTodayUtc())
          .order('created_at', ascending: false)
          .limit(20);

      final orderList = List<Map<String, dynamic>>.from(orders);

      // Calculate summary
      double totalRevenue = 0;
      int completedCount = 0;
      final paymentBreakdown = <String, int>{};

      for (final o in orderList) {
        final total = (o['total'] as num?)?.toDouble() ?? 0;
        if (o['status'] == 'completed') {
          totalRevenue += total;
          completedCount++;
        }
        final pm = o['payment_method']?.toString() ?? 'unknown';
        paymentBreakdown[pm] = (paymentBreakdown[pm] ?? 0) + 1;
      }

      // Build order summaries (compact for AI context)
      final orderSummaries = orderList.map((o) {
        final items = (o['order_items'] as List?)
            ?.map((i) => '${i['product_name']} x${i['quantity']}')
            .join(', ') ?? '';
        return {
          'order_number': o['order_number'],
          'status': o['status'],
          'total': o['total'],
          'payment': o['payment_method'],
          'items': items,
          'time': o['created_at'],
        };
      }).toList();

      return {
        'today_total_orders': orderList.length,
        'today_completed': completedCount,
        'today_revenue': totalRevenue,
        'payment_breakdown': paymentBreakdown,
        'orders': orderSummaries,
      };
    } catch (_) {
      return {
        'today_total_orders': 0,
        'today_completed': 0,
        'today_revenue': 0.0,
        'orders': [],
      };
    }
  }

  /// Get top selling products (last 7 days)
  Future<List<Map<String, dynamic>>> _getTopProducts(String outletId) async {
    try {
      final weekAgo = DateTimeUtils.toUtcIso(DateTime.now().subtract(const Duration(days: 7)));

      final items = await _client
          .from('order_items')
          .select('product_name, quantity, subtotal, orders!inner(outlet_id, status, created_at)')
          .eq('orders.outlet_id', outletId)
          .eq('orders.status', 'completed')
          .gte('orders.created_at', weekAgo);

      // Aggregate by product
      final productMap = <String, Map<String, dynamic>>{};
      for (final item in List<Map<String, dynamic>>.from(items)) {
        final name = item['product_name']?.toString() ?? 'Unknown';
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final sub = (item['subtotal'] as num?)?.toDouble() ?? 0;
        productMap.putIfAbsent(name, () => {'name': name, 'qty': 0, 'revenue': 0.0});
        productMap[name]!['qty'] = (productMap[name]!['qty'] as int) + qty;
        productMap[name]!['revenue'] = (productMap[name]!['revenue'] as double) + sub;
      }

      final sorted = productMap.values.toList()
        ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
      return sorted.take(10).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get low stock items with names
  Future<List<Map<String, dynamic>>> _getLowStockItems(String outletId) async {
    try {
      final response = await _client
          .from(AppConstants.tableIngredients)
          .select('name, current_stock, min_stock, unit')
          .eq('outlet_id', outletId);

      final items = List<Map<String, dynamic>>.from(response);
      final lowStock = items.where((i) {
        final current = (i['current_stock'] as num?)?.toDouble() ?? 0;
        final min = (i['min_stock'] as num?)?.toDouble() ?? 0;
        return current <= min;
      }).toList();

      return lowStock;
    } catch (_) {
      return [];
    }
  }

  Future<int> _getActiveInsightCount(String outletId) async {
    try {
      return await _insightRepo.getInsightCount(outletId);
    } catch (_) {
      return 0;
    }
  }

  /// Get operational costs + bonus percentage for HPP context
  Future<Map<String, dynamic>> _getOperationalCosts(String outletId) async {
    try {
      final response = await _client
          .from('operational_costs')
          .select('category, name, amount')
          .eq('outlet_id', outletId)
          .eq('is_active', true);

      final items = List<Map<String, dynamic>>.from(response);

      double totalOperational = 0;
      double totalLabor = 0;
      double bonusPercent = 0;
      final details = <Map<String, dynamic>>[];

      for (final item in items) {
        final cat = item['category']?.toString() ?? '';
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        if (cat == 'bonus') {
          bonusPercent = amount;
        } else {
          if (cat == 'operational') totalOperational += amount;
          if (cat == 'labor') totalLabor += amount;
          details.add({
            'name': item['name'],
            'category': cat,
            'amount': amount,
          });
        }
      }

      return {
        'total_monthly': totalOperational + totalLabor,
        'operational': totalOperational,
        'labor': totalLabor,
        'bonus_percent': bonusPercent,
        'items': details,
      };
    } catch (_) {
      return {
        'total_monthly': 0,
        'operational': 0,
        'labor': 0,
        'bonus_percent': 0,
        'items': [],
      };
    }
  }

  /// Get Week-over-Week comparative metrics using RPC function
  Future<Map<String, dynamic>> _getComparativeMetrics(String outletId) async {
    try {
      final result = await _client.rpc('compare_period_performance', params: {
        'p_outlet_id': outletId,
        'p_current_days': 7,
        'p_comparison_days': 7,
      });

      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return {
        'current_period': {},
        'previous_period': {},
        'trend': 'INSUFFICIENT_DATA',
      };
    }
  }

  /// Get profit margins and profitability analysis from view
  Future<Map<String, dynamic>> _getProfitMargins(String outletId) async {
    try {
      final products = await _client
          .from('v_product_performance')
          .select('product_name, total_revenue, total_profit, profit_margin_pct, total_quantity_sold')
          .eq('outlet_id', outletId)
          .order('total_profit', ascending: false)
          .limit(10);

      final productList = List<Map<String, dynamic>>.from(products);

      double totalRevenue = 0;
      double totalProfit = 0;

      for (final p in productList) {
        totalRevenue += (p['total_revenue'] as num?)?.toDouble() ?? 0;
        totalProfit += (p['total_profit'] as num?)?.toDouble() ?? 0;
      }

      return {
        'top_products': productList,
        'total_revenue': totalRevenue,
        'total_profit': totalProfit,
        'overall_margin_pct': totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0,
      };
    } catch (_) {
      return {
        'top_products': [],
        'total_revenue': 0,
        'total_profit': 0,
        'overall_margin_pct': 0,
      };
    }
  }

  /// Get customer segmentation insights from RPC function
  Future<Map<String, dynamic>> _getCustomerSegmentation(String outletId) async {
    try {
      final result = await _client.rpc('get_customer_insights', params: {
        'p_outlet_id': outletId,
        'p_days_back': 90,
      });

      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return {
        'total_customers': 0,
        'vip_customers': 0,
        'loyal_customers': 0,
        'repeat_customers': 0,
        'new_customers': 0,
        'top_customers': [],
      };
    }
  }

  /// Get hourly revenue patterns from view (last 90 days)
  Future<Map<String, dynamic>> _getHourlyPatterns(String outletId) async {
    try {
      final patterns = await _client
          .from('v_hourly_revenue_pattern')
          .select('hour_of_day, day_of_week, order_count, revenue')
          .eq('outlet_id', outletId)
          .order('revenue', ascending: false)
          .limit(20);

      final patternList = List<Map<String, dynamic>>.from(patterns);

      // Find peak hours
      final Map<int, double> hourlyRevenue = {};
      for (final p in patternList) {
        final hour = (p['hour_of_day'] as num?)?.toInt() ?? 0;
        final revenue = (p['revenue'] as num?)?.toDouble() ?? 0;
        hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) + revenue;
      }

      final sortedHours = hourlyRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final peakHours = sortedHours.take(5).map((e) => e.key).toList();

      return {
        'patterns': patternList,
        'peak_hours': peakHours,
        'total_data_points': patternList.length,
      };
    } catch (_) {
      return {
        'patterns': [],
        'peak_hours': [],
        'total_data_points': 0,
      };
    }
  }
}
