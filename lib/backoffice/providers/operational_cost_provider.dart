import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/operational_cost.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/operational_cost_repository.dart';

final operationalCostRepositoryProvider = Provider<OperationalCostRepository>((ref) {
  return OperationalCostRepository();
});

final operationalCostsProvider = FutureProvider<List<OperationalCost>>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  return ref.read(operationalCostRepositoryProvider).getCosts(outletId);
});

final totalMonthlyCostProvider = FutureProvider<double>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  return ref.read(operationalCostRepositoryProvider).getTotalMonthlyCost(outletId);
});

final costsByCategoryProvider = FutureProvider<Map<String, double>>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  return ref.read(operationalCostRepositoryProvider).getCostsByCategory(outletId);
});

final bonusPercentageProvider = FutureProvider<double>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  return ref.read(operationalCostRepositoryProvider).getBonusPercentage(outletId);
});
