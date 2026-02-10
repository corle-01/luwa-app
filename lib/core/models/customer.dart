class Customer {
  final String id;
  final String? outletId;
  final String name;
  final String? phone;
  final String? email;
  final int loyaltyPoints;
  final double totalSpent;
  final int visitCount;
  final DateTime? lastVisit;
  final DateTime createdAt;

  Customer({
    required this.id,
    this.outletId,
    required this.name,
    this.phone,
    this.email,
    this.loyaltyPoints = 0,
    this.totalSpent = 0,
    this.visitCount = 0,
    this.lastVisit,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      loyaltyPoints: json['loyalty_points'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      visitCount: json['total_orders'] as int? ?? 0,
      lastVisit: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
