import 'package:supabase_flutter/supabase_flutter.dart';

class StaffProfile {
  final String id;
  final String fullName;
  final String role;
  final String? pin;
  final String? email;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;

  StaffProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.pin,
    this.email,
    this.phone,
    this.isActive = true,
    this.createdAt,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    return StaffProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'cashier',
      pin: json['pin'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  bool get hasPin => pin != null && pin!.isNotEmpty;

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'cashier':
        return 'Kasir';
      case 'kitchen':
        return 'Kitchen';
      case 'waiter':
        return 'Waiter';
      default:
        return role;
    }
  }
}

class StaffRepository {
  final _supabase = Supabase.instance.client;

  Future<List<StaffProfile>> getStaff(String outletId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('full_name', ascending: true);

    return (response as List)
        .map((json) => StaffProfile.fromJson(json))
        .toList();
  }

  Future<String> createStaff({
    required String outletId,
    required String fullName,
    required String role,
    String? pin,
    String? email,
    String? phone,
  }) async {
    final response = await _supabase.rpc('create_staff_profile', params: {
      'p_outlet_id': outletId,
      'p_full_name': fullName,
      'p_role': role,
      'p_pin': pin,
      'p_email': email,
      'p_phone': phone,
    });

    return response as String;
  }

  Future<void> updateStaff({
    required String id,
    String? fullName,
    String? role,
    String? pin,
    String? email,
    String? phone,
  }) async {
    await _supabase.rpc('update_staff_profile', params: {
      'p_id': id,
      'p_full_name': fullName,
      'p_role': role,
      'p_pin': pin,
      'p_email': email,
      'p_phone': phone,
    });
  }

  Future<void> deleteStaff(String id) async {
    await _supabase.rpc('delete_staff_profile', params: {
      'p_id': id,
    });
  }
}
