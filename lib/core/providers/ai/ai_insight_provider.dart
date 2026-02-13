import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:luwa_app/core/models/ai_insight.dart';
import 'package:luwa_app/core/repositories/ai_insight_repository.dart';
import 'package:luwa_app/core/services/ai/ai_insight_manager.dart';

/// State for the AI insights panel.
class AiInsightState {
  /// List of active insights.
  final List<AiInsight> insights;

  /// Number of unread/active insights.
  final int unreadCount;

  /// Whether insights are currently being loaded.
  final bool isLoading;

  /// Error message from the last failed operation, if any.
  final String? error;

  /// The outlet ID that insights are loaded for.
  final String? outletId;

  const AiInsightState({
    this.insights = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
    this.outletId,
  });

  AiInsightState copyWith({
    List<AiInsight>? insights,
    int? unreadCount,
    bool? isLoading,
    String? error,
    String? outletId,
    bool clearError = false,
  }) {
    return AiInsightState(
      insights: insights ?? this.insights,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      outletId: outletId ?? this.outletId,
    );
  }
}

/// Notifier that manages AI insight state.
///
/// Handles loading insights, processing user actions (dismiss, act on),
/// and subscribing to real-time updates from Supabase.
class AiInsightNotifier extends StateNotifier<AiInsightState> {
  final AiInsightManager _insightManager;
  final AiInsightRepository _insightRepo;

  /// Active Supabase realtime channel for insight updates.
  RealtimeChannel? _realtimeChannel;

  AiInsightNotifier({
    AiInsightManager? insightManager,
    AiInsightRepository? insightRepo,
  })  : _insightManager = insightManager ?? AiInsightManager(),
        _insightRepo = insightRepo ?? AiInsightRepository(),
        super(const AiInsightState());

  /// Load active insights for an outlet and subscribe to real-time updates.
  Future<void> loadInsights(String outletId) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      outletId: outletId,
    );

    try {
      final insights = await _insightManager.loadInsights(
        outletId,
        forceRefresh: true,
      );
      final unreadCount = await _insightManager.getUnreadCount(outletId);

      state = state.copyWith(
        insights: insights,
        unreadCount: unreadCount,
        isLoading: false,
      );

      // Subscribe to real-time updates
      _subscribeToRealtime(outletId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load insights: $e',
      );
    }
  }

  /// Dismiss an insight (user doesn't want to see it anymore).
  Future<void> dismissInsight(String id) async {
    try {
      await _insightManager.handleInsightAction(id, 'dismiss');

      // Update local state
      final updatedInsights =
          state.insights.where((i) => i.id != id).toList();
      state = state.copyWith(
        insights: updatedInsights,
        unreadCount: updatedInsights.length,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to dismiss insight: $e',
      );
    }
  }

  /// Mark an insight as acted upon.
  Future<void> actOnInsight(String id) async {
    try {
      await _insightManager.handleInsightAction(id, 'act');

      // Update local state
      final updatedInsights =
          state.insights.where((i) => i.id != id).toList();
      state = state.copyWith(
        insights: updatedInsights,
        unreadCount: updatedInsights.length,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to act on insight: $e',
      );
    }
  }

  /// Refresh insights from the database.
  Future<void> refresh() async {
    if (state.outletId == null) return;
    await loadInsights(state.outletId!);
  }

  /// Subscribe to real-time changes on the insights table.
  void _subscribeToRealtime(String outletId) {
    // Unsubscribe from any existing channel
    _unsubscribeFromRealtime();

    _realtimeChannel = _insightRepo.subscribeToInsights(
      outletId,
      onInsert: (insight) {
        if (!mounted) return;
        // Add new insight to the top of the list
        final updatedInsights = [insight, ...state.insights];
        state = state.copyWith(
          insights: updatedInsights,
          unreadCount: updatedInsights.length,
        );
      },
      onUpdate: (insight) {
        if (!mounted) return;
        if (insight.isActive) {
          // Update the insight in place
          final updatedInsights = state.insights.map((i) {
            return i.id == insight.id ? insight : i;
          }).toList();
          state = state.copyWith(insights: updatedInsights);
        } else {
          // Remove non-active insights
          final updatedInsights =
              state.insights.where((i) => i.id != insight.id).toList();
          state = state.copyWith(
            insights: updatedInsights,
            unreadCount: updatedInsights.length,
          );
        }
      },
      onDelete: (oldRecord) {
        if (!mounted) return;
        final deletedId = oldRecord['id'] as String?;
        if (deletedId != null) {
          final updatedInsights =
              state.insights.where((i) => i.id != deletedId).toList();
          state = state.copyWith(
            insights: updatedInsights,
            unreadCount: updatedInsights.length,
          );
        }
      },
    );
  }

  /// Unsubscribe from real-time updates.
  void _unsubscribeFromRealtime() {
    if (_realtimeChannel != null && state.outletId != null) {
      _insightRepo.unsubscribeFromInsights(state.outletId!);
      _realtimeChannel = null;
    }
  }

  /// Clear the error state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }
}

/// Provider for the AI insight state.
final aiInsightProvider =
    StateNotifierProvider<AiInsightNotifier, AiInsightState>((ref) {
  return AiInsightNotifier();
});

/// Provider that exposes just the list of active insights.
final aiActiveInsightsProvider = Provider<List<AiInsight>>((ref) {
  return ref.watch(aiInsightProvider).insights;
});

/// Provider that exposes the unread insight count.
final aiInsightUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(aiInsightProvider).unreadCount;
});

/// Provider that exposes critical insights only.
final aiCriticalInsightsProvider = Provider<List<AiInsight>>((ref) {
  return ref
      .watch(aiInsightProvider)
      .insights
      .where((i) => i.severity == 'critical')
      .toList();
});
