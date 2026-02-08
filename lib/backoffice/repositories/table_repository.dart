import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TableModel {
  final String id;
  final String outletId;
  final String tableNumber;
  final int capacity;
  final String status;
  final String? section;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TableModel({
    required this.id,
    required this.outletId,
    required this.tableNumber,
    this.capacity = 4,
    this.status = 'available',
    this.section,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      tableNumber: json['table_number']?.toString() ?? '',
      capacity: json['capacity'] as int? ?? 4,
      status: json['status'] as String? ?? 'available',
      section: json['section'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'available':
        return 'Tersedia';
      case 'occupied':
        return 'Terisi';
      case 'reserved':
        return 'Dipesan';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'available':
        return const Color(0xFF10B981); // green / successColor
      case 'occupied':
        return const Color(0xFFEF4444); // red / errorColor
      case 'reserved':
        return const Color(0xFFF59E0B); // orange / warningColor
      case 'maintenance':
        return const Color(0xFF6B7280); // gray / textSecondary
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}

class TableRepository {
  final _supabase = Supabase.instance.client;

  Future<List<TableModel>> getTables(String outletId) async {
    final response = await _supabase
        .from('tables')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('table_number', ascending: true);

    return (response as List)
        .map((json) => TableModel.fromJson(json))
        .toList();
  }

  Future<void> createTable({
    required String outletId,
    required String tableNumber,
    int capacity = 4,
    String? section,
  }) async {
    await _supabase.from('tables').insert({
      'outlet_id': outletId,
      'table_number': tableNumber,
      'capacity': capacity,
      'section': section,
    });
  }

  Future<void> updateTable({
    required String id,
    String? tableNumber,
    int? capacity,
    String? section,
    String? status,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (tableNumber != null) updates['table_number'] = tableNumber;
    if (capacity != null) updates['capacity'] = capacity;
    if (section != null) updates['section'] = section;
    if (status != null) updates['status'] = status;

    await _supabase.from('tables').update(updates).eq('id', id);
  }

  Future<void> deleteTable(String id) async {
    await _supabase
        .from('tables')
        .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> toggleTable(String id, bool isActive) async {
    await _supabase
        .from('tables')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
