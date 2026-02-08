import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:utter_app/core/config/app_constants.dart';
import 'package:utter_app/core/repositories/ai_insight_repository.dart';
import 'package:utter_app/core/services/ai/ai_memory_service.dart';
import 'package:utter_app/core/services/ai/ai_prediction_service.dart';

/// Builds rich context data for AI conversations.
///
/// Integrates the three AI personas:
/// - OTAK (Memory): Business insights from past conversations
/// - BADAN (Action): Real-time business data for action decisions
/// - PERASAAN (Prediction): Business mood and forecasts
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
    ]);

    // Build memory context from OTAK
    final memoryContext = _memoryService.buildMemoryContext();

    // Cast prediction results
    final mood = results[6] as BusinessMoodData;
    final prediction = results[7] as BusinessPrediction;

    return {
      'outlet': results[0],
      'current_shift': results[1],
      'recent_orders': results[2],
      'top_products': results[3],
      'low_stock_items': results[4],
      'active_insights_count': results[5],
      'timestamp': DateTime.now().toIso8601String(),
      // OTAK persona context
      'ai_memories': memoryContext,
      // PERASAAN persona context
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
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

      // Get today's orders with items
      final orders = await _client
          .from(AppConstants.tableOrders)
          .select('id, order_number, status, payment_method, total, subtotal, tax_amount, discount_amount, created_at, order_items(product_name, quantity, unit_price, subtotal)')
          .eq('outlet_id', outletId)
          .gte('created_at', startOfDay)
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
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

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
}
