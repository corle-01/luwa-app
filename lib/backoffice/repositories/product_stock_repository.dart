import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class ProductStockModel {
  final String id;
  final String name;
  final String? categoryName;
  final double sellingPrice;
  final double costPrice;
  final bool trackStock;
  final int stockQuantity;
  final int minStock;
  final bool isActive;

  ProductStockModel({
    required this.id,
    required this.name,
    this.categoryName,
    this.sellingPrice = 0,
    this.costPrice = 0,
    this.trackStock = false,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.isActive = true,
  });

  factory ProductStockModel.fromJson(Map<String, dynamic> json) {
    return ProductStockModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      categoryName: json['categories'] is Map
          ? json['categories']['name'] as String?
          : null,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      trackStock: json['track_stock'] as bool? ?? false,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      minStock: json['min_stock'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  bool get isLowStock => trackStock && stockQuantity > 0 && stockQuantity <= minStock;

  bool get isOutOfStock => trackStock && stockQuantity <= 0;

  double get stockValue => stockQuantity * costPrice;
}

class ProductStockMovement {
  final String id;
  final String productId;
  final String type;
  final int quantity;
  final String? notes;
  final String? productName;
  final DateTime createdAt;

  ProductStockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.notes,
    this.productName,
    required this.createdAt,
  });

  factory ProductStockMovement.fromJson(Map<String, dynamic> json) {
    return ProductStockMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      type: json['type'] as String? ?? 'adjustment',
      quantity: json['quantity'] as int? ?? 0,
      notes: json['notes'] as String?,
      productName: json['products'] is Map
          ? json['products']['name'] as String?
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'stock_in':
        return 'Stok Masuk';
      case 'stock_out':
        return 'Stok Keluar';
      case 'adjustment':
        return 'Penyesuaian';
      case 'production':
        return 'Produksi';
      case 'sale':
        return 'Penjualan';
      case 'return':
        return 'Retur';
      default:
        return type;
    }
  }
}

// ── Repository ──────────────────────────────────────────────────────────────

class ProductStockRepository {
  final _supabase = Supabase.instance.client;

  /// Fetch all products with stock info for an outlet.
  Future<List<ProductStockModel>> getProductStock(String outletId) async {
    final response = await _supabase
        .from('products')
        .select('id, name, selling_price, cost_price, track_stock, stock_quantity, min_stock, is_active, categories(name)')
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => ProductStockModel.fromJson(json))
        .toList();
  }

  /// Add a stock movement and update the product's stock_quantity.
  Future<void> addStockMovement({
    required String productId,
    required String outletId,
    required String type,
    required int quantity,
    String? notes,
  }) async {
    // Insert movement record
    await _supabase.from('product_stock_movements').insert({
      'product_id': productId,
      'outlet_id': outletId,
      'type': type,
      'quantity': quantity,
      'notes': notes,
    });

    // Fetch current stock and update
    final current = await _supabase
        .from('products')
        .select('stock_quantity')
        .eq('id', productId)
        .single();

    final currentStock = current['stock_quantity'] as int? ?? 0;
    final newStock = currentStock + quantity;

    await _supabase
        .from('products')
        .update({
          'stock_quantity': newStock < 0 ? 0 : newStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Fetch stock movements for a specific product.
  Future<List<ProductStockMovement>> getStockMovements(
    String outletId, {
    String? productId,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('product_stock_movements')
        .select('*, products(name)')
        .eq('outlet_id', outletId);

    if (productId != null) {
      query = query.eq('product_id', productId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => ProductStockMovement.fromJson(json))
        .toList();
  }

  /// Toggle track_stock for a product.
  Future<void> toggleTrackStock(String productId, bool trackStock) async {
    await _supabase
        .from('products')
        .update({
          'track_stock': trackStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Update min_stock for a product.
  Future<void> updateMinStock(String productId, int minStock) async {
    await _supabase
        .from('products')
        .update({
          'min_stock': minStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Update cost_price for a product (manual, for non-recipe products).
  Future<void> updateCostPrice(String productId, double costPrice) async {
    await _supabase
        .from('products')
        .update({
          'cost_price': costPrice,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Soft-delete a product (set is_active = false).
  Future<void> deleteProduct(String productId) async {
    await _supabase
        .from('products')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Check if a product has recipes (HPP auto-calculated).
  Future<bool> hasRecipe(String productId) async {
    final res = await _supabase
        .from('recipes')
        .select('id')
        .eq('product_id', productId)
        .limit(1);
    return (res as List).isNotEmpty;
  }
}
