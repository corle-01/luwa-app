import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/staff_repository.dart';

final staffRepositoryProvider = Provider((ref) => StaffRepository());

final staffListProvider = FutureProvider<List<StaffProfile>>((ref) async {
  final repo = ref.watch(staffRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getStaff(outletId);
});
