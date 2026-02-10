import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class BOModifierGroup {
  final String id;
  final String outletId;
  final String name;
  final String selectionType;
  final bool isRequired;
  final int? minSelections;
  final int? maxSelections;
  final int sortOrder;
  final List<BOModifierOption> options;

  BOModifierGroup({
    required this.id,
    required this.outletId,
    required this.name,
    this.selectionType = 'single',
    this.isRequired = false,
    this.minSelections,
    this.maxSelections,
    this.sortOrder = 0,
    this.options = const [],
  });

  factory BOModifierGroup.fromJson(Map<String, dynamic> json) {
    return BOModifierGroup(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      selectionType: json['selection_type'] as String? ?? 'single',
      isRequired: json['is_required'] as bool? ?? false,
      minSelections: json['min_selections'] as int?,
      maxSelections: json['max_selections'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      options: ((json['modifier_options'] as List?)
              ?.map((o) => BOModifierOption.fromJson(o as Map<String, dynamic>))
              .toList()
            ?..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))) ??
          [],
    );
  }
}

class BOModifierOption {
  final String id;
  final String groupId;
  final String name;
  final double priceAdjustment;
  final bool isAvailable;
  final bool isDefault;
  final int sortOrder;

  BOModifierOption({
    required this.id,
    required this.groupId,
    required this.name,
    this.priceAdjustment = 0,
    this.isAvailable = true,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory BOModifierOption.fromJson(Map<String, dynamic> json) {
    return BOModifierOption(
      id: json['id'] as String,
      groupId: json['modifier_group_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class ProductModifierAssignment {
  final String productId;
  final String modifierGroupId;
  final int sortOrder;

  ProductModifierAssignment({
    required this.productId,
    required this.modifierGroupId,
    this.sortOrder = 0,
  });

  factory ProductModifierAssignment.fromJson(Map<String, dynamic> json) {
    return ProductModifierAssignment(
      productId: json['product_id'] as String,
      modifierGroupId: json['modifier_group_id'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class ModifierOptionIngredient {
  final String id;
  final String modifierOptionId;
  final String ingredientId;
  final String ingredientName;
  final String ingredientUnit;
  final double quantity;
  final String unit;

  ModifierOptionIngredient({
    required this.id,
    required this.modifierOptionId,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientUnit,
    required this.quantity,
    required this.unit,
  });

  factory ModifierOptionIngredient.fromJson(Map<String, dynamic> json) {
    final ingredient = json['ingredients'] as Map<String, dynamic>? ?? {};
    return ModifierOptionIngredient(
      id: json['id'] as String,
      modifierOptionId: json['modifier_option_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      ingredientName: ingredient['name'] as String? ?? '',
      ingredientUnit: ingredient['unit'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'gram',
    );
  }
}

// ── Repository ──────────────────────────────────────────────────────────────

class BOModifierRepository {
  final _supabase = Supabase.instance.client;

  // ── Modifier Groups ─────────────────────────────────────────────────────

  /// Fetch all modifier groups for an outlet, with their options.
  Future<List<BOModifierGroup>> getModifierGroups(String outletId) async {
    final response = await _supabase
        .from('modifier_groups')
        .select('*, modifier_options(*)')
        .eq('outlet_id', outletId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => BOModifierGroup.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new modifier group.
  Future<void> createModifierGroup({
    required String outletId,
    required String name,
    bool isRequired = false,
    int? minSelections,
    int? maxSelections,
    String selectionType = 'single',
  }) async {
    await _supabase.from('modifier_groups').insert({
      'outlet_id': outletId,
      'name': name,
      'is_required': isRequired,
      'min_selections': minSelections,
      'max_selections': maxSelections,
      'selection_type': selectionType,
    });
  }

  /// Update an existing modifier group.
  Future<void> updateModifierGroup(
    String id, {
    String? name,
    bool? isRequired,
    int? minSelections,
    int? maxSelections,
    String? selectionType,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (isRequired != null) data['is_required'] = isRequired;
    if (minSelections != null) data['min_selections'] = minSelections;
    if (maxSelections != null) data['max_selections'] = maxSelections;
    if (selectionType != null) data['selection_type'] = selectionType;

    if (data.isNotEmpty) {
      await _supabase.from('modifier_groups').update(data).eq('id', id);
    }
  }

  /// Delete a modifier group and its options + product assignments.
  Future<void> deleteModifierGroup(String id) async {
    // Delete product assignments first
    await _supabase
        .from('product_modifier_groups')
        .delete()
        .eq('modifier_group_id', id);
    // Delete options
    await _supabase
        .from('modifier_options')
        .delete()
        .eq('modifier_group_id', id);
    // Delete group
    await _supabase.from('modifier_groups').delete().eq('id', id);
  }

  // ── Modifier Options ────────────────────────────────────────────────────

  /// Create a new modifier option.
  Future<void> createModifierOption({
    required String groupId,
    required String name,
    double priceAdjustment = 0,
    bool isDefault = false,
    int sortOrder = 0,
  }) async {
    await _supabase.from('modifier_options').insert({
      'modifier_group_id': groupId,
      'name': name,
      'price_adjustment': priceAdjustment,
      'is_default': isDefault,
      'is_available': true,
      'sort_order': sortOrder,
    });
  }

  /// Update an existing modifier option.
  Future<void> updateModifierOption(
    String id, {
    String? name,
    double? priceAdjustment,
    bool? isDefault,
    bool? isAvailable,
    int? sortOrder,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (priceAdjustment != null) data['price_adjustment'] = priceAdjustment;
    if (isDefault != null) data['is_default'] = isDefault;
    if (isAvailable != null) data['is_available'] = isAvailable;
    if (sortOrder != null) data['sort_order'] = sortOrder;

    if (data.isNotEmpty) {
      await _supabase.from('modifier_options').update(data).eq('id', id);
    }
  }

  /// Delete a modifier option.
  Future<void> deleteModifierOption(String id) async {
    await _supabase.from('modifier_options').delete().eq('id', id);
  }

  // ── Product-Modifier Assignment ─────────────────────────────────────────

  /// Get which modifier groups are assigned to a product.
  Future<List<ProductModifierAssignment>> getProductModifiers(
    String productId,
  ) async {
    final response = await _supabase
        .from('product_modifier_groups')
        .select()
        .eq('product_id', productId)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((json) =>
            ProductModifierAssignment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Assign a modifier group to a product.
  Future<void> assignModifierToProduct({
    required String productId,
    required String groupId,
    int sortOrder = 0,
  }) async {
    await _supabase.from('product_modifier_groups').insert({
      'product_id': productId,
      'modifier_group_id': groupId,
      'sort_order': sortOrder,
    });
  }

  /// Remove a modifier group from a product.
  Future<void> removeModifierFromProduct({
    required String productId,
    required String groupId,
  }) async {
    await _supabase
        .from('product_modifier_groups')
        .delete()
        .eq('product_id', productId)
        .eq('modifier_group_id', groupId);
  }

  // ── Modifier Option Ingredients ──────────────────────────────────────────

  /// Get all ingredient links for a modifier option.
  Future<List<ModifierOptionIngredient>> getModifierOptionIngredients(
    String optionId,
  ) async {
    final response = await _supabase
        .from('modifier_option_ingredients')
        .select('*, ingredients(name, unit)')
        .eq('modifier_option_id', optionId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) =>
            ModifierOptionIngredient.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Add an ingredient link to a modifier option.
  Future<void> addModifierOptionIngredient({
    required String optionId,
    required String ingredientId,
    required double quantity,
    String unit = 'gram',
  }) async {
    await _supabase.from('modifier_option_ingredients').insert({
      'modifier_option_id': optionId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'unit': unit,
    });
  }

  /// Update quantity/unit for a modifier option ingredient link.
  Future<void> updateModifierOptionIngredient(
    String id, {
    double? quantity,
    String? unit,
  }) async {
    final data = <String, dynamic>{};
    if (quantity != null) data['quantity'] = quantity;
    if (unit != null) data['unit'] = unit;

    if (data.isNotEmpty) {
      await _supabase
          .from('modifier_option_ingredients')
          .update(data)
          .eq('id', id);
    }
  }

  /// Delete a modifier option ingredient link.
  Future<void> deleteModifierOptionIngredient(String id) async {
    await _supabase
        .from('modifier_option_ingredients')
        .delete()
        .eq('id', id);
  }

  /// Get count of linked ingredients per modifier option (for display).
  Future<Map<String, int>> getModifierOptionIngredientCounts(
    List<String> optionIds,
  ) async {
    if (optionIds.isEmpty) return {};

    final response = await _supabase
        .from('modifier_option_ingredients')
        .select('modifier_option_id')
        .inFilter('modifier_option_id', optionIds);

    final counts = <String, int>{};
    for (final row in response as List) {
      final optionId = row['modifier_option_id'] as String;
      counts[optionId] = (counts[optionId] ?? 0) + 1;
    }
    return counts;
  }
}
