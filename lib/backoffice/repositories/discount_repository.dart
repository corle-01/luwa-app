import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/format_utils.dart';

class DiscountModel {
  final String id;
  final String outletId;
  final String name;
  final String type;
  final double value;
  final double minPurchase;
  final double? maxDiscount;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiscountModel({
    required this.id,
    required this.outletId,
    required this.name,
    required this.type,
    required this.value,
    this.minPurchase = 0,
    this.maxDiscount,
    this.isActive = true,
    this.validFrom,
    this.validUntil,
    this.createdAt,
    this.updatedAt,
  });

  factory DiscountModel.fromJson(Map<String, dynamic> json) {
    return DiscountModel(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'percentage',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      minPurchase: (json['min_purchase'] as num?)?.toDouble() ?? 0,
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  bool get isPercentage => type == 'percentage';

  String get displayValue {
    if (isPercentage) {
      final formatted = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      return '$formatted%';
    } else {
      return FormatUtils.currency(value);
    }
  }

  String get typeLabel => isPercentage ? 'Persentase' : 'Nominal';
}

class DiscountRepository {
  final _supabase = Supabase.instance.client;

  Future<List<DiscountModel>> getDiscounts(String outletId) async {
    final response = await _supabase
        .from('discounts')
        .select()
        .eq('outlet_id', outletId)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => DiscountModel.fromJson(json))
        .toList();
  }

  Future<void> createDiscount({
    required String outletId,
    required String name,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    await _supabase.from('discounts').insert({
      'outlet_id': outletId,
      'name': name,
      'type': type,
      'value': value,
      'min_purchase': minPurchase ?? 0,
      'max_discount': maxDiscount,
      'valid_from': validFrom?.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
    });
  }

  Future<void> updateDiscount({
    required String id,
    required String name,
    required String type,
    required double value,
    double? minPurchase,
    double? maxDiscount,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    await _supabase.from('discounts').update({
      'name': name,
      'type': type,
      'value': value,
      'min_purchase': minPurchase ?? 0,
      'max_discount': maxDiscount,
      'valid_from': validFrom?.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteDiscount(String id) async {
    await _supabase.from('discounts').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> toggleDiscount(String id, bool isActive) async {
    await _supabase.from('discounts').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
