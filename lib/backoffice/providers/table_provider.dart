import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/table_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final tableRepositoryProvider = Provider((ref) => TableRepository());

final tableListProvider = FutureProvider<List<TableModel>>((ref) async {
  final repo = ref.watch(tableRepositoryProvider);
  return repo.getTables(_outletId);
});
