import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/pos_modifier_repository.dart';

final posModifierRepositoryProvider = Provider((ref) => PosModifierRepository());

final posModifierGroupsProvider = FutureProvider.family<List<ModifierGroup>, String>((ref, productId) async {
  final repo = ref.watch(posModifierRepositoryProvider);
  return repo.getModifierGroups(productId);
});
