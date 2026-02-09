import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/date_utils.dart';
import '../models/kds_order.dart';

class KdsRepository {
  final _supabase = Supabase.instance.client;

  /// Get active kitchen orders for today.
  /// Returns completed (paid) orders whose kitchen_status is NOT 'served',
  /// ordered oldest-first (FIFO) so the kitchen prepares in order.
  Future<List<KdsOrder>> getActiveKitchenOrders(String outletId) async {
    // Get orders that are completed (paid) and kitchen_status is NOT 'served'
    // Single query with joins: orders + order_items + tables (fixes N+1 pattern)
    final ordersResponse = await _supabase
        .from('orders')
        .select('*, order_items(*), tables(table_number)')
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .neq('kitchen_status', 'served')
        .gte('created_at', DateTimeUtils.startOfTodayUtc())
        .order('created_at', ascending: true); // oldest first (FIFO)

    final orders = <KdsOrder>[];
    for (final orderJson in ordersResponse as List) {
      final itemsList = orderJson['order_items'] as List? ?? [];
      final items = itemsList
          .map((j) => KdsOrderItem.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      // Extract table_number from joined tables data
      final tableData = orderJson['tables'] as Map<String, dynamic>?;
      final enrichedJson = Map<String, dynamic>.from(orderJson);
      if (tableData != null) {
        enrichedJson['table_number'] = tableData['table_number'];
      }

      orders.add(KdsOrder.fromJson(enrichedJson, items));
    }

    return orders;
  }

  /// Update a single item's kitchen status.
  /// Sets kitchen_started_at when status becomes 'cooking',
  /// and kitchen_completed_at when status becomes 'ready'.
  /// The DB trigger will automatically update the parent order's kitchen_status.
  Future<void> updateItemStatus(String itemId, String status) async {
    final updates = <String, dynamic>{
      'kitchen_status': status,
    };
    if (status == 'cooking') {
      updates['kitchen_started_at'] = DateTimeUtils.nowUtc();
    } else if (status == 'ready') {
      updates['kitchen_completed_at'] = DateTimeUtils.nowUtc();
    }
    await _supabase.from('order_items').update(updates).eq('id', itemId);
  }

  /// Mark all pending items in an order as 'cooking' (start all).
  Future<void> startAllItems(String orderId) async {
    await _supabase.from('order_items').update({
      'kitchen_status': 'cooking',
      'kitchen_started_at': DateTimeUtils.nowUtc(),
    }).eq('order_id', orderId).eq('kitchen_status', 'pending');
  }

  /// Mark all non-ready items in an order as 'ready' (complete all).
  Future<void> completeAllItems(String orderId) async {
    await _supabase.from('order_items').update({
      'kitchen_status': 'ready',
      'kitchen_completed_at': DateTimeUtils.nowUtc(),
    }).eq('order_id', orderId).neq('kitchen_status', 'ready');
  }

  /// Mark the entire order as served (removes from KDS view).
  /// Also releases the table back to 'available' if it was a dine-in order.
  Future<void> markOrderServed(String orderId) async {
    // Parallel: read table_id AND update status at the same time
    final orderFuture = _supabase
        .from('orders')
        .select('table_id')
        .eq('id', orderId)
        .maybeSingle();
    final updateFuture = _supabase.from('orders').update({
      'kitchen_status': 'served',
      'updated_at': DateTimeUtils.nowUtc(),
    }).eq('id', orderId);
    final results = await Future.wait<dynamic>([orderFuture, updateFuture]);

    // Release table if this was a dine-in order
    final order = results[0] as Map<String, dynamic>?;
    final tableId = order?['table_id'] as String?;
    if (tableId != null) {
      // Only release if no other active orders on this table
      final otherOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('table_id', tableId)
          .inFilter('status', ['pending', 'completed'])
          .neq('kitchen_status', 'served')
          .neq('id', orderId)
          .limit(1);
      if ((otherOrders as List).isEmpty) {
        await _supabase.from('tables').update({
          'status': 'available',
          'updated_at': DateTimeUtils.nowUtc(),
        }).eq('id', tableId);
      }
    }
  }

  /// Recall an order: reset all items back to 'pending'.
  /// Useful if an order was marked ready by mistake.
  Future<void> recallOrder(String orderId) async {
    await _supabase.from('order_items').update({
      'kitchen_status': 'pending',
      'kitchen_started_at': null,
      'kitchen_completed_at': null,
    }).eq('order_id', orderId);
  }
}
