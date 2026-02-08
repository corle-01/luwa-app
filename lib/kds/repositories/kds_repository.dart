import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kds_order.dart';

class KdsRepository {
  final _supabase = Supabase.instance.client;

  /// Get active kitchen orders for today.
  /// Returns completed (paid) orders whose kitchen_status is NOT 'served',
  /// ordered oldest-first (FIFO) so the kitchen prepares in order.
  Future<List<KdsOrder>> getActiveKitchenOrders(String outletId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // Get orders that are completed (paid) and kitchen_status is NOT 'served'
    final ordersResponse = await _supabase
        .from('orders')
        .select()
        .eq('outlet_id', outletId)
        .eq('status', 'completed')
        .neq('kitchen_status', 'served')
        .gte('created_at', startOfDay.toIso8601String())
        .order('created_at', ascending: true); // oldest first (FIFO)

    final orders = <KdsOrder>[];
    for (final orderJson in ordersResponse as List) {
      final orderId = orderJson['id'] as String;

      final itemsResponse = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      final items = (itemsResponse as List)
          .map((j) => KdsOrderItem.fromJson(j))
          .toList();

      orders.add(KdsOrder.fromJson(orderJson, items));
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
      updates['kitchen_started_at'] = DateTime.now().toIso8601String();
    } else if (status == 'ready') {
      updates['kitchen_completed_at'] = DateTime.now().toIso8601String();
    }
    await _supabase.from('order_items').update(updates).eq('id', itemId);
  }

  /// Mark all pending items in an order as 'cooking' (start all).
  Future<void> startAllItems(String orderId) async {
    await _supabase.from('order_items').update({
      'kitchen_status': 'cooking',
      'kitchen_started_at': DateTime.now().toIso8601String(),
    }).eq('order_id', orderId).eq('kitchen_status', 'pending');
  }

  /// Mark all non-ready items in an order as 'ready' (complete all).
  Future<void> completeAllItems(String orderId) async {
    await _supabase.from('order_items').update({
      'kitchen_status': 'ready',
      'kitchen_completed_at': DateTime.now().toIso8601String(),
    }).eq('order_id', orderId).neq('kitchen_status', 'ready');
  }

  /// Mark the entire order as served (removes from KDS view).
  Future<void> markOrderServed(String orderId) async {
    await _supabase.from('orders').update({
      'kitchen_status': 'served',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
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
