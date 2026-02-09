import 'package:supabase_flutter/supabase_flutter.dart';

class SelfOrderRepository {
  final _client = Supabase.instance.client;

  /// Fetch active products with categories and images for outlet
  Future<List<Map<String, dynamic>>> getMenuProducts(String outletId) async {
    final res = await _client
        .from('products')
        .select('*, categories(*), product_images(*)')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetch categories for outlet
  Future<List<Map<String, dynamic>>> getCategories(String outletId) async {
    final res = await _client
        .from('categories')
        .select()
        .eq('outlet_id', outletId)
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetch modifier groups + options for a product
  /// Queries through junction table product_modifier_groups (same pattern as POS)
  Future<List<Map<String, dynamic>>> getModifierGroups(
      String productId) async {
    // Step 1: Get modifier group IDs linked to this product
    final junctionRes = await _client
        .from('product_modifier_groups')
        .select('modifier_group_id')
        .eq('product_id', productId);

    final groupIds = (junctionRes as List)
        .map((r) => r['modifier_group_id'] as String)
        .toList();

    if (groupIds.isEmpty) return [];

    // Step 2: Fetch full modifier groups with their options
    final res = await _client
        .from('modifier_groups')
        .select('*, modifier_options(*)')
        .inFilter('id', groupIds)
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Submit self-order: creates order + order_items.
  /// [paymentMethod] = 'cash' (bayar di kasir) or 'qris' (already paid via QRIS).
  /// Returns order ID.
  Future<String> submitOrder({
    required String outletId,
    required String tableId,
    required String orderType,
    required List<SelfOrderItem> items,
    String? customerNotes,
    String paymentMethod = 'cash',
  }) async {
    // Generate order number with SO- prefix for self-order
    final now = DateTime.now();
    final orderNumber =
        'SO-${now.millisecondsSinceEpoch.toString().substring(7)}';

    // Calculate subtotal from items
    double subtotal = 0;
    for (final item in items) {
      subtotal += item.totalPrice;
    }

    // Determine payment status based on method:
    // - qris: customer already paid → 'paid'
    // - cash: pay later at cashier → 'unpaid'
    final paymentStatus = paymentMethod == 'qris' ? 'paid' : 'unpaid';

    // Step 1: Insert order as 'pending'
    // DB triggers fire on UPDATE (pending -> completed), not on INSERT.
    final orderRes = await _client
        .from('orders')
        .insert({
          'outlet_id': outletId,
          'order_number': orderNumber,
          'order_type': orderType,
          'table_id': tableId,
          'status': 'pending',
          'payment_method': paymentMethod,
          'payment_status': paymentStatus,
          'subtotal': subtotal,
          'tax_amount': 0,
          'discount_amount': 0,
          'total': subtotal,
          'amount_paid': paymentMethod == 'qris' ? subtotal : 0,
          'notes': customerNotes,
          'source': 'self_order',
        })
        .select('id')
        .single();

    final orderId = orderRes['id'] as String;

    // Step 2: Insert order items
    final itemsData = items
        .map((item) => {
              'order_id': orderId,
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.totalPrice,
              'modifiers': item.modifiers,
              'notes': item.notes,
              'kitchen_status': 'pending',
            })
        .toList();

    await _client.from('order_items').insert(itemsData);

    // Step 3: Update table status to occupied
    await _client
        .from('tables')
        .update({
          'status': 'occupied',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tableId);

    return orderId;
  }

  /// Get order status for customer tracking
  Future<Map<String, dynamic>?> getOrderStatus(String orderId) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', orderId)
        .maybeSingle();
    return res;
  }

  /// Get table info by ID
  Future<Map<String, dynamic>?> getTableInfo(String tableId) async {
    final res = await _client
        .from('tables')
        .select()
        .eq('id', tableId)
        .maybeSingle();
    return res;
  }

  /// Get active orders for a table (for re-visiting tracking page)
  Future<List<Map<String, dynamic>>> getTableOrders(String tableId) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('table_id', tableId)
        .inFilter('status', ['pending', 'preparing', 'ready'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }
}

/// Self-order item model for the customer cart.
/// Simpler than the POS CartItem — no discount/tax logic,
/// just product + modifiers + quantity.
class SelfOrderItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final List<Map<String, dynamic>>? modifiers; // [{name, option, price}]
  final String? notes;
  final String? imageUrl;

  SelfOrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
    this.modifiers,
    this.notes,
    this.imageUrl,
  });

  /// Sum of all modifier price adjustments
  double get modifierTotal {
    if (modifiers == null || modifiers!.isEmpty) return 0;
    return modifiers!.fold(
        0.0, (sum, m) => sum + ((m['price'] as num?)?.toDouble() ?? 0));
  }

  /// Total price for this line item (unit + modifiers) * quantity
  double get totalPrice => (unitPrice + modifierTotal) * quantity;

  SelfOrderItem copyWith({
    String? productId,
    String? productName,
    double? unitPrice,
    int? quantity,
    List<Map<String, dynamic>>? modifiers,
    String? notes,
    String? imageUrl,
  }) {
    return SelfOrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Unique key for cart deduplication.
  /// Same product with different modifiers or notes = different cart line.
  String get cartKey {
    final modKey = modifiers
            ?.map((m) => '${m['name']}:${m['option']}')
            .join(',') ??
        '';
    return '$productId|$modKey|${notes ?? ''}';
  }
}
