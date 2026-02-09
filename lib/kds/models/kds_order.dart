/// KDS (Kitchen Display System) order model.
/// Represents an order as seen by the kitchen, with per-item status tracking.
class KdsOrder {
  final String id;
  final String? orderNumber;
  final String orderType;
  final int? tableNumber;
  final String? customerName;
  final String kitchenStatus; // waiting, in_progress, ready, served
  final String? notes;
  final DateTime createdAt;
  final DateTime? kitchenCompletedAt;
  final List<KdsOrderItem> items;

  KdsOrder({
    required this.id,
    this.orderNumber,
    this.orderType = 'dine_in',
    this.tableNumber,
    this.customerName,
    this.kitchenStatus = 'waiting',
    this.notes,
    required this.createdAt,
    this.kitchenCompletedAt,
    this.items = const [],
  });

  factory KdsOrder.fromJson(Map<String, dynamic> json, List<KdsOrderItem> items) {
    return KdsOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String?,
      orderType: json['order_type'] as String? ?? 'dine_in',
      tableNumber: json['table_number'] is int
          ? json['table_number'] as int
          : int.tryParse(json['table_number']?.toString() ?? ''),
      customerName: json['customer_name'] as String?,
      kitchenStatus: json['kitchen_status'] as String? ?? 'waiting',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      kitchenCompletedAt: json['kitchen_completed_at'] != null
          ? DateTime.parse(json['kitchen_completed_at'] as String)
          : null,
      items: items,
    );
  }

  /// How long since the order was placed
  Duration get elapsedTime => DateTime.now().difference(createdAt);

  /// Order is considered overdue after 15 minutes
  bool get isOverdue => elapsedTime.inMinutes > 15;

  /// Number of items still waiting to be prepared
  int get pendingCount => items.where((i) => i.kitchenStatus == 'pending').length;

  /// Number of items currently being cooked
  int get cookingCount => items.where((i) => i.kitchenStatus == 'cooking').length;

  /// Number of items ready to serve
  int get readyCount => items.where((i) => i.kitchenStatus == 'ready').length;

  /// Display label for the order (order number or fallback)
  String get displayLabel => orderNumber ?? '#${id.substring(0, 6).toUpperCase()}';
}

/// A single item within a KDS order, with its own kitchen preparation status.
class KdsOrderItem {
  final String id;
  final String orderId;
  final String productName;
  final int quantity;
  final String kitchenStatus; // pending, cooking, ready
  final String? notes;
  final List<Map<String, dynamic>>? modifiers;
  final DateTime? kitchenStartedAt;
  final DateTime? kitchenCompletedAt;

  KdsOrderItem({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.quantity,
    this.kitchenStatus = 'pending',
    this.notes,
    this.modifiers,
    this.kitchenStartedAt,
    this.kitchenCompletedAt,
  });

  factory KdsOrderItem.fromJson(Map<String, dynamic> json) {
    return KdsOrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productName: json['product_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      kitchenStatus: json['kitchen_status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      modifiers: json['modifiers'] != null
          ? List<Map<String, dynamic>>.from(json['modifiers'])
          : null,
      kitchenStartedAt: json['kitchen_started_at'] != null
          ? DateTime.parse(json['kitchen_started_at'] as String)
          : null,
      kitchenCompletedAt: json['kitchen_completed_at'] != null
          ? DateTime.parse(json['kitchen_completed_at'] as String)
          : null,
    );
  }

  /// Whether this item has any modifier options
  bool get hasModifiers => modifiers != null && modifiers!.isNotEmpty;

  /// Formatted modifier list for display (e.g. "Extra Cheese, No Onion")
  String get modifierSummary {
    if (!hasModifiers) return '';
    return modifiers!
        .map((m) =>
            m['option_name'] as String? ??
            m['option'] as String? ??
            m['name'] as String? ??
            m['modifier_name'] as String? ??
            '')
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
}
