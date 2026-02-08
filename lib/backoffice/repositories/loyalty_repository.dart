import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyProgram {
  final String id;
  final String name;
  final String? description;
  final double pointsPerAmount;
  final double amountPerPoint;
  final int minRedeemPoints;
  final double redeemValue;
  final bool isActive;
  final DateTime? createdAt;

  LoyaltyProgram({
    required this.id,
    required this.name,
    this.description,
    this.pointsPerAmount = 1,
    this.amountPerPoint = 10000,
    this.minRedeemPoints = 10,
    this.redeemValue = 10000,
    this.isActive = true,
    this.createdAt,
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> json) => LoyaltyProgram(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    pointsPerAmount: (json['points_per_amount'] as num?)?.toDouble() ?? 1,
    amountPerPoint: (json['amount_per_point'] as num?)?.toDouble() ?? 10000,
    minRedeemPoints: json['min_redeem_points'] as int? ?? 10,
    redeemValue: (json['redeem_value'] as num?)?.toDouble() ?? 10000,
    isActive: json['is_active'] as bool? ?? true,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
  );
}

class LoyaltyTransaction {
  final String id;
  final String customerId;
  final String? programId;
  final String? orderId;
  final String type; // earn or redeem
  final int points;
  final double amount;
  final String? description;
  final DateTime createdAt;
  final String? customerName;

  LoyaltyTransaction({
    required this.id,
    required this.customerId,
    this.programId,
    this.orderId,
    required this.type,
    required this.points,
    this.amount = 0,
    this.description,
    required this.createdAt,
    this.customerName,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) => LoyaltyTransaction(
    id: json['id'],
    customerId: json['customer_id'],
    programId: json['program_id'],
    orderId: json['order_id'],
    type: json['type'],
    points: json['points'] as int,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    description: json['description'],
    createdAt: DateTime.parse(json['created_at']),
    customerName: json['customers'] != null ? json['customers']['name'] as String? : null,
  );
}

class LoyaltyRepository {
  final _supabase = Supabase.instance.client;

  Future<List<LoyaltyProgram>> getPrograms(String outletId) async {
    final response = await _supabase
        .from('loyalty_programs')
        .select()
        .eq('outlet_id', outletId)
        .order('created_at');
    return (response as List).map((j) => LoyaltyProgram.fromJson(j)).toList();
  }

  Future<void> createProgram({
    required String outletId,
    required String name,
    String? description,
    required double pointsPerAmount,
    required double amountPerPoint,
    required int minRedeemPoints,
    required double redeemValue,
  }) async {
    await _supabase.from('loyalty_programs').insert({
      'outlet_id': outletId,
      'name': name,
      'description': description,
      'points_per_amount': pointsPerAmount,
      'amount_per_point': amountPerPoint,
      'min_redeem_points': minRedeemPoints,
      'redeem_value': redeemValue,
    });
  }

  Future<void> updateProgram({
    required String id,
    required String name,
    String? description,
    required double pointsPerAmount,
    required double amountPerPoint,
    required int minRedeemPoints,
    required double redeemValue,
    required bool isActive,
  }) async {
    await _supabase.from('loyalty_programs').update({
      'name': name,
      'description': description,
      'points_per_amount': pointsPerAmount,
      'amount_per_point': amountPerPoint,
      'min_redeem_points': minRedeemPoints,
      'redeem_value': redeemValue,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteProgram(String id) async {
    await _supabase.from('loyalty_programs').delete().eq('id', id);
  }

  Future<List<LoyaltyTransaction>> getTransactions(String outletId, {String? customerId, String? typeFilter}) async {
    var query = _supabase
        .from('loyalty_transactions')
        .select('*, customers(name)')
        .eq('outlet_id', outletId);
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    if (typeFilter != null && typeFilter.isNotEmpty) {
      query = query.eq('type', typeFilter);
    }
    final response = await query.order('created_at', ascending: false).limit(100);
    return (response as List).map((j) => LoyaltyTransaction.fromJson(j)).toList();
  }

  Future<void> earnPoints({
    required String outletId,
    required String customerId,
    required String programId,
    required String orderId,
    required int points,
    required double amount,
  }) async {
    // Insert transaction
    await _supabase.from('loyalty_transactions').insert({
      'outlet_id': outletId,
      'customer_id': customerId,
      'program_id': programId,
      'order_id': orderId,
      'type': 'earn',
      'points': points,
      'amount': amount,
      'description': 'Poin dari pembelian Rp ${amount.toStringAsFixed(0)}',
    });

    // Update customer loyalty_points
    final current = await _supabase.from('customers').select('loyalty_points').eq('id', customerId).single();
    final currentPoints = current['loyalty_points'] as int? ?? 0;
    await _supabase.from('customers').update({
      'loyalty_points': currentPoints + points,
    }).eq('id', customerId);
  }

  Future<void> redeemPoints({
    required String outletId,
    required String customerId,
    required String programId,
    required int points,
    required double discountAmount,
    String? orderId,
  }) async {
    await _supabase.from('loyalty_transactions').insert({
      'outlet_id': outletId,
      'customer_id': customerId,
      'program_id': programId,
      'order_id': orderId,
      'type': 'redeem',
      'points': points,
      'amount': discountAmount,
      'description': 'Tukar $points poin untuk diskon Rp ${discountAmount.toStringAsFixed(0)}',
    });

    final current = await _supabase.from('customers').select('loyalty_points').eq('id', customerId).single();
    final currentPoints = current['loyalty_points'] as int? ?? 0;
    await _supabase.from('customers').update({
      'loyalty_points': (currentPoints - points).clamp(0, 999999),
    }).eq('id', customerId);
  }
}
