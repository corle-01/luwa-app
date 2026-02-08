import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseOrderItemModel {
  final String id;
  final String poId;
  final String ingredientId;
  final String ingredientName;
  final double quantity;
  final String unit;
  final double unitCost;
  final double totalCost;
  final double receivedQuantity;
  final DateTime? createdAt;

  PurchaseOrderItemModel({
    required this.id,
    required this.poId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.unitCost = 0,
    this.totalCost = 0,
    this.receivedQuantity = 0,
    this.createdAt,
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      id: json['id'] as String,
      poId: json['po_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      ingredientName: json['ingredient_name'] as String? ?? '',
      quantity: _toDouble(json['quantity']),
      unit: json['unit'] as String? ?? 'pcs',
      unitCost: _toDouble(json['unit_cost']),
      totalCost: _toDouble(json['total_cost']),
      receivedQuantity: _toDouble(json['received_quantity']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class PurchaseOrderModel {
  final String id;
  final String outletId;
  final String supplierId;
  final String poNumber;
  final String status;
  final DateTime? orderDate;
  final DateTime? expectedDate;
  final DateTime? receivedDate;
  final double totalAmount;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? supplierName;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    required this.id,
    required this.outletId,
    required this.supplierId,
    required this.poNumber,
    required this.status,
    this.orderDate,
    this.expectedDate,
    this.receivedDate,
    this.totalAmount = 0,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.supplierName,
    this.items = const [],
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json,
      {List<PurchaseOrderItemModel>? items}) {
    return PurchaseOrderModel(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      supplierId: json['supplier_id'] as String,
      poNumber: json['po_number'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'] as String)
          : null,
      expectedDate: json['expected_date'] != null
          ? DateTime.parse(json['expected_date'] as String)
          : null,
      receivedDate: json['received_date'] != null
          ? DateTime.parse(json['received_date'] as String)
          : null,
      totalAmount: PurchaseOrderItemModel._toDouble(json['total_amount']),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      supplierName: json['suppliers'] != null
          ? (json['suppliers'] as Map<String, dynamic>)['name'] as String?
          : null,
      items: items ?? [],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'ordered':
        return 'Dipesan';
      case 'partial':
        return 'Sebagian';
      case 'received':
        return 'Diterima';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}

class PurchaseOrderRepository {
  final _supabase = Supabase.instance.client;

  Future<List<PurchaseOrderModel>> getPurchaseOrders(String outletId) async {
    final response = await _supabase
        .from('purchase_orders')
        .select('*, suppliers(name)')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PurchaseOrderModel.fromJson(json))
        .toList();
  }

  Future<PurchaseOrderModel> getPurchaseOrder(String id) async {
    final poResponse = await _supabase
        .from('purchase_orders')
        .select('*, suppliers(name)')
        .eq('id', id)
        .single();

    final itemsResponse = await _supabase
        .from('purchase_order_items')
        .select()
        .eq('po_id', id)
        .order('created_at', ascending: true);

    final items = (itemsResponse as List)
        .map((json) => PurchaseOrderItemModel.fromJson(json))
        .toList();

    return PurchaseOrderModel.fromJson(poResponse, items: items);
  }

  Future<String> generatePoNumber(String outletId) async {
    final response = await _supabase
        .rpc('generate_po_number', params: {'p_outlet_id': outletId});
    return response as String;
  }

  Future<PurchaseOrderModel> createPurchaseOrder({
    required String outletId,
    required String supplierId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? createdBy,
    DateTime? expectedDate,
  }) async {
    // Generate PO number
    final poNumber = await generatePoNumber(outletId);

    // Calculate total
    double totalAmount = 0;
    for (final item in items) {
      final qty = PurchaseOrderItemModel._toDouble(item['quantity']);
      final cost = PurchaseOrderItemModel._toDouble(item['unit_cost']);
      totalAmount += qty * cost;
    }

    // Insert PO
    final poResponse = await _supabase
        .from('purchase_orders')
        .insert({
          'outlet_id': outletId,
          'supplier_id': supplierId,
          'po_number': poNumber,
          'status': 'draft',
          'total_amount': totalAmount,
          'notes': notes,
          'created_by': createdBy,
          'expected_date': expectedDate?.toIso8601String(),
        })
        .select('*, suppliers(name)')
        .single();

    final poId = poResponse['id'] as String;

    // Insert items
    final itemInserts = items.map((item) {
      final qty = PurchaseOrderItemModel._toDouble(item['quantity']);
      final cost = PurchaseOrderItemModel._toDouble(item['unit_cost']);
      return {
        'po_id': poId,
        'ingredient_id': item['ingredient_id'],
        'ingredient_name': item['ingredient_name'],
        'quantity': qty,
        'unit': item['unit'],
        'unit_cost': cost,
        'total_cost': qty * cost,
      };
    }).toList();

    await _supabase.from('purchase_order_items').insert(itemInserts);

    return PurchaseOrderModel.fromJson(poResponse);
  }

  Future<void> updatePOStatus(String id, String status) async {
    final data = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status == 'received') {
      data['received_date'] = DateTime.now().toIso8601String();
    }

    await _supabase
        .from('purchase_orders')
        .update(data)
        .eq('id', id);
  }

  Future<void> receivePO(
    String poId,
    String outletId,
    List<Map<String, dynamic>> receivedItems,
  ) async {
    // Update each PO item's received_quantity
    for (final item in receivedItems) {
      final itemId = item['id'] as String;
      final receivedQty = PurchaseOrderItemModel._toDouble(item['received_quantity']);

      await _supabase
          .from('purchase_order_items')
          .update({'received_quantity': receivedQty})
          .eq('id', itemId);

      // Add stock movement for each received item
      if (receivedQty > 0) {
        final ingredientId = item['ingredient_id'] as String;

        // Insert stock_movement
        await _supabase.from('stock_movements').insert({
          'ingredient_id': ingredientId,
          'movement_type': 'purchase',
          'quantity': receivedQty,
          'notes': 'Penerimaan PO',
        });

        // Update ingredient current_stock
        final current = await _supabase
            .from('ingredients')
            .select('current_stock')
            .eq('id', ingredientId)
            .single();

        final currentStock = PurchaseOrderItemModel._toDouble(current['current_stock']);
        final newStock = currentStock + receivedQty;

        await _supabase
            .from('ingredients')
            .update({
              'current_stock': newStock,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', ingredientId);
      }
    }

    // Check if all items fully received or partial
    final allItems = await _supabase
        .from('purchase_order_items')
        .select()
        .eq('po_id', poId);

    bool allReceived = true;
    bool anyReceived = false;

    for (final item in allItems as List) {
      final qty = PurchaseOrderItemModel._toDouble(item['quantity']);
      final recvQty = PurchaseOrderItemModel._toDouble(item['received_quantity']);
      if (recvQty >= qty) {
        anyReceived = true;
      } else if (recvQty > 0) {
        anyReceived = true;
        allReceived = false;
      } else {
        allReceived = false;
      }
    }

    final newStatus = allReceived ? 'received' : (anyReceived ? 'partial' : 'draft');
    await updatePOStatus(poId, newStatus);
  }

  Future<void> deletePO(String id) async {
    // Only delete if draft - items cascade-delete automatically
    await _supabase
        .from('purchase_orders')
        .delete()
        .eq('id', id)
        .eq('status', 'draft');
  }
}
