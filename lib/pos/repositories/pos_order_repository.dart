import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/order.dart';

class PosOrderRepository {
  final _supabase = Supabase.instance.client;

  /// Creates an order as 'pending', inserts items, then updates to 'completed'.
  /// This ensures DB triggers (deduct_stock, update_shift, update_customer) fire correctly.
  Future<Order> createOrder({
    required String outletId,
    required String shiftId,
    required String cashierId,
    required String orderType,
    required String paymentMethod,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double serviceChargeAmount,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    double? amountPaid,
    double? changeAmount,
    String? discountId,
    String? customerId,
    String? tableId,
    String? notes,
  }) async {
    // Generate order number
    String orderNumber;
    try {
      final result = await _supabase.rpc('generate_order_number', params: {'p_outlet_id': outletId});
      orderNumber = result as String? ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Step 1: INSERT as 'pending'
    final orderResponse = await _supabase
        .from('orders')
        .insert({
          'outlet_id': outletId,
          'order_number': orderNumber,
          'shift_id': shiftId,
          'cashier_id': cashierId,
          'customer_id': customerId,
          'order_type': orderType,
          'table_id': tableId,
          'status': 'pending',
          'payment_method': paymentMethod,
          'payment_status': 'unpaid',
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'discount_id': discountId,
          'tax_amount': taxAmount,
          'service_charge_amount': serviceChargeAmount,
          'total': totalAmount,
          'amount_paid': amountPaid ?? totalAmount,
          'change_amount': changeAmount ?? 0,
          'notes': notes,
        })
        .select()
        .single();

    final orderId = orderResponse['id'] as String;

    // Step 2: Insert order items
    final orderItems = items.map((item) => {
      ...item,
      'order_id': orderId,
    }).toList();

    await _supabase.from('order_items').insert(orderItems);

    // Step 3: UPDATE to 'completed' — triggers fire on this transition
    final completedResponse = await _supabase
        .from('orders')
        .update({
          'status': 'completed',
          'payment_status': 'paid',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId)
        .select()
        .single();

    return Order.fromJson(completedResponse);
  }

  Future<List<Order>> getOrders({
    required String outletId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? paymentMethod,
    String? searchQuery,
  }) async {
    var query = _supabase
        .from('orders')
        .select()
        .eq('outlet_id', outletId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      query = query.lte('created_at', endOfDay.toIso8601String());
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      query = query.eq('payment_method', paymentMethod);
    }

    final response = await query.order('created_at', ascending: false);

    List<Order> orders = (response as List).map((json) => Order.fromJson(json)).toList();

    // Client-side search filter for order number
    if (searchQuery != null && searchQuery.isNotEmpty) {
      orders = orders.where((o) =>
        (o.orderNumber ?? o.id).toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }

    return orders;
  }

  Future<List<Order>> getTodayOrders(String outletId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final response = await _supabase
        .from('orders')
        .select()
        .eq('outlet_id', outletId)
        .gte('created_at', startOfDay.toIso8601String())
        .order('created_at', ascending: false);

    return (response as List).map((json) => Order.fromJson(json)).toList();
  }

  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final response = await _supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return (response as List).map((json) => OrderItem.fromJson(json)).toList();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase
        .from('orders')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', orderId);
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _supabase
        .from('orders')
        .update({
          'status': 'cancelled',
          'notes': reason,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }
}
