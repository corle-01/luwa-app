import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModifierGroup {
  final String id;
  final String name;
  final String selectionType; // 'single' or 'multiple'
  final bool isRequired;
  final int? minSelections;
  final int? maxSelections;
  final List<ModifierOption> options;

  ModifierGroup({
    required this.id,
    required this.name,
    this.selectionType = 'single',
    this.isRequired = false,
    this.minSelections,
    this.maxSelections,
    this.options = const [],
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      selectionType: json['selection_type'] as String? ?? 'single',
      isRequired: json['is_required'] as bool? ?? false,
      minSelections: json['min_selections'] as int?,
      maxSelections: json['max_selections'] as int?,
      options: (json['modifier_options'] as List?)
              ?.map((o) => ModifierOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ModifierOption {
  final String id;
  final String name;
  final double priceAdjustment;
  final bool isAvailable;
  final int sortOrder;

  ModifierOption({
    required this.id,
    required this.name,
    this.priceAdjustment = 0,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class PosModifierRepository {
  final _supabase = Supabase.instance.client;

  Future<List<ModifierGroup>> getModifierGroups(String productId) async {
    try {
      final response = await _supabase
          .from('product_modifier_groups')
          .select('modifier_group_id')
          .eq('product_id', productId);

      final groupIds = (response as List)
          .map((r) => r['modifier_group_id'] as String)
          .toList();

      if (groupIds.isEmpty) return [];

      final groupsResponse = await _supabase
          .from('modifier_groups')
          .select('*, modifier_options(*)')
          .inFilter('id', groupIds)
          .order('sort_order', ascending: true);

      return (groupsResponse as List)
          .map((json) => ModifierGroup.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PosModifierRepository.getModifierGroups error: $e');
      return [];
    }
  }
}
