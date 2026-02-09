import 'product_image.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final double sellingPrice;
  final double? costPrice;
  final String? categoryId;
  final String? categoryName;
  final String? imageUrl;
  final bool isAvailable;
  final bool trackStock;
  final int stockQuantity;
  final int minStock;
  final int sortOrder;
  final String? outletId;
  int? calculatedAvailableQty;
  final List<ProductImage> images;
  final List<String> featuredCategoryIds;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.sellingPrice,
    this.costPrice,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
    this.isAvailable = true,
    this.trackStock = true,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.sortOrder = 0,
    this.outletId,
    this.calculatedAvailableQty,
    this.images = const [],
    this.featuredCategoryIds = const [],
  });

  /// The primary image URL: first checks the images list for one flagged
  /// as primary, then falls back to the legacy [imageUrl] field.
  String? get primaryImageUrl {
    final primary = images.where((i) => i.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.imageUrl;
    if (images.isNotEmpty) return images.first.imageUrl;
    return imageUrl;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse nested product_images if present
    List<ProductImage> images = [];
    if (json['product_images'] is List) {
      images = (json['product_images'] as List)
          .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Parse featured category IDs from junction table
    List<String> featuredCategoryIds = [];
    if (json['product_featured_categories'] is List) {
      featuredCategoryIds = (json['product_featured_categories'] as List)
          .map((e) => e['featured_category_id'] as String)
          .toList();
    }

    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      categoryId: json['category_id'] as String?,
      categoryName: json['categories'] is Map ? json['categories']['name'] as String? : null,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      trackStock: json['track_stock'] as bool? ?? true,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      minStock: json['min_stock'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      outletId: json['outlet_id'] as String?,
      images: images,
      featuredCategoryIds: featuredCategoryIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'selling_price': sellingPrice,
    'cost_price': costPrice,
    'category_id': categoryId,
    'image_url': imageUrl,
    'is_available': isAvailable,
    'track_stock': trackStock,
    'stock_quantity': stockQuantity,
    'min_stock': minStock,
    'sort_order': sortOrder,
    'outlet_id': outletId,
  };

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? sellingPrice,
    double? costPrice,
    String? categoryId,
    String? categoryName,
    String? imageUrl,
    bool? isAvailable,
    bool? trackStock,
    int? stockQuantity,
    int? minStock,
    int? sortOrder,
    String? outletId,
    int? calculatedAvailableQty,
    List<ProductImage>? images,
    List<String>? featuredCategoryIds,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      trackStock: trackStock ?? this.trackStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStock: minStock ?? this.minStock,
      sortOrder: sortOrder ?? this.sortOrder,
      outletId: outletId ?? this.outletId,
      calculatedAvailableQty: calculatedAvailableQty ?? this.calculatedAvailableQty,
      images: images ?? this.images,
      featuredCategoryIds: featuredCategoryIds ?? this.featuredCategoryIds,
    );
  }
}

class ProductCategory {
  final String id;
  final String name;
  final String? color;
  final String? icon;
  final int sortOrder;
  final bool isFeatured;
  final String station; // 'kitchen' or 'bar'

  ProductCategory({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.isFeatured = false,
    this.station = 'kitchen',
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
      station: json['station'] as String? ?? 'kitchen',
    );
  }
}
