import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/customer.dart';

class PosCustomerRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Customer>> searchCustomers(String outletId, String query) async {
    final response = await _supabase
        .from('customers')
        .select()
        .eq('outlet_id', outletId)
        .or('name.ilike.%$query%,phone.ilike.%$query%')
        .order('name')
        .limit(20);
    return (response as List).map((json) => Customer.fromJson(json)).toList();
  }

  Future<Customer> createCustomer(String outletId, {required String name, String? phone, String? email}) async {
    final response = await _supabase
        .from('customers')
        .insert({
          'outlet_id': outletId,
          'name': name,
          'phone': phone,
          'email': email,
        })
        .select()
        .single();
    return Customer.fromJson(response);
  }

  Future<Customer?> getCustomer(String id) async {
    final response = await _supabase
        .from('customers')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Customer.fromJson(response);
  }
}
