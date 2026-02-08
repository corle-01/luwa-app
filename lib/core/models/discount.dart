class Discount {
  final String id;
  final String? outletId;
  final String name;
  final String type;
  final double value;
  final double? minPurchase;
  final double? maxDiscount;
  final bool isActive;

  Discount({
    required this.id,
    this.outletId,
    required this.name,
    required this.type,
    required this.value,
    this.minPurchase,
    this.maxDiscount,
    this.isActive = true,
  });

  double calculateDiscount(double subtotal) {
    if (minPurchase != null && subtotal < minPurchase!) return 0;
    double disc;
    if (type == 'percentage') {
      disc = subtotal * (value / 100);
      if (maxDiscount != null && disc > maxDiscount!) disc = maxDiscount!;
    } else {
      disc = value;
    }
    return disc > subtotal ? subtotal : disc;
  }

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String?,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'percentage',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      minPurchase: (json['min_purchase'] as num?)?.toDouble(),
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class Tax {
  final String id;
  final String name;
  final String type;
  final double rate;
  final bool isInclusive;
  final bool isActive;

  Tax({
    required this.id,
    required this.name,
    required this.type,
    required this.rate,
    this.isInclusive = false,
    this.isActive = true,
  });

  factory Tax.fromJson(Map<String, dynamic> json) {
    return Tax(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'tax',
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      isInclusive: json['is_inclusive'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
