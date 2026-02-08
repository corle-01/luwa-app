import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:utter_app/core/models/ai_action_log.dart';
import 'package:utter_app/core/repositories/ai_action_log_repository.dart';

/// State for the AI action log viewer.
class AiActionLogState {
  /// List of action logs.
  final List<AiActionLog> logs;

  /// List of actions pending approval.
  final List<AiActionLog> pendingApprovals;

  /// Whether logs are currently being loaded.
  final bool isLoading;

  /// Error message from the last failed operation, if any.
  final String? error;

  /// The outlet ID that logs are loaded for.
  final String? outletId;

  /// Whether there are more logs to load (for pagination).
  final bool hasMore;

  const AiActionLogState({
    this.logs = const [],
    this.pendingApprovals = const [],
    this.isLoading = false,
    this.error,
    this.outletId,
    this.hasMore = true,
  });

  /// Get logs that can still be undone.
  List<AiActionLog> get undoableLogs =>
      logs.where((log) => log.canUndo).toList();

  AiActionLogState copyWith({
    List<AiActionLog>? logs,
    List<AiActionLog>? pendingApprovals,
    bool? isLoading,
    String? error,
    String? outletId,
    bool? hasMore,
    bool clearError = false,
  }) {
    return AiActionLogState(
      logs: logs ?? this.logs,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      outletId: outletId ?? this.outletId,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Notifier that manages AI action log state.
///
/// Handles loading action logs, undo operations, and approval workflows.
class AiActionLogNotifier extends StateNotifier<AiActionLogState> {
  final AiActionLogRepository _actionLogRepo;

  /// The number of logs per page for pagination.
  static const int _pageSize = 20;

  AiActionLogNotifier({AiActionLogRepository? actionLogRepo})
      : _actionLogRepo = actionLogRepo ?? AiActionLogRepository(),
        super(const AiActionLogState());

  /// Load action logs for a specific outlet.
  ///
  /// Resets the list and loads the first page. Optionally filter
  /// by [featureKey].
  Future<void> loadLogs(
    String outletId, {
    String? featureKey,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      outletId: outletId,
    );

    try {
      final logs = await _actionLogRepo.getActionLogs(
        outletId,
        limit: _pageSize,
        offset: 0,
        featureKey: featureKey,
      );

      final pendingApprovals =
          await _actionLogRepo.getPendingApprovals(outletId);

      state = state.copyWith(
        logs: logs,
        pendingApprovals: pendingApprovals,
        isLoading: false,
        hasMore: logs.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load action logs: $e',
      );
    }
  }

  /// Load the next page of action logs.
  Future<void> loadMore({String? featureKey}) async {
    if (state.isLoading || !state.hasMore || state.outletId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final moreLogs = await _actionLogRepo.getActionLogs(
        state.outletId!,
        limit: _pageSize,
        offset: state.logs.length,
        featureKey: featureKey,
      );

      state = state.copyWith(
        logs: [...state.logs, ...moreLogs],
        isLoading: false,
        hasMore: moreLogs.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load more logs: $e',
      );
    }
  }

  /// Undo a specific action.
  ///
  /// Marks the action as undone in the database and updates the local state.
  Future<void> undoAction(String id) async {
    try {
      final updatedLog = await _actionLogRepo.undoAction(id);

      // Update the log in the local state
      final updatedLogs = state.logs.map((log) {
        return log.id == updatedLog.id ? updatedLog : log;
      }).toList();

      state = state.copyWith(logs: updatedLogs);
    } catch (e) {
      state = state.copyWith(
        error: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Failed to undo action: $e',
      );
    }
  }

  /// Approve a pending action.
  Future<void> approveAction(String id, String approvedBy) async {
    try {
      final updatedLog =
          await _actionLogRepo.approveAction(id, approvedBy);

      // Update logs and remove from pending
      final updatedLogs = state.logs.map((log) {
        return log.id == updatedLog.id ? updatedLog : log;
      }).toList();

      final updatedPending =
          state.pendingApprovals.where((log) => log.id != id).toList();

      state = state.copyWith(
        logs: updatedLogs,
        pendingApprovals: updatedPending,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to approve action: $e',
      );
    }
  }

  /// Reject a pending action.
  Future<void> rejectAction(String id, String rejectedBy) async {
    try {
      final updatedLog =
          await _actionLogRepo.rejectAction(id, rejectedBy);

      // Update logs and remove from pending
      final updatedLogs = state.logs.map((log) {
        return log.id == updatedLog.id ? updatedLog : log;
      }).toList();

      final updatedPending =
          state.pendingApprovals.where((log) => log.id != id).toList();

      state = state.copyWith(
        logs: updatedLogs,
        pendingApprovals: updatedPending,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to reject action: $e',
      );
    }
  }

  /// Refresh the logs from the database.
  Future<void> refresh() async {
    if (state.outletId == null) return;
    await loadLogs(state.outletId!);
  }

  /// Clear the error state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for the AI action log state.
final aiActionLogProvider =
    StateNotifierProvider<AiActionLogNotifier, AiActionLogState>((ref) {
  return AiActionLogNotifier();
});

/// Provider that exposes just the list of action logs.
final aiActionLogsProvider = Provider<List<AiActionLog>>((ref) {
  return ref.watch(aiActionLogProvider).logs;
});

/// Provider that exposes the list of pending approvals.
final aiPendingApprovalsProvider = Provider<List<AiActionLog>>((ref) {
  return ref.watch(aiActionLogProvider).pendingApprovals;
});

/// Provider that exposes the count of pending approvals.
final aiPendingApprovalCountProvider = Provider<int>((ref) {
  return ref.watch(aiActionLogProvider).pendingApprovals.length;
});

/// Provider that exposes undoable actions.
final aiUndoableActionsProvider = Provider<List<AiActionLog>>((ref) {
  return ref.watch(aiActionLogProvider).undoableLogs;
});
