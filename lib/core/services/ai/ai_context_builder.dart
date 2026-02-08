import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:utter_app/core/config/app_constants.dart';
import 'package:utter_app/core/repositories/ai_insight_repository.dart';

/// Builds context data for AI conversations.
///
/// Gathers relevant business data from the outlet to provide the AI
/// with current state information. This includes outlet details, current
/// shift data, sales summaries, stock alerts, and active insights.
class AiContextBuilder {
  final SupabaseClient _client;
  final AiInsightRepository _insightRepo;

  AiContextBuilder({
    SupabaseClient? client,
    AiInsightRepository? insightRepo,
  })  : _client = client ?? Supabase.instance.client,
        _insightRepo = insightRepo ?? AiInsightRepository();

  /// Build a comprehensive context object for the AI.
  ///
  /// Gathers data from multiple sources to provide the AI with a
  /// snapshot of the outlet's current state. All queries are executed
  /// concurrently for performance.
  Future<Map<String, dynamic>> buildContext(String outletId) async {
    // Execute all context queries concurrently
    final results = await Future.wait([
      _getOutletInfo(outletId),
      _getCurrentShift(outletId),
      _getTodaysSalesSummary(outletId),
      _getLowStockCount(outletId),
      _getActiveInsightCount(outletId),
    ]);

    final outletInfo = results[0] as Map<String, dynamic>?;
    final currentShift = results[1] as Map<String, dynamic>?;
    final salesSummary = results[2] as Map<String, dynamic>;
    final lowStockCount = results[3] as int;
    final activeInsightCount = results[4] as int;

    return {
      'outlet': outletInfo,
      'current_shift': currentShift,
      'today_sales': salesSummary,
      'low_stock_count': lowStockCount,
      'active_insights_count': activeInsightCount,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Get basic outlet information.
  Future<Map<String, dynamic>?> _getOutletInfo(String outletId) async {
    try {
      final response = await _client
          .from(AppConstants.tableOutlets)
          .select('id, name, address, phone, timezone, currency')
          .eq('id', outletId)
          .maybeSingle();

      return response != null
          ? Map<String, dynamic>.from(response)
          : null;
    } catch (e) {
      // Return null if outlet info cannot be fetched
      return null;
    }
  }

  /// Get the current active shift for the outlet.
  Future<Map<String, dynamic>?> _getCurrentShift(String outletId) async {
    try {
      final response = await _client
          .from(AppConstants.tableShifts)
          .select('id, started_at, cashier_id, opening_balance')
          .eq('outlet_id', outletId)
          .isFilter('ended_at', null)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response != null
          ? Map<String, dynamic>.from(response)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// Get today's sales summary.
  Future<Map<String, dynamic>> _getTodaysSalesSummary(
    String outletId,
  ) async {
    try {
      final today = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(today.year, today.month, today.day)
          .toIso8601String();

      final response = await _client
          .from(AppConstants.tableOrders)
          .select('id, total_amount, status')
          .eq('outlet_id', outletId)
          .gte('created_at', startOfDay)
          .inFilter('status', [
        AppConstants.orderStatusCompleted,
        AppConstants.orderStatusReady,
      ]);

      final orders = response as List;
      double totalRevenue = 0;
      int completedOrders = 0;

      for (final order in orders) {
        final amount = order['total_amount'];
        if (amount != null) {
          totalRevenue += (amount is int) ? amount.toDouble() : (amount as double);
        }
        if (order['status'] == AppConstants.orderStatusCompleted) {
          completedOrders++;
        }
      }

      return {
        'total_orders': orders.length,
        'completed_orders': completedOrders,
        'total_revenue': totalRevenue,
      };
    } catch (e) {
      return {
        'total_orders': 0,
        'completed_orders': 0,
        'total_revenue': 0.0,
      };
    }
  }

  /// Get the count of ingredients with low stock.
  Future<int> _getLowStockCount(String outletId) async {
    try {
      // Ingredients where current_stock <= min_stock
      final response = await _client
          .from(AppConstants.tableIngredients)
          .select('id, current_stock, min_stock')
          .eq('outlet_id', outletId);

      final ingredients = response as List;
      int lowCount = 0;

      for (final item in ingredients) {
        final currentStock = item['current_stock'] as num? ?? 0;
        final minStock = item['min_stock'] as num? ?? 0;
        if (currentStock <= minStock) {
          lowCount++;
        }
      }

      return lowCount;
    } catch (e) {
      return 0;
    }
  }

  /// Get the count of active AI insights.
  Future<int> _getActiveInsightCount(String outletId) async {
    try {
      return await _insightRepo.getInsightCount(outletId);
    } catch (e) {
      return 0;
    }
  }
}
