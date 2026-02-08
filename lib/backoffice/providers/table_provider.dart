import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/table_repository.dart';

final tableRepositoryProvider = Provider((ref) => TableRepository());

final tableListProvider = FutureProvider<List<TableModel>>((ref) async {
  final repo = ref.watch(tableRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTables(outletId);
});
