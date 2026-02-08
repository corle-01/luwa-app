import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerModel {
  final String id;
  final String outletId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int loyaltyPoints;
  final int totalVisits;
  final double totalSpent;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    required this.id,
    required this.outletId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.loyaltyPoints = 0,
    this.totalVisits = 0,
    this.totalSpent = 0,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      loyaltyPoints: json['loyalty_points'] as int? ?? 0,
      totalVisits: json['total_visits'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class CustomerRepository {
  final _supabase = Supabase.instance.client;

  Future<List<CustomerModel>> getCustomers(String outletId) async {
    final response = await _supabase
        .from('customers')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => CustomerModel.fromJson(json))
        .toList();
  }

  Future<List<CustomerModel>> searchCustomers(String outletId, String query) async {
    final response = await _supabase
        .from('customers')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .or('name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
        .order('name', ascending: true);

    return (response as List)
        .map((json) => CustomerModel.fromJson(json))
        .toList();
  }

  Future<void> createCustomer({
    required String outletId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    await _supabase.from('customers').insert({
      'outlet_id': outletId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
    });
  }

  Future<void> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (address != null) data['address'] = address;
    if (notes != null) data['notes'] = notes;

    await _supabase
        .from('customers')
        .update(data)
        .eq('id', id);
  }

  Future<void> deleteCustomer(String id) async {
    await _supabase
        .from('customers')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
