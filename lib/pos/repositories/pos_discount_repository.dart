import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/discount.dart';

class PosDiscountRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Discount>> getActiveDiscounts(String outletId) async {
    try {
      final response = await _supabase
          .from('discounts')
          .select()
          .eq('outlet_id', outletId)
          .eq('is_active', true);
      return (response as List).map((json) => Discount.fromJson(json)).toList();
    } catch (e) {
      debugPrint('PosDiscountRepository.getActiveDiscounts error: $e');
      return [];
    }
  }

  Future<List<Tax>> getActiveTaxes(String outletId) async {
    try {
      final response = await _supabase
          .from('taxes')
          .select()
          .eq('outlet_id', outletId)
          .eq('is_active', true);
      return (response as List).map((json) => Tax.fromJson(json)).toList();
    } catch (e) {
      debugPrint('PosDiscountRepository.getActiveTaxes error: $e');
      return [];
    }
  }
}
