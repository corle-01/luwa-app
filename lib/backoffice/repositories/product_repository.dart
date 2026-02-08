import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class ProductModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;
  final double sellingPrice;
  final double costPrice;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    required this.sellingPrice,
    this.costPrice = 0,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['categories'] is Map
          ? json['categories']['name'] as String?
          : null,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'category_id': categoryId,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  /// Profit margin in absolute value
  double get margin => sellingPrice - costPrice;

  /// Profit margin as percentage of selling price
  double get marginPercent =>
      costPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;
}

class CategoryModel {
  final String id;
  final String name;
  final String? color;
  final int sortOrder;
  final bool isActive;

  CategoryModel({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// ── Repository ──────────────────────────────────────────────────────────────

class ProductRepository {
  final _supabase = Supabase.instance.client;

  /// Fetch all products for an outlet (including inactive), with category join.
  Future<List<ProductModel>> getProducts(String outletId) async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name)')
        .eq('outlet_id', outletId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => ProductModel.fromJson(json))
        .toList();
  }

  /// Fetch all categories for an outlet (including inactive).
  Future<List<CategoryModel>> getCategories(String outletId) async {
    final response = await _supabase
        .from('categories')
        .select()
        .eq('outlet_id', outletId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => CategoryModel.fromJson(json))
        .toList();
  }

  /// Create a new product.
  Future<void> createProduct({
    required String outletId,
    required String name,
    String? categoryId,
    required double sellingPrice,
    double costPrice = 0,
    String? description,
  }) async {
    await _supabase.from('products').insert({
      'outlet_id': outletId,
      'name': name,
      'category_id': categoryId,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'description': description,
      'is_active': true,
    });
  }

  /// Update an existing product.
  Future<void> updateProduct(
    String id, {
    String? name,
    String? categoryId,
    double? sellingPrice,
    double? costPrice,
    String? description,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) data['name'] = name;
    if (categoryId != null) data['category_id'] = categoryId;
    if (sellingPrice != null) data['selling_price'] = sellingPrice;
    if (costPrice != null) data['cost_price'] = costPrice;
    if (description != null) data['description'] = description;

    await _supabase.from('products').update(data).eq('id', id);
  }

  /// Soft enable / disable a product.
  Future<void> toggleProduct(String id, bool isActive) async {
    await _supabase.from('products').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Delete a product permanently.
  Future<void> deleteProduct(String id) async {
    await _supabase.from('products').delete().eq('id', id);
  }

  /// Create a new category.
  Future<void> createCategory({
    required String outletId,
    required String name,
    String? color,
  }) async {
    await _supabase.from('categories').insert({
      'outlet_id': outletId,
      'name': name,
      'color': color,
      'is_active': true,
    });
  }

  /// Update category.
  Future<void> updateCategory(
    String id, {
    String? name,
    String? color,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    await _supabase.from('categories').update(data).eq('id', id);
  }

  /// Delete a category permanently.
  Future<void> deleteCategory(String id) async {
    // Set products in this category to uncategorized first
    await _supabase
        .from('products')
        .update({'category_id': null})
        .eq('category_id', id);
    await _supabase.from('categories').delete().eq('id', id);
  }
}
