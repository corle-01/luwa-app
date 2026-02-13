import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:luwa_app/core/config/app_constants.dart';
import 'package:luwa_app/core/models/ai_insight.dart';

/// Repository for managing AI insights in Supabase.
///
/// Insights are AI-generated observations, predictions, and recommendations
/// about the outlet's business data.
class AiInsightRepository {
  final SupabaseClient _client;

  AiInsightRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all active insights for a specific outlet.
  ///
  /// Returns insights ordered by severity (critical first) and then by
  /// creation time (most recent first).
  Future<List<AiInsight>> getActiveInsights(String outletId) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .select()
        .eq('outlet_id', outletId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    final insights = (response as List)
        .map((json) => AiInsight.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    // Sort by severity priority: critical > warning > info > positive
    insights.sort((a, b) {
      const severityOrder = {
        'critical': 0,
        'warning': 1,
        'info': 2,
        'positive': 3,
      };
      final aOrder = severityOrder[a.severity] ?? 4;
      final bOrder = severityOrder[b.severity] ?? 4;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return b.createdAt.compareTo(a.createdAt);
    });

    return insights;
  }

  /// Get a single insight by ID.
  Future<AiInsight?> getInsight(String id) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AiInsight.fromJson(Map<String, dynamic>.from(response));
  }

  /// Dismiss an insight (mark as dismissed by the user).
  Future<AiInsight> dismissInsight(String id) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .update({'status': 'dismissed'})
        .eq('id', id)
        .select()
        .single();

    return AiInsight.fromJson(Map<String, dynamic>.from(response));
  }

  /// Mark an insight as acted upon.
  Future<AiInsight> actOnInsight(String id) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .update({'status': 'acted_on'})
        .eq('id', id)
        .select()
        .single();

    return AiInsight.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get the count of active insights for an outlet.
  Future<int> getInsightCount(String outletId) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .select('id')
        .eq('outlet_id', outletId)
        .eq('status', 'active');

    return (response as List).length;
  }

  /// Get insights filtered by type.
  Future<List<AiInsight>> getInsightsByType(
    String outletId,
    String insightType,
  ) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .select()
        .eq('outlet_id', outletId)
        .eq('insight_type', insightType)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AiInsight.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Get insights filtered by severity.
  Future<List<AiInsight>> getInsightsBySeverity(
    String outletId,
    String severity,
  ) async {
    final response = await _client
        .from(AppConstants.tableAIInsights)
        .select()
        .eq('outlet_id', outletId)
        .eq('severity', severity)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AiInsight.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Expire all insights that have passed their expiration date.
  ///
  /// This can be called periodically to clean up stale insights.
  Future<void> expireOldInsights(String outletId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(AppConstants.tableAIInsights)
        .update({'status': 'expired'})
        .eq('outlet_id', outletId)
        .eq('status', 'active')
        .lt('expires_at', now);
  }

  /// Subscribe to real-time changes on the insights table for an outlet.
  ///
  /// Returns a [RealtimeChannel] that can be used to listen for INSERT,
  /// UPDATE, and DELETE events.
  RealtimeChannel subscribeToInsights(
    String outletId, {
    required void Function(AiInsight insight) onInsert,
    required void Function(AiInsight insight) onUpdate,
    required void Function(Map<String, dynamic> oldRecord) onDelete,
  }) {
    return _client
        .channel('ai_insights_$outletId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tableAIInsights,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onInsert(AiInsight.fromJson(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConstants.tableAIInsights,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdate(AiInsight.fromJson(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: AppConstants.tableAIInsights,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'outlet_id',
            value: outletId,
          ),
          callback: (payload) {
            onDelete(payload.oldRecord);
          },
        )
        .subscribe();
  }

  /// Unsubscribe from real-time updates.
  Future<void> unsubscribeFromInsights(String outletId) async {
    await _client.removeChannel(
      _client.channel('ai_insights_$outletId'),
    );
  }
}
