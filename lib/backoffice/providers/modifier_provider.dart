import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/modifier_repository.dart';

final boModifierRepositoryProvider =
    Provider((ref) => BOModifierRepository());

final boModifierGroupsProvider =
    FutureProvider<List<BOModifierGroup>>((ref) async {
  final repo = ref.watch(boModifierRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getModifierGroups(outletId);
});

/// Provider for product modifier assignments.
/// Pass a productId to get its assigned modifier group IDs.
final productModifierAssignmentsProvider =
    FutureProvider.family<List<ProductModifierAssignment>, String>(
  (ref, productId) async {
    final repo = ref.watch(boModifierRepositoryProvider);
    return repo.getProductModifiers(productId);
  },
);

/// Provider for modifier option ingredients.
/// Pass an optionId to get its linked ingredients.
final modifierOptionIngredientsProvider =
    FutureProvider.family<List<ModifierOptionIngredient>, String>(
  (ref, optionId) async {
    final repo = ref.watch(boModifierRepositoryProvider);
    return repo.getModifierOptionIngredients(optionId);
  },
);
