class OperationalCost {
  final String id;
  final String outletId;
  final String category; // 'operational' or 'labor'
  final String name;
  final double amount;
  final bool isMonthly;
  final bool isActive;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OperationalCost({
    required this.id,
    required this.outletId,
    required this.category,
    required this.name,
    this.amount = 0,
    this.isMonthly = true,
    this.isActive = true,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory OperationalCost.fromJson(Map<String, dynamic> json) {
    return OperationalCost(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      category: json['category'] as String? ?? 'operational',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      isMonthly: json['is_monthly'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get categoryLabel => category == 'labor' ? 'Tenaga Kerja' : 'Operasional';
}
