class Order {
  final String id;
  final String? orderNumber;
  final String? outletId;
  final String? shiftId;
  final String? cashierId;
  final String? customerId;
  final String? customerName;
  final String orderType;
  final String? tableId;
  final int? tableNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double serviceCharge;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OrderItem>? items;

  Order({
    required this.id,
    this.orderNumber,
    this.outletId,
    this.shiftId,
    this.cashierId,
    this.customerId,
    this.customerName,
    this.orderType = 'dine_in',
    this.tableId,
    this.tableNumber,
    this.status = 'completed',
    this.paymentMethod = 'cash',
    this.paymentStatus = 'paid',
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.serviceCharge = 0,
    this.totalAmount = 0,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String?,
      outletId: json['outlet_id'] as String?,
      shiftId: json['shift_id'] as String?,
      cashierId: json['cashier_id'] as String?,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      orderType: json['order_type'] as String? ?? 'dine_in',
      tableId: json['table_id'] as String?,
      tableNumber: json['table_number'] as int?,
      status: json['status'] as String? ?? 'completed',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'paid',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      serviceCharge: (json['service_charge_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'outlet_id': outletId,
    'shift_id': shiftId,
    'cashier_id': cashierId,
    'customer_id': customerId,
    'order_type': orderType,
    'table_id': tableId,
    'status': status,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'subtotal': subtotal,
    'discount_amount': discountAmount,
    'tax_amount': taxAmount,
    'service_charge_amount': serviceCharge,
    'total': totalAmount,
    'notes': notes,
  };
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;
  final List<Map<String, dynamic>>? modifiers;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
    this.modifiers,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      modifiers: json['modifiers'] != null ? List<Map<String, dynamic>>.from(json['modifiers']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'subtotal': totalPrice,
    'total': totalPrice,
    'notes': notes,
    'modifiers': modifiers,
  };
}
