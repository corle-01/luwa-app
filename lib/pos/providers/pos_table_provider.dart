import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/pos_table_repository.dart';

final posTableRepositoryProvider = Provider((ref) => PosTableRepository());

final posTablesProvider = FutureProvider<List<RestaurantTable>>((ref) async {
  final repo = ref.watch(posTableRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTables(outletId);
});
