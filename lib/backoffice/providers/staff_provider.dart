import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/staff_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final staffRepositoryProvider = Provider((ref) => StaffRepository());

final staffListProvider = FutureProvider<List<StaffProfile>>((ref) async {
  final repo = ref.watch(staffRepositoryProvider);
  return repo.getStaff(_outletId);
});
