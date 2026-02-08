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
  final int sortOrder;
  final String? outletId;
  int? calculatedAvailableQty;

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
    this.sortOrder = 0,
    this.outletId,
    this.calculatedAvailableQty,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
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
      sortOrder: json['sort_order'] as int? ?? 0,
      outletId: json['outlet_id'] as String?,
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
    int? sortOrder,
    String? outletId,
    int? calculatedAvailableQty,
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
      sortOrder: sortOrder ?? this.sortOrder,
      outletId: outletId ?? this.outletId,
      calculatedAvailableQty: calculatedAvailableQty ?? this.calculatedAvailableQty,
    );
  }
}

class ProductCategory {
  final String id;
  final String name;
  final String? color;
  final String? icon;
  final int sortOrder;

  ProductCategory({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    this.sortOrder = 0,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
