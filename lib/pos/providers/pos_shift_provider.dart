import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/shift.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/pos_shift_repository.dart';

final posShiftRepositoryProvider = Provider((ref) => PosShiftRepository());

class PosShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final Ref _ref;
  PosShiftNotifier(this._ref) : super(const AsyncLoading()) {
    loadActiveShift();
  }

  String get _outletId => _ref.read(currentOutletIdProvider);

  Future<void> loadActiveShift() async {
    state = const AsyncLoading();
    try {
      final repo = _ref.read(posShiftRepositoryProvider);
      final shift = await repo.getActiveShift(_outletId);
      state = AsyncData(shift);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<Shift?> openShift(String cashierId, double openingCash) async {
    try {
      final repo = _ref.read(posShiftRepositoryProvider);
      final shift = await repo.openShift(
        outletId: _outletId,
        cashierId: cashierId,
        openingCash: openingCash,
      );
      state = AsyncData(shift);
      return shift;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
    }
  }

  Future<void> closeShift(double closingCash, {String? notes}) async {
    final current = state.value;
    if (current == null) return;
    try {
      final repo = _ref.read(posShiftRepositoryProvider);
      await repo.closeShift(shiftId: current.id, closingCash: closingCash, notes: notes);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> refresh() async => loadActiveShift();
}

final posShiftNotifierProvider = StateNotifierProvider<PosShiftNotifier, AsyncValue<Shift?>>(
  (ref) => PosShiftNotifier(ref),
);

final posShiftSummaryProvider = FutureProvider.family<ShiftSummary, String>((ref, shiftId) async {
  final repo = ref.watch(posShiftRepositoryProvider);
  return repo.getShiftSummary(shiftId);
});
