import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientModel {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;
  final double maxStock;
  final double costPerUnit;
  final String? supplierName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IngredientModel({
    required this.id,
    required this.name,
    required this.unit,
    this.currentStock = 0,
    this.minStock = 0,
    this.maxStock = 0,
    this.costPerUnit = 0,
    this.supplierName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    return IngredientModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'pcs',
      currentStock: _toDouble(json['current_stock']),
      minStock: _toDouble(json['min_stock']),
      maxStock: _toDouble(json['max_stock']),
      costPerUnit: _toDouble(json['cost_per_unit']),
      supplierName: json['suppliers'] != null
          ? (json['suppliers'] as Map<String, dynamic>)['name'] as String?
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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

  bool get isLowStock => currentStock <= minStock && currentStock > 0;

  bool get isOutOfStock => currentStock <= 0;

  double get stockPercentage {
    if (maxStock <= 0) return 0;
    return (currentStock / maxStock).clamp(0.0, 1.0);
  }

  double get stockValue => currentStock * costPerUnit;
}

class StockMovement {
  final String id;
  final String type;
  final double quantity;
  final String? notes;
  final String? ingredientName;
  final String? ingredientUnit;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.type,
    required this.quantity,
    this.notes,
    this.ingredientName,
    this.ingredientUnit,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'adjustment',
      quantity: IngredientModel._toDouble(json['quantity']),
      notes: json['notes'] as String?,
      ingredientName: json['ingredients'] != null
          ? (json['ingredients'] as Map<String, dynamic>)['name'] as String?
          : null,
      ingredientUnit: json['ingredients'] != null
          ? (json['ingredients'] as Map<String, dynamic>)['unit'] as String?
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'purchase':
        return 'Pembelian';
      case 'adjustment':
        return 'Penyesuaian';
      case 'waste':
        return 'Waste';
      case 'transfer':
        return 'Transfer';
      case 'production':
        return 'Produksi';
      default:
        return type;
    }
  }
}

class InventoryRepository {
  final _supabase = Supabase.instance.client;

  Future<List<IngredientModel>> getIngredients(String outletId) async {
    final response = await _supabase
        .from('ingredients')
        .select('*, suppliers(name)')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => IngredientModel.fromJson(json))
        .toList();
  }

  Future<List<StockMovement>> getRecentMovements(
    String outletId, {
    int limit = 20,
  }) async {
    final response = await _supabase
        .from('stock_movements')
        .select('*, ingredients(name, unit)')
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => StockMovement.fromJson(json))
        .toList();
  }

  Future<void> adjustStock({
    required String ingredientId,
    required String outletId,
    required double quantity,
    required String type,
    String? notes,
  }) async {
    // Insert stock movement record
    await _supabase.from('stock_movements').insert({
      'outlet_id': outletId,
      'ingredient_id': ingredientId,
      'type': type,
      'quantity': quantity,
      'notes': notes,
    });

    // Update current_stock on the ingredient
    // Fetch current stock first, then update
    final current = await _supabase
        .from('ingredients')
        .select('current_stock')
        .eq('id', ingredientId)
        .single();

    final currentStock = IngredientModel._toDouble(current['current_stock']);
    final newStock = currentStock + quantity;

    await _supabase
        .from('ingredients')
        .update({
          'current_stock': newStock < 0 ? 0 : newStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', ingredientId);
  }

  Future<void> updateIngredient(
    String id, {
    double? minStock,
    double? maxStock,
    double? costPerUnit,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (minStock != null) updates['min_stock'] = minStock;
    if (maxStock != null) updates['max_stock'] = maxStock;
    if (costPerUnit != null) updates['cost_per_unit'] = costPerUnit;

    await _supabase.from('ingredients').update(updates).eq('id', id);
  }
}
