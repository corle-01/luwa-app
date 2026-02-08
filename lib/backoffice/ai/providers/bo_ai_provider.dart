import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the Back Office AI dashboard.
///
/// Manages UI state specific to the Back Office AI pages,
/// including filters, active tabs, and view preferences.
class BoAiState {
  /// Currently selected insight severity filter.
  /// null means "All" (no filter).
  final String? selectedInsightFilter;

  /// Currently selected feature key filter for action logs.
  /// null means "All" (no filter).
  final String? selectedLogFilter;

  /// Date range start for action log filtering.
  final DateTime? logDateFrom;

  /// Date range end for action log filtering.
  final DateTime? logDateTo;

  /// Active tab index for mobile dashboard layout.
  /// 0 = Insights, 1 = Chat, 2 = Actions
  final int dashboardTab;

  /// Search query for conversation history.
  final String conversationSearchQuery;

  const BoAiState({
    this.selectedInsightFilter,
    this.selectedLogFilter,
    this.logDateFrom,
    this.logDateTo,
    this.dashboardTab = 0,
    this.conversationSearchQuery = '',
  });

  BoAiState copyWith({
    String? selectedInsightFilter,
    String? selectedLogFilter,
    DateTime? logDateFrom,
    DateTime? logDateTo,
    int? dashboardTab,
    String? conversationSearchQuery,
    bool clearInsightFilter = false,
    bool clearLogFilter = false,
    bool clearDateRange = false,
  }) {
    return BoAiState(
      selectedInsightFilter: clearInsightFilter
          ? null
          : (selectedInsightFilter ?? this.selectedInsightFilter),
      selectedLogFilter: clearLogFilter
          ? null
          : (selectedLogFilter ?? this.selectedLogFilter),
      logDateFrom:
          clearDateRange ? null : (logDateFrom ?? this.logDateFrom),
      logDateTo: clearDateRange ? null : (logDateTo ?? this.logDateTo),
      dashboardTab: dashboardTab ?? this.dashboardTab,
      conversationSearchQuery:
          conversationSearchQuery ?? this.conversationSearchQuery,
    );
  }
}

/// StateNotifier that manages Back Office AI UI state.
class BoAiNotifier extends StateNotifier<BoAiState> {
  BoAiNotifier() : super(const BoAiState());

  /// Set the insight severity filter.
  /// Pass null to clear the filter (show all).
  void setInsightFilter(String? severity) {
    if (severity == null) {
      state = state.copyWith(clearInsightFilter: true);
    } else {
      state = state.copyWith(selectedInsightFilter: severity);
    }
  }

  /// Set the action log feature key filter.
  /// Pass null to clear the filter (show all).
  void setLogFilter(String? featureKey) {
    if (featureKey == null) {
      state = state.copyWith(clearLogFilter: true);
    } else {
      state = state.copyWith(selectedLogFilter: featureKey);
    }
  }

  /// Set the date range for action log filtering.
  void setLogDateRange(DateTime? from, DateTime? to) {
    if (from == null && to == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      state = state.copyWith(logDateFrom: from, logDateTo: to);
    }
  }

  /// Switch the active mobile dashboard tab.
  void switchTab(int index) {
    state = state.copyWith(dashboardTab: index);
  }

  /// Update the conversation search query.
  void setConversationSearch(String query) {
    state = state.copyWith(conversationSearchQuery: query);
  }

  /// Reset all filters to defaults.
  void resetFilters() {
    state = const BoAiState();
  }
}

/// Provider for the Back Office AI UI state.
final boAiProvider =
    StateNotifierProvider<BoAiNotifier, BoAiState>((ref) {
  return BoAiNotifier();
});

/// Provider that exposes the selected insight filter.
final boAiInsightFilterProvider = Provider<String?>((ref) {
  return ref.watch(boAiProvider).selectedInsightFilter;
});

/// Provider that exposes the selected log filter.
final boAiLogFilterProvider = Provider<String?>((ref) {
  return ref.watch(boAiProvider).selectedLogFilter;
});

/// Provider that exposes the active dashboard tab index.
final boAiDashboardTabProvider = Provider<int>((ref) {
  return ref.watch(boAiProvider).dashboardTab;
});
