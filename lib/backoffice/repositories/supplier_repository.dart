import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierModel {
  final String id;
  final String outletId;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SupplierModel({
    required this.id,
    required this.outletId,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      name: json['name'] as String? ?? '',
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
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

class SupplierRepository {
  final _supabase = Supabase.instance.client;

  Future<List<SupplierModel>> getSuppliers(String outletId) async {
    final response = await _supabase
        .from('suppliers')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => SupplierModel.fromJson(json))
        .toList();
  }

  Future<SupplierModel> createSupplier({
    required String outletId,
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _supabase
        .from('suppliers')
        .insert({
          'outlet_id': outletId,
          'name': name,
          'contact_person': contactPerson,
          'phone': phone,
          'email': email,
          'address': address,
          'notes': notes,
        })
        .select()
        .single();

    return SupplierModel.fromJson(response);
  }

  Future<void> updateSupplier({
    required String id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) data['name'] = name;
    if (contactPerson != null) data['contact_person'] = contactPerson;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (address != null) data['address'] = address;
    if (notes != null) data['notes'] = notes;

    await _supabase
        .from('suppliers')
        .update(data)
        .eq('id', id);
  }

  Future<void> deleteSupplier(String id) async {
    await _supabase
        .from('suppliers')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
