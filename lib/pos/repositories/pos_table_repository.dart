import 'package:supabase_flutter/supabase_flutter.dart';

/// Model untuk meja restoran
class RestaurantTable {
  final String id;
  final String outletId;
  final String tableNumber;
  final String? name;
  final int capacity;
  final String? section;
  final String status;
  final DateTime? updatedAt;

  const RestaurantTable({
    required this.id,
    required this.outletId,
    required this.tableNumber,
    this.name,
    required this.capacity,
    this.section,
    this.status = 'available',
    this.updatedAt,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      tableNumber: json['table_number'] as String? ?? '',
      name: json['name'] as String?,
      capacity: json['capacity'] as int? ?? 4,
      section: json['section'] as String?,
      status: json['status'] as String? ?? 'available',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get displayName => name ?? 'Meja $tableNumber';
  bool get isAvailable => status == 'available';
  bool get isOccupied => status == 'occupied';
  bool get isReserved => status == 'reserved';
}

class PosTableRepository {
  final _supabase = Supabase.instance.client;

  Future<List<RestaurantTable>> getTables(String outletId) async {
    try {
      final response = await _supabase
          .from('tables')
          .select()
          .eq('outlet_id', outletId)
          .order('sort_order', ascending: true);
      return (response as List).map((j) => RestaurantTable.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateTableStatus(String tableId, String status) async {
    await _supabase
        .from('tables')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', tableId);
  }
}
