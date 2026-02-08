import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:utter_app/core/config/app_constants.dart';
import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/core/repositories/ai_conversation_repository.dart';
import 'package:utter_app/core/services/ai/ai_context_builder.dart';

/// Response returned by the AI service after processing a message.
class AiResponse {
  /// The text reply from the AI.
  final String reply;

  /// List of actions the AI took or is suggesting.
  final List<Map<String, dynamic>> actions;

  /// The conversation ID (existing or newly created).
  final String conversationId;

  const AiResponse({
    required this.reply,
    this.actions = const [],
    required this.conversationId,
  });

  factory AiResponse.fromJson(Map<String, dynamic> json) {
    return AiResponse(
      reply: json['reply'] as String? ?? '',
      actions: json['actions'] != null
          ? List<Map<String, dynamic>>.from(
              (json['actions'] as List).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const [],
      conversationId: json['conversation_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reply': reply,
      'actions': actions,
      'conversation_id': conversationId,
    };
  }
}

/// Main AI service that handles communication with the AI backend.
///
/// Sends user messages to the Supabase Edge Function `/ai-agent`,
/// manages conversation state, and processes AI responses including
/// any actions the AI needs to take.
class AiService {
  static const String _edgeFunctionUrl =
      'https://eavsygnrluburvrobvoj.supabase.co/functions/v1/ai-agent';

  final SupabaseClient _client;
  final AiConversationRepository _conversationRepo;
  final AiContextBuilder _contextBuilder;
  final http.Client _httpClient;

  AiService({
    SupabaseClient? client,
    AiConversationRepository? conversationRepo,
    AiContextBuilder? contextBuilder,
    http.Client? httpClient,
  })  : _client = client ?? Supabase.instance.client,
        _conversationRepo =
            conversationRepo ?? AiConversationRepository(),
        _contextBuilder = contextBuilder ?? AiContextBuilder(),
        _httpClient = httpClient ?? http.Client();

  /// Send a message to the AI agent and receive a response.
  ///
  /// If [conversationId] is null, a new conversation will be created.
  /// The [context] parameter allows passing additional contextual data;
  /// if null, the context will be auto-built from the outlet's current state.
  ///
  /// Returns an [AiResponse] containing the AI's reply, any actions taken,
  /// and the conversation ID.
  Future<AiResponse> sendMessage(
    String message, {
    String? conversationId,
    required String outletId,
    required String userId,
    Map<String, dynamic>? context,
  }) async {
    // Create a new conversation if needed
    String activeConversationId = conversationId ?? '';
    if (activeConversationId.isEmpty) {
      final conversation = await _conversationRepo.createConversation(
        outletId: outletId,
        userId: userId,
        source: 'chat',
      );
      activeConversationId = conversation.id;
    }

    // Save the user message to the database
    final userMessage = AiMessage(
      id: const Uuid().v4(),
      conversationId: activeConversationId,
      role: 'user',
      content: message,
      createdAt: DateTime.now().toUtc(),
    );
    await _conversationRepo.addMessage(userMessage);

    // Build context if not provided
    final messageContext =
        context ?? await _contextBuilder.buildContext(outletId);

    // Get the auth token for the current user
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';

    // Get recent message history for the conversation
    final recentMessages =
        await _conversationRepo.getMessages(activeConversationId, limit: 10);
    final messageHistory = recentMessages
        .map((m) => {
              'role': m.role,
              'content': m.content,
            })
        .toList();

    // Build the request payload
    final requestBody = {
      'message': message,
      'conversation_id': activeConversationId,
      'outlet_id': outletId,
      'user_id': userId,
      'context': messageContext,
      'history': messageHistory,
    };

    try {
      // Call the Supabase Edge Function
      final response = await _httpClient
          .post(
            Uri.parse(_edgeFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'apikey': 'sb_publishable_NQB_fdJdLgGK0R3OI2Cyjg_UlG76qUs',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(AppConstants.aiTimeout);

      if (response.statusCode != 200) {
        throw AiServiceException(
          'AI service returned status ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final responseData =
          jsonDecode(response.body) as Map<String, dynamic>;

      // Parse the AI response
      final aiResponse = AiResponse(
        reply: responseData['reply'] as String? ?? '',
        actions: responseData['actions'] != null
            ? List<Map<String, dynamic>>.from(
                (responseData['actions'] as List).map(
                  (item) => Map<String, dynamic>.from(item as Map),
                ),
              )
            : const [],
        conversationId: activeConversationId,
      );

      // Save the assistant message to the database
      final assistantMessage = AiMessage(
        id: const Uuid().v4(),
        conversationId: activeConversationId,
        role: 'assistant',
        content: aiResponse.reply,
        functionCalls: aiResponse.actions.isNotEmpty
            ? aiResponse.actions
            : null,
        tokensUsed: responseData['tokens_used'] as int?,
        model: responseData['model'] as String?,
        createdAt: DateTime.now().toUtc(),
      );
      await _conversationRepo.addMessage(assistantMessage);

      // Update conversation title from first message if not set
      if (conversationId == null || conversationId.isEmpty) {
        final title = message.length > 50
            ? '${message.substring(0, 50)}...'
            : message;
        await _conversationRepo.updateConversation(
          activeConversationId,
          title: title,
        );
      }

      return aiResponse;
    } on AiServiceException {
      rethrow;
    } catch (e) {
      throw AiServiceException(
        'Failed to communicate with AI service: $e',
      );
    }
  }

  /// Dispose of resources.
  void dispose() {
    _httpClient.close();
  }
}

/// Exception thrown when the AI service encounters an error.
class AiServiceException implements Exception {
  final String message;
  final int? statusCode;

  const AiServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'AiServiceException: $message';
}
