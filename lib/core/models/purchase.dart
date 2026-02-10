import 'package:flutter/foundation.dart';

class Purchase {
  final String id;
  final String outletId;
  final String? supplierId;
  final String supplierName;
  final String picName;
  final String paymentSource; // 'kas_kasir' | 'uang_luar'
  final String? paymentDetail;
  final String? shiftId;
  final String? receiptImageUrl;
  final double totalAmount;
  final String? notes;
  final DateTime purchaseDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<PurchaseItem> items;

  const Purchase({
    required this.id,
    required this.outletId,
    this.supplierId,
    required this.supplierName,
    required this.picName,
    required this.paymentSource,
    this.paymentDetail,
    this.shiftId,
    this.receiptImageUrl,
    required this.totalAmount,
    this.notes,
    required this.purchaseDate,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Purchase.fromJson(Map<String, dynamic> json, {List<PurchaseItem>? items}) {
    return Purchase(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String? ?? '',
      picName: json['pic_name'] as String? ?? '',
      paymentSource: json['payment_source'] as String? ?? 'kas_kasir',
      paymentDetail: json['payment_detail'] as String?,
      shiftId: json['shift_id'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      purchaseDate: DateTime.tryParse(json['purchase_date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      items: items ?? [],
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'outlet_id': outletId,
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'pic_name': picName,
    'payment_source': paymentSource,
    'payment_detail': paymentDetail,
    'shift_id': shiftId,
    'receipt_image_url': receiptImageUrl,
    'total_amount': totalAmount,
    'notes': notes,
    'purchase_date': purchaseDate.toIso8601String().split('T')[0],
  };
}

class PurchaseItem {
  final String id;
  final String purchaseId;
  final String? ingredientId;
  final String itemName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    this.ingredientId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      ingredientId: json['ingredient_id'] as String?,
      itemName: json['item_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'pcs',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson(String purchaseId) => {
    'purchase_id': purchaseId,
    'ingredient_id': ingredientId,
    'item_name': itemName,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'total_price': totalPrice,
  };
}

class PurchaseStats {
  final double totalAmount;
  final double kasKasirAmount;
  final double uangLuarAmount;
  final int totalTransactions;

  const PurchaseStats({
    required this.totalAmount,
    required this.kasKasirAmount,
    required this.uangLuarAmount,
    required this.totalTransactions,
  });
}
