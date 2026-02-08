import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/backup_repository.dart';

final backupRepositoryProvider = Provider((ref) => BackupRepository());

final backupSummaryProvider = FutureProvider<BackupSummary>((ref) async {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(backupRepositoryProvider);
  return repo.getBackupSummary(outletId);
});

/// State for backup operations (export/import progress).
class BackupState {
  final bool isExporting;
  final bool isImporting;
  final String? message;
  final bool isError;
  final Map<String, int>? importResult;

  const BackupState({
    this.isExporting = false,
    this.isImporting = false,
    this.message,
    this.isError = false,
    this.importResult,
  });

  BackupState copyWith({
    bool? isExporting,
    bool? isImporting,
    String? message,
    bool? isError,
    Map<String, int>? importResult,
  }) {
    return BackupState(
      isExporting: isExporting ?? this.isExporting,
      isImporting: isImporting ?? this.isImporting,
      message: message ?? this.message,
      isError: isError ?? this.isError,
      importResult: importResult ?? this.importResult,
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final BackupRepository _repo;
  final String _outletId;

  BackupNotifier(this._repo, {required String outletId})
      : _outletId = outletId,
        super(const BackupState());

  /// Export all data and return the JSON map for download.
  Future<Map<String, dynamic>?> exportData() async {
    state = const BackupState(isExporting: true, message: 'Mengekspor data...');
    try {
      final data = await _repo.exportAllData(_outletId);
      state = const BackupState(
        isExporting: false,
        message: 'Backup berhasil diunduh!',
      );
      return data;
    } catch (e) {
      state = BackupState(
        isExporting: false,
        message: 'Gagal mengekspor data: $e',
        isError: true,
      );
      return null;
    }
  }

  /// Import data from a parsed JSON map.
  Future<bool> importData(Map<String, dynamic> jsonData) async {
    state = const BackupState(isImporting: true, message: 'Memvalidasi backup...');

    // Validate
    final validationError = _repo.validateBackup(jsonData);
    if (validationError != null) {
      state = BackupState(
        isImporting: false,
        message: validationError,
        isError: true,
      );
      return false;
    }

    state = const BackupState(isImporting: true, message: 'Mengimpor data...');

    try {
      final result = await _repo.importData(jsonData);
      state = BackupState(
        isImporting: false,
        message: 'Import berhasil!',
        importResult: result,
      );
      return true;
    } catch (e) {
      state = BackupState(
        isImporting: false,
        message: 'Gagal mengimpor data: $e',
        isError: true,
      );
      return false;
    }
  }

  void clearMessage() {
    state = const BackupState();
  }
}

final backupNotifierProvider =
    StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(backupRepositoryProvider);
  return BackupNotifier(repo, outletId: outletId);
});
