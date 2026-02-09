import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/product_image.dart';

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
  final List<ProductImage> images;

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
    this.images = const [],
  });

  /// The primary image URL: checks the images list first (primary flag,
  /// then first by sort_order), falls back to legacy [imageUrl] field.
  String? get primaryImageUrl {
    final primary = images.where((i) => i.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.imageUrl;
    if (images.isNotEmpty) return images.first.imageUrl;
    return imageUrl;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Parse nested product_images if present
    List<ProductImage> images = [];
    if (json['product_images'] is List) {
      images = (json['product_images'] as List)
          .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

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
      images: images,
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
  final bool isFeatured;

  CategoryModel({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.isFeatured = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }
}

// ── Repository ──────────────────────────────────────────────────────────────

class ProductRepository {
  final _supabase = Supabase.instance.client;

  /// Fetch all products for an outlet (including inactive), with category
  /// join and product_images nested.
  Future<List<ProductModel>> getProducts(String outletId) async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name), product_images(*)')
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

  // ── Product Images ──────────────────────────────────────────────────────

  /// Fetch all images for a product, sorted by sort_order.
  Future<List<ProductImage>> getProductImages(String productId) async {
    final response = await _supabase
        .from('product_images')
        .select()
        .eq('product_id', productId)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((json) => ProductImage.fromJson(json))
        .toList();
  }

  /// Add a new image to a product.
  /// If [isPrimary] is true, clears the primary flag on all other images first.
  Future<ProductImage> addProductImage({
    required String productId,
    required String imageUrl,
    int sortOrder = 0,
    bool isPrimary = false,
  }) async {
    if (isPrimary) {
      // Clear primary flag on all existing images for this product
      await _supabase
          .from('product_images')
          .update({'is_primary': false})
          .eq('product_id', productId);
    }

    final response = await _supabase
        .from('product_images')
        .insert({
          'product_id': productId,
          'image_url': imageUrl,
          'sort_order': sortOrder,
          'is_primary': isPrimary,
        })
        .select()
        .single();

    return ProductImage.fromJson(response);
  }

  /// Delete a product image by its ID.
  Future<void> deleteProductImage(String imageId) async {
    await _supabase.from('product_images').delete().eq('id', imageId);
  }

  /// Set a specific image as the primary image for its product.
  /// Clears primary from all others for the same product.
  Future<void> setPrimaryImage({
    required String productId,
    required String imageId,
  }) async {
    // Clear all primary flags for this product
    await _supabase
        .from('product_images')
        .update({'is_primary': false})
        .eq('product_id', productId);

    // Set the new primary
    await _supabase
        .from('product_images')
        .update({'is_primary': true})
        .eq('id', imageId);
  }

  /// Reorder images by updating their sort_order values.
  /// [imageIds] should be the ordered list of image IDs.
  Future<void> reorderImages(List<String> imageIds) async {
    for (int i = 0; i < imageIds.length; i++) {
      await _supabase
          .from('product_images')
          .update({'sort_order': i})
          .eq('id', imageIds[i]);
    }
  }
}
