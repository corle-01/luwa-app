/// Model representing a single image attached to a product.
///
/// Products can have multiple images. The [isPrimary] flag marks the image
/// shown as the main thumbnail; [sortOrder] controls display order.
class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final int sortOrder;
  final bool isPrimary;
  final DateTime? createdAt;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.createdAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      imageUrl: json['image_url'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_primary': isPrimary,
      };

  ProductImage copyWith({
    String? id,
    String? productId,
    String? imageUrl,
    int? sortOrder,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return ProductImage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
