class Shift {
  final String id;
  final String outletId;
  final String cashierId;
  final String? cashierName;
  final String status;
  final double openingCash;
  final double? closingCash;
  final double? totalSales;
  final int? totalOrders;
  final double? totalCash;
  final double? totalNonCash;
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;

  Shift({
    required this.id,
    required this.outletId,
    required this.cashierId,
    this.cashierName,
    this.status = 'open',
    required this.openingCash,
    this.closingCash,
    this.totalSales,
    this.totalOrders,
    this.totalCash,
    this.totalNonCash,
    this.notes,
    required this.openedAt,
    this.closedAt,
  });

  String get durationFormatted {
    final end = closedAt ?? DateTime.now();
    final diff = end.difference(openedAt);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours}j ${minutes}m';
  }

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String? ?? '',
      cashierId: json['cashier_id'] as String? ?? '',
      cashierName: json['cashier_name'] as String? ?? json['profiles']?['full_name'] as String?,
      status: json['status'] as String? ?? 'open',
      openingCash: (json['opening_cash'] as num?)?.toDouble() ?? 0,
      closingCash: (json['closing_cash'] as num?)?.toDouble(),
      totalSales: (json['total_sales'] as num?)?.toDouble(),
      totalOrders: json['total_orders'] as int?,
      totalCash: (json['total_cash'] as num?)?.toDouble(),
      totalNonCash: (json['total_non_cash'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      openedAt: DateTime.tryParse(json['opened_at'] as String? ?? '') ??
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'cashier_id': cashierId,
    'status': status,
    'opening_cash': openingCash,
    'closing_cash': closingCash,
    'notes': notes,
  };
}

class ShiftSummary {
  final double totalSales;
  final int totalOrders;
  final double totalCash;
  final double totalNonCash;
  final double expectedCash;
  final double? actualCash;
  final double? difference;
  final Map<String, int> ordersByStatus;
  final Map<String, double> salesByPayment;

  ShiftSummary({
    required this.totalSales,
    required this.totalOrders,
    required this.totalCash,
    required this.totalNonCash,
    required this.expectedCash,
    this.actualCash,
    this.difference,
    this.ordersByStatus = const {},
    this.salesByPayment = const {},
  });
}
