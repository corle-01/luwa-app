import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:utter_app/core/config/app_constants.dart';
import 'package:utter_app/core/models/ai_conversation.dart';
import 'package:utter_app/core/models/ai_message.dart';

/// Repository for managing AI conversations and messages in Supabase.
class AiConversationRepository {
  final SupabaseClient _client;

  AiConversationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all conversations for a specific outlet, ordered by most recent first.
  Future<List<AiConversation>> getConversations(String outletId) async {
    final response = await _client
        .from(AppConstants.tableAIConversations)
        .select()
        .eq('outlet_id', outletId)
        .order('updated_at', ascending: false);

    return (response as List)
        .map((json) => AiConversation.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Get a single conversation by ID.
  Future<AiConversation?> getConversation(String id) async {
    final response = await _client
        .from(AppConstants.tableAIConversations)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AiConversation.fromJson(Map<String, dynamic>.from(response));
  }

  /// Create a new conversation.
  ///
  /// Returns the created [AiConversation] with the server-generated fields.
  Future<AiConversation> createConversation({
    required String outletId,
    required String userId,
    String source = 'chat',
    String? title,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();

    final data = {
      'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'source': source,
      'title': title,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
    };

    final response = await _client
        .from(AppConstants.tableAIConversations)
        .insert(data)
        .select()
        .single();

    return AiConversation.fromJson(Map<String, dynamic>.from(response));
  }

  /// Update a conversation's title or active status.
  Future<AiConversation> updateConversation(
    String id, {
    String? title,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (isActive != null) updates['is_active'] = isActive;

    final response = await _client
        .from(AppConstants.tableAIConversations)
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return AiConversation.fromJson(Map<String, dynamic>.from(response));
  }

  /// Get messages for a specific conversation.
  ///
  /// Returns messages ordered by creation time ascending (oldest first)
  /// so they display in chronological order. Use [limit] to restrict the
  /// number of recent messages returned.
  Future<List<AiMessage>> getMessages(
    String conversationId, {
    int limit = 20,
  }) async {
    final response = await _client
        .from(AppConstants.tableAIMessages)
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (response as List)
        .map((json) => AiMessage.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Add a message to a conversation.
  ///
  /// Automatically updates the conversation's `updated_at` timestamp.
  Future<AiMessage> addMessage(AiMessage message) async {
    final response = await _client
        .from(AppConstants.tableAIMessages)
        .insert(message.toJson())
        .select()
        .single();

    // Update the conversation's updated_at timestamp
    await _client
        .from(AppConstants.tableAIConversations)
        .update({
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', message.conversationId);

    return AiMessage.fromJson(Map<String, dynamic>.from(response));
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String id) async {
    // Messages should be cascade-deleted by database FK, but we ensure cleanup
    await _client
        .from(AppConstants.tableAIMessages)
        .delete()
        .eq('conversation_id', id);

    await _client
        .from(AppConstants.tableAIConversations)
        .delete()
        .eq('id', id);
  }

  /// Archive a conversation (mark as inactive).
  Future<void> archiveConversation(String id) async {
    await _client
        .from(AppConstants.tableAIConversations)
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }
}
