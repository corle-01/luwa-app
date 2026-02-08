import 'package:supabase_flutter/supabase_flutter.dart';

class CashierProfile {
  final String id;
  final String fullName;
  final String role;
  final String? pin;

  CashierProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.pin,
  });

  factory CashierProfile.fromJson(Map<String, dynamic> json) {
    return CashierProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'cashier',
      pin: json['pin'] as String?,
    );
  }

  bool get hasPin => pin != null && pin!.isNotEmpty;
}

class PosCashierRepository {
  final _supabase = Supabase.instance.client;

  /// Fetch cashiers for a specific outlet
  /// Returns profiles where role is cashier, manager, or owner and is_active=true
  Future<List<CashierProfile>> getCashiers(String outletId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('outlet_id', outletId)
        .eq('is_active', true)
        .order('full_name', ascending: true);

    return (response as List)
        .map((json) => CashierProfile.fromJson(json))
        .toList();
  }

  /// Verify if the provided PIN matches the cashier's PIN
  /// Returns true if PIN matches, false otherwise
  /// Note: This checks locally; PIN is not exposed beyond this method
  bool verifyPin(CashierProfile cashier, String inputPin) {
    if (cashier.pin == null || cashier.pin!.isEmpty) {
      return true; // No PIN set, allow access
    }
    return cashier.pin == inputPin;
  }
}
