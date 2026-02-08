import 'package:supabase_flutter/supabase_flutter.dart';

class TaxModel {
  final String id;
  final String outletId;
  final String name;
  final String type; // 'percentage' or 'fixed'
  final double value;
  final bool isInclusive;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaxModel({
    required this.id,
    required this.outletId,
    required this.name,
    required this.type,
    required this.value,
    this.isInclusive = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TaxModel.fromJson(Map<String, dynamic> json) {
    return TaxModel(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'percentage',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      isInclusive: json['is_inclusive'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get typeLabel => type == 'percentage' ? 'Persentase' : 'Nominal';

  String get displayValue {
    if (type == 'percentage') {
      // Remove trailing zeros for cleaner display
      final formatted = value.truncateToDouble() == value
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
      return '$formatted%';
    } else {
      return 'Rp ${value.toInt()}';
    }
  }
}

class TaxRepository {
  final _supabase = Supabase.instance.client;

  Future<List<TaxModel>> getTaxes(String outletId) async {
    final response = await _supabase
        .from('taxes')
        .select()
        .eq('outlet_id', outletId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => TaxModel.fromJson(json))
        .toList();
  }

  Future<String> createTax({
    required String outletId,
    required String name,
    required String type,
    required double value,
    bool isInclusive = false,
  }) async {
    final response = await _supabase
        .from('taxes')
        .insert({
          'outlet_id': outletId,
          'name': name,
          'type': type,
          'value': value,
          'is_inclusive': isInclusive,
          'is_active': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<void> updateTax({
    required String id,
    required String name,
    required String type,
    required double value,
    bool isInclusive = false,
  }) async {
    await _supabase
        .from('taxes')
        .update({
          'name': name,
          'type': type,
          'value': value,
          'is_inclusive': isInclusive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteTax(String id) async {
    await _supabase
        .from('taxes')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> toggleTax(String id, bool isActive) async {
    await _supabase
        .from('taxes')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
