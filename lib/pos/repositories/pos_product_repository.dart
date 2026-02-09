import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/product.dart';

class PosProductRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Product>> getProducts(String outletId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('*, categories(name), product_images(*)')
          .eq('outlet_id', outletId)
          .eq('is_available', true)
          .order('sort_order', ascending: true);
      return (response as List).map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      // Fallback: try without category join
      try {
        final response = await _supabase
            .from('products')
            .select()
            .eq('outlet_id', outletId)
            .eq('is_available', true)
            .order('sort_order', ascending: true);
        return (response as List).map((json) => Product.fromJson(json)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<ProductCategory>> getCategories(String outletId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('outlet_id', outletId)
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (response as List).map((json) => ProductCategory.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Product>> searchProducts(String outletId, String query) async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name), product_images(*)')
        .eq('outlet_id', outletId)
        .ilike('name', '%$query%')
        .order('name');
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }
}
