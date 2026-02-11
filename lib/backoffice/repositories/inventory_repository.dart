import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/unit_converter.dart';

class IngredientModel {
  final String id;
  final String name;
  final String unit; // Display unit (for UI)
  final String baseUnit; // Storage unit (g, ml, or pcs)
  final String category;
  final double currentStock; // Always in base unit
  final double minStock; // Always in base unit
  final double maxStock; // Always in base unit
  final double costPerUnit; // Cost per display unit
  final String? supplierName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IngredientModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.baseUnit,
    this.category = 'makanan',
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
    final unit = json['unit'] as String? ?? 'pcs';
    return IngredientModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      unit: unit,
      baseUnit: json['base_unit'] as String? ?? UnitConverter.getBaseUnit(unit),
      category: json['category'] as String? ?? 'makanan',
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

  // ══════════════════════════════════════════════════════════════
  // Unit Conversion Helpers
  // ══════════════════════════════════════════════════════════════

  /// Get current stock in display unit
  double get currentStockInDisplayUnit {
    return UnitConverter.convert(
      value: currentStock,
      from: baseUnit,
      to: unit,
    ) ?? currentStock;
  }

  /// Get min stock in display unit
  double get minStockInDisplayUnit {
    return UnitConverter.convert(
      value: minStock,
      from: baseUnit,
      to: unit,
    ) ?? minStock;
  }

  /// Get max stock in display unit
  double get maxStockInDisplayUnit {
    return UnitConverter.convert(
      value: maxStock,
      from: baseUnit,
      to: unit,
    ) ?? maxStock;
  }

  /// Format current stock for display
  String get formattedStock {
    return UnitConverter.formatValue(currentStock, baseUnit);
  }

  /// Convert value from any unit to base unit
  double convertToBaseUnit(double value, String fromUnit) {
    final converted = UnitConverter.convert(
      value: value,
      from: fromUnit,
      to: baseUnit,
    );
    return converted ?? value;
  }
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
      type: json['movement_type'] as String? ?? json['type'] as String? ?? 'adjustment',
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
    String? inputUnit, // Unit used for input (optional)
  }) async {
    double finalQuantity = quantity;

    // If inputUnit is provided, convert to base unit
    if (inputUnit != null) {
      // Fetch ingredient to get base unit
      final response = await _supabase
          .from('ingredients')
          .select('base_unit')
          .eq('id', ingredientId)
          .single();

      final baseUnit = response['base_unit'] as String? ?? 'pcs';

      // Convert to base unit
      final converted = UnitConverter.convert(
        value: quantity,
        from: inputUnit,
        to: baseUnit,
      );
      finalQuantity = converted ?? quantity;
    }

    // Insert stock movement record (store in base unit)
    await _supabase.from('stock_movements').insert({
      'outlet_id': outletId,
      'ingredient_id': ingredientId,
      'movement_type': type,
      'quantity': finalQuantity,
      'notes': notes,
    });

    // Atomic stock update via RPC (prevents race conditions)
    await _supabase.rpc('increment_ingredient_stock', params: {
      'p_ingredient_id': ingredientId,
      'p_quantity': finalQuantity,
    });
  }

  Future<void> updateIngredient(
    String id, {
    double? minStock,
    double? maxStock,
    double? costPerUnit,
    String? category,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (minStock != null) updates['min_stock'] = minStock;
    if (maxStock != null) updates['max_stock'] = maxStock;
    if (costPerUnit != null) updates['cost_per_unit'] = costPerUnit;
    if (category != null) updates['category'] = category;

    await _supabase.from('ingredients').update(updates).eq('id', id);
  }

  Future<void> addIngredient({
    required String outletId,
    required String name,
    required String unit,
    String category = 'makanan',
    double costPerUnit = 0,
    double minStock = 0,
    String? supplierId,
  }) async {
    // Determine base unit from display unit
    final baseUnit = UnitConverter.getBaseUnit(unit);

    // Convert minStock to base unit if needed
    final minStockInBase = UnitConverter.convert(
      value: minStock,
      from: unit,
      to: baseUnit,
    ) ?? minStock;

    await _supabase.from('ingredients').insert({
      'outlet_id': outletId,
      'name': name,
      'unit': unit, // Display unit
      'base_unit': baseUnit, // Storage unit
      'category': category,
      'cost_per_unit': costPerUnit,
      'min_stock': minStockInBase, // Store in base unit
      'current_stock': 0,
      'supplier_id': supplierId,
      'is_active': true,
    });
  }

  Future<void> deleteIngredient(String id) async {
    await _supabase
        .from('ingredients')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
