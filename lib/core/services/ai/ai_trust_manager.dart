import 'package:luwa_app/core/config/app_constants.dart';
import 'package:luwa_app/core/models/ai_trust_setting.dart';
import 'package:luwa_app/core/repositories/ai_trust_repository.dart';

/// Manages AI trust level permissions and checks.
///
/// The trust manager determines whether the AI is allowed to perform
/// a specific action based on the outlet's trust settings for the
/// corresponding feature.
class AiTrustManager {
  final AiTrustRepository _trustRepo;

  /// Local cache of trust settings to reduce database lookups.
  final Map<String, AiTrustSetting> _cache = {};

  AiTrustManager({AiTrustRepository? trustRepo})
      : _trustRepo = trustRepo ?? AiTrustRepository();

  /// Check whether the AI has permission to perform a specific action
  /// type for a given feature in an outlet.
  ///
  /// [outletId] - The outlet to check permissions for.
  /// [featureKey] - The AI feature being invoked (e.g., 'stock_alert').
  /// [actionType] - The type of action being attempted (e.g., 'auto_executed').
  ///
  /// Returns `true` if the action is permitted based on the trust level.
  Future<bool> checkPermission(
    String outletId,
    String featureKey,
    String actionType,
  ) async {
    final setting = await _getTrustSetting(outletId, featureKey);

    // If no setting exists, default to inform-only (most restrictive)
    if (setting == null) return actionType == AppConstants.actionInformed;

    // If the feature is disabled, no actions are permitted
    if (!setting.isEnabled) return false;

    // Check if the action type is allowed at the current trust level
    return _isActionAllowed(setting.trustLevel, actionType);
  }

  /// Determine whether an action type is allowed at a given trust level.
  ///
  /// Trust level hierarchy:
  /// - Level 0 (Inform Only): Only 'informed' actions
  /// - Level 1 (Suggest + Confirm): 'informed' and 'suggested' actions
  /// - Level 2 (Auto + Notify): All except 'silent_executed'
  /// - Level 3 (Full Auto): All action types
  bool _isActionAllowed(int trustLevel, String actionType) {
    switch (trustLevel) {
      case AppConstants.trustLevelInform: // 0
        return actionType == AppConstants.actionInformed;

      case AppConstants.trustLevelSuggest: // 1
        return actionType == AppConstants.actionInformed ||
            actionType == AppConstants.actionSuggested;

      case AppConstants.trustLevelAuto: // 2
        return actionType == AppConstants.actionInformed ||
            actionType == AppConstants.actionSuggested ||
            actionType == AppConstants.actionAutoExecuted ||
            actionType == AppConstants.actionApproved ||
            actionType == AppConstants.actionRejected ||
            actionType == AppConstants.actionEdited ||
            actionType == AppConstants.actionUndone;

      case AppConstants.trustLevelSilent: // 3
        return true; // All actions allowed

      default:
        return false;
    }
  }

  /// Get a human-readable label for a trust level.
  String getTrustLabel(int level) {
    switch (level) {
      case 0:
        return 'Inform Only';
      case 1:
        return 'Suggest + Confirm';
      case 2:
        return 'Auto + Notify';
      case 3:
        return 'Full Auto';
      default:
        return 'Unknown';
    }
  }

  /// Get the description for a trust level.
  String getTrustDescription(int level) {
    switch (level) {
      case 0:
        return 'AI will only inform you about observations and issues. '
            'No actions are taken automatically.';
      case 1:
        return 'AI will suggest actions and wait for your confirmation '
            'before executing them.';
      case 2:
        return 'AI will automatically execute actions and notify you. '
            'You can undo actions within the undo window.';
      case 3:
        return 'AI will automatically execute actions silently. '
            'Actions are logged but you will not be notified.';
      default:
        return 'Unknown trust level.';
    }
  }

  /// Get the required trust level for a given action type.
  int getRequiredTrustLevel(String actionType) {
    switch (actionType) {
      case AppConstants.actionInformed:
        return AppConstants.trustLevelInform;
      case AppConstants.actionSuggested:
        return AppConstants.trustLevelSuggest;
      case AppConstants.actionAutoExecuted:
        return AppConstants.trustLevelAuto;
      case AppConstants.actionSilentExecuted:
        return AppConstants.trustLevelSilent;
      default:
        return AppConstants.trustLevelInform;
    }
  }

  /// Get the trust setting from cache or database.
  Future<AiTrustSetting?> _getTrustSetting(
    String outletId,
    String featureKey,
  ) async {
    final cacheKey = '${outletId}_$featureKey';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final setting = await _trustRepo.getTrustLevel(outletId, featureKey);
    if (setting != null) {
      _cache[cacheKey] = setting;
    }
    return setting;
  }

  /// Clear the local cache for a specific outlet.
  void clearCache({String? outletId}) {
    if (outletId != null) {
      _cache.removeWhere((key, _) => key.startsWith('${outletId}_'));
    } else {
      _cache.clear();
    }
  }

  /// Preload all trust settings for an outlet into the cache.
  Future<void> preloadSettings(String outletId) async {
    final settings = await _trustRepo.getTrustSettings(outletId);
    for (final setting in settings) {
      _cache['${outletId}_${setting.featureKey}'] = setting;
    }
  }
}
