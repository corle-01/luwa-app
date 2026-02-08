import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:utter_app/core/models/ai_trust_setting.dart';
import 'package:utter_app/core/repositories/ai_trust_repository.dart';

/// State for AI trust settings management.
class AiTrustState {
  /// List of all trust settings for the current outlet.
  final List<AiTrustSetting> settings;

  /// Whether settings are currently being loaded.
  final bool isLoading;

  /// Error message from the last failed operation, if any.
  final String? error;

  /// The outlet ID that settings are loaded for.
  final String? outletId;

  const AiTrustState({
    this.settings = const [],
    this.isLoading = false,
    this.error,
    this.outletId,
  });

  /// Get a specific trust setting by feature key.
  AiTrustSetting? getByFeatureKey(String featureKey) {
    try {
      return settings.firstWhere((s) => s.featureKey == featureKey);
    } catch (_) {
      return null;
    }
  }

  /// Get the trust level for a specific feature.
  int getTrustLevel(String featureKey) {
    return getByFeatureKey(featureKey)?.trustLevel ?? 0;
  }

  AiTrustState copyWith({
    List<AiTrustSetting>? settings,
    bool? isLoading,
    String? error,
    String? outletId,
    bool clearError = false,
  }) {
    return AiTrustState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      outletId: outletId ?? this.outletId,
    );
  }
}

/// Notifier that manages AI trust settings state.
///
/// Handles loading and updating trust levels for the current outlet.
class AiTrustNotifier extends StateNotifier<AiTrustState> {
  final AiTrustRepository _trustRepo;

  AiTrustNotifier({AiTrustRepository? trustRepo})
      : _trustRepo = trustRepo ?? AiTrustRepository(),
        super(const AiTrustState());

  /// Load all trust settings for a specific outlet.
  Future<void> loadSettings(String outletId) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      outletId: outletId,
    );

    try {
      final settings = await _trustRepo.getTrustSettings(outletId);
      state = state.copyWith(
        settings: settings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load trust settings: $e',
      );
    }
  }

  /// Update the trust level for a specific feature.
  ///
  /// [featureKey] identifies which feature to update.
  /// [level] is the new trust level (0-3).
  /// [updatedBy] is the user ID making the change.
  Future<void> updateTrustLevel(
    String featureKey,
    int level, {
    required String updatedBy,
  }) async {
    final setting = state.getByFeatureKey(featureKey);
    if (setting == null) {
      state = state.copyWith(
        error: 'Trust setting not found for feature: $featureKey',
      );
      return;
    }

    try {
      final updated = await _trustRepo.updateTrustLevel(
        setting.id,
        level,
        updatedBy,
      );

      // Update the setting in the local state
      final updatedSettings = state.settings.map((s) {
        return s.id == updated.id ? updated : s;
      }).toList();

      state = state.copyWith(settings: updatedSettings);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to update trust level: $e',
      );
    }
  }

  /// Toggle the enabled/disabled state of a feature.
  Future<void> toggleFeature(
    String featureKey, {
    required bool isEnabled,
    required String updatedBy,
  }) async {
    final setting = state.getByFeatureKey(featureKey);
    if (setting == null) {
      state = state.copyWith(
        error: 'Trust setting not found for feature: $featureKey',
      );
      return;
    }

    try {
      final updated = await _trustRepo.toggleEnabled(
        setting.id,
        isEnabled,
        updatedBy,
      );

      // Update the setting in the local state
      final updatedSettings = state.settings.map((s) {
        return s.id == updated.id ? updated : s;
      }).toList();

      state = state.copyWith(settings: updatedSettings);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to toggle feature: $e',
      );
    }
  }

  /// Refresh the settings from the database.
  Future<void> refresh() async {
    if (state.outletId == null) return;
    await loadSettings(state.outletId!);
  }

  /// Clear the error state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for the AI trust settings state.
final aiTrustProvider =
    StateNotifierProvider<AiTrustNotifier, AiTrustState>((ref) {
  return AiTrustNotifier();
});

/// Provider that exposes just the list of trust settings.
final aiTrustSettingsProvider = Provider<List<AiTrustSetting>>((ref) {
  return ref.watch(aiTrustProvider).settings;
});

/// Provider that exposes the loading state for trust settings.
final aiTrustLoadingProvider = Provider<bool>((ref) {
  return ref.watch(aiTrustProvider).isLoading;
});

/// Provider family that returns the trust level for a specific feature key.
final aiFeatureTrustLevelProvider =
    Provider.family<int, String>((ref, featureKey) {
  return ref.watch(aiTrustProvider).getTrustLevel(featureKey);
});
