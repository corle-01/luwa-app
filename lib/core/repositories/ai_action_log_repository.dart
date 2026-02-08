import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:utter_app/core/config/app_constants.dart';
import 'package:utter_app/core/models/ai_action_log.dart';

/// Repository for managing AI action logs in Supabase.
///
/// Action logs record every action the AI takes, including informed,
/// suggested, auto-executed, and silent actions. Supports undo
/// functionality for actions within their undo window.
class AiActionLogRepository {
  final SupabaseClient _client;

  AiActionLogRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get action logs for a specific outlet.
  ///
  /// Supports pagination via [limit] and [offset], and optional filtering
  /// by [featureKey]. Returns logs ordered by most recent first.
  Future<List<AiActionLog>> getActionLogs(
    String outletId, {
    int limit = 20,
    int offset = 0,
    String? featureKey,
  }) async {
    var query = _client
        .from(AppConstants.tableAIActionLogs)
        .select()
        .eq('outlet_id', outletId);

    if (featureKey != null) {
      query = query.eq('feature_key', featureKey);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => AiActionLog.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Get a single action log by ID.
  Future<AiActionLog?> getActionLog(String id) async {
    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AiActionLog.fromJson(Map<String, dynamic>.from(response));
  }

  /// Mark an action as undone.
  ///
  /// This will set the `is_undone` flag to true. The actual undo logic
  /// (reversing the action) should be handled by the AI service or
  /// calling code. Returns the updated [AiActionLog].
  ///
  /// Throws an exception if the action's undo deadline has passed.
  Future<AiActionLog> undoAction(String id) async {
    // First check if the action can be undone
    final existing = await getActionLog(id);
    if (existing == null) {
      throw Exception('Action log not found: $id');
    }
    if (!existing.canUndo) {
      throw Exception(
        'Action cannot be undone. The undo window has expired or '
        'the action has already been undone.',
      );
    }

    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .update({
          'is_undone': true,
          'action_type': AppConstants.actionUndone,
        })
        .eq('id', id)
        .select()
        .single();

    return AiActionLog.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get actions that are pending approval (suggested but not yet
  /// approved or rejected).
  Future<List<AiActionLog>> getPendingApprovals(String outletId) async {
    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .select()
        .eq('outlet_id', outletId)
        .eq('action_type', AppConstants.actionSuggested)
        .eq('is_undone', false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AiActionLog.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Create a new action log entry.
  Future<AiActionLog> createActionLog(AiActionLog log) async {
    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .insert(log.toJson())
        .select()
        .single();

    return AiActionLog.fromJson(Map<String, dynamic>.from(response));
  }

  /// Approve a suggested action.
  ///
  /// Changes the action type from 'suggested' to 'approved' and records
  /// who approved it.
  Future<AiActionLog> approveAction(String id, String approvedBy) async {
    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .update({
          'action_type': AppConstants.actionApproved,
          'approved_by': approvedBy,
        })
        .eq('id', id)
        .select()
        .single();

    return AiActionLog.fromJson(Map<String, dynamic>.from(response));
  }

  /// Reject a suggested action.
  Future<AiActionLog> rejectAction(String id, String approvedBy) async {
    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .update({
          'action_type': AppConstants.actionRejected,
          'approved_by': approvedBy,
        })
        .eq('id', id)
        .select()
        .single();

    return AiActionLog.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get count of actions that can still be undone.
  Future<int> getUndoableCount(String outletId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _client
        .from(AppConstants.tableAIActionLogs)
        .select('id')
        .eq('outlet_id', outletId)
        .eq('is_undone', false)
        .gt('undo_deadline', now);

    return (response as List).length;
  }
}
