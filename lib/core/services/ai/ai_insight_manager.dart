import 'package:utter_app/core/models/ai_insight.dart';
import 'package:utter_app/core/repositories/ai_insight_repository.dart';

/// Manages AI insights lifecycle and operations.
///
/// Provides a high-level interface for loading, processing, and managing
/// AI-generated insights. Handles caching, filtering, and user actions
/// on insights.
class AiInsightManager {
  final AiInsightRepository _insightRepo;

  /// Local cache of active insights by outlet.
  final Map<String, List<AiInsight>> _insightsCache = {};

  AiInsightManager({AiInsightRepository? insightRepo})
      : _insightRepo = insightRepo ?? AiInsightRepository();

  /// Load all active insights for an outlet.
  ///
  /// Results are cached locally and can be refreshed by calling
  /// this method again with [forceRefresh] set to true.
  Future<List<AiInsight>> loadInsights(
    String outletId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _insightsCache.containsKey(outletId)) {
      return _insightsCache[outletId]!;
    }

    // Expire stale insights first
    await _insightRepo.expireOldInsights(outletId);

    // Load active insights
    final insights = await _insightRepo.getActiveInsights(outletId);
    _insightsCache[outletId] = insights;
    return insights;
  }

  /// Handle a user action on an insight.
  ///
  /// Supported actions:
  /// - 'dismiss': Mark the insight as dismissed
  /// - 'act': Mark the insight as acted upon
  ///
  /// Returns the updated insight.
  Future<AiInsight> handleInsightAction(
    String insightId,
    String action,
  ) async {
    AiInsight updatedInsight;

    switch (action) {
      case 'dismiss':
        updatedInsight = await _insightRepo.dismissInsight(insightId);
        break;
      case 'act':
        updatedInsight = await _insightRepo.actOnInsight(insightId);
        break;
      default:
        throw ArgumentError('Unknown insight action: $action');
    }

    // Update the cache
    _updateCacheEntry(updatedInsight);

    return updatedInsight;
  }

  /// Get the count of unread/active insights for an outlet.
  Future<int> getUnreadCount(String outletId) async {
    // Check cache first
    if (_insightsCache.containsKey(outletId)) {
      return _insightsCache[outletId]!
          .where((i) => i.isActive)
          .length;
    }

    return await _insightRepo.getInsightCount(outletId);
  }

  /// Get insights filtered by type from the cache or database.
  Future<List<AiInsight>> getInsightsByType(
    String outletId,
    String insightType,
  ) async {
    final insights = await loadInsights(outletId);
    return insights
        .where((i) => i.insightType == insightType)
        .toList();
  }

  /// Get insights filtered by severity from the cache.
  Future<List<AiInsight>> getInsightsBySeverity(
    String outletId,
    String severity,
  ) async {
    final insights = await loadInsights(outletId);
    return insights
        .where((i) => i.severity == severity)
        .toList();
  }

  /// Get critical insights that need immediate attention.
  Future<List<AiInsight>> getCriticalInsights(String outletId) async {
    final insights = await loadInsights(outletId);
    return insights
        .where((i) => i.severity == 'critical')
        .toList();
  }

  /// Update a single entry in the cache after a mutation.
  void _updateCacheEntry(AiInsight updatedInsight) {
    final outletId = updatedInsight.outletId;
    if (!_insightsCache.containsKey(outletId)) return;

    final insights = _insightsCache[outletId]!;

    if (updatedInsight.isActive) {
      // Update existing or add new
      final index = insights.indexWhere((i) => i.id == updatedInsight.id);
      if (index >= 0) {
        insights[index] = updatedInsight;
      } else {
        insights.add(updatedInsight);
      }
    } else {
      // Remove from active cache if no longer active
      insights.removeWhere((i) => i.id == updatedInsight.id);
    }
  }

  /// Add a new insight to the local cache (e.g., from a realtime event).
  void addToCache(AiInsight insight) {
    final outletId = insight.outletId;
    _insightsCache.putIfAbsent(outletId, () => []);
    _insightsCache[outletId]!.add(insight);
  }

  /// Remove an insight from the local cache.
  void removeFromCache(String outletId, String insightId) {
    _insightsCache[outletId]?.removeWhere((i) => i.id == insightId);
  }

  /// Clear the cache for a specific outlet, or all caches.
  void clearCache({String? outletId}) {
    if (outletId != null) {
      _insightsCache.remove(outletId);
    } else {
      _insightsCache.clear();
    }
  }
}
