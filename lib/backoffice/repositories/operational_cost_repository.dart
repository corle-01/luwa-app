import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/operational_cost.dart';

class OperationalCostRepository {
  final _supabase = Supabase.instance.client;

  Future<List<OperationalCost>> getCosts(String outletId) async {
    final response = await _supabase
        .from('operational_costs')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => OperationalCost.fromJson(json))
        .toList();
  }

  Future<void> updateCost(String id, {required double amount, String? notes}) async {
    final updates = <String, dynamic>{
      'amount': amount,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) updates['notes'] = notes;
    await _supabase.from('operational_costs').update(updates).eq('id', id);
  }

  Future<void> addCost({
    required String outletId,
    required String category,
    required String name,
    double amount = 0,
    String? notes,
  }) async {
    await _supabase.from('operational_costs').insert({
      'outlet_id': outletId,
      'category': category,
      'name': name,
      'amount': amount,
      'notes': notes,
      'is_active': true,
    });
  }

  Future<void> deleteCost(String id) async {
    await _supabase
        .from('operational_costs')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Get total monthly costs (for HPP calculation)
  Future<double> getTotalMonthlyCost(String outletId) async {
    final costs = await getCosts(outletId);
    return costs.fold(0.0, (sum, c) => sum + c.amount);
  }

  /// Get costs grouped by category
  Future<Map<String, double>> getCostsByCategory(String outletId) async {
    final costs = await getCosts(outletId);
    final map = <String, double>{};
    for (final c in costs) {
      map[c.category] = (map[c.category] ?? 0) + c.amount;
    }
    return map;
  }
}
