import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Current selected outlet
final currentOutletProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// Current outlet ID (convenience provider - falls back to default)
final currentOutletIdProvider = Provider<String>((ref) {
  final outlet = ref.watch(currentOutletProvider);
  return outlet?['id'] as String? ?? 'a0000000-0000-0000-0000-000000000001';
});

// List of all outlets
final outletsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('outlets')
      .select()
      .eq('is_active', true)
      .order('name');
  return List<Map<String, dynamic>>.from(res);
});
