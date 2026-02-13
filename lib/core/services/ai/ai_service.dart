import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:luwa_app/core/services/ai/ai_context_builder.dart';

/// Response returned by the AI service after processing a message.
class AiResponse {
  /// The text reply from the AI.
  final String reply;

  /// List of actions the AI took or is suggesting.
  final List<Map<String, dynamic>> actions;

  /// The conversation ID (client-side only, for tracking).
  final String conversationId;

  const AiResponse({
    required this.reply,
    this.actions = const [],
    required this.conversationId,
  });
}

/// Main AI service that handles communication with DeepSeek via Supabase RPC.
///
/// Calls the `ai_chat` Postgres function which proxies requests to DeepSeek API
/// server-side, avoiding CORS issues and keeping the API key secure.
class AiService {
  final SupabaseClient _client;
  final AiContextBuilder _contextBuilder;

  AiService({
    SupabaseClient? client,
    AiContextBuilder? contextBuilder,
    String outletId = 'a0000000-0000-0000-0000-000000000001',
  })  : _client = client ?? Supabase.instance.client,
        _contextBuilder = contextBuilder ?? AiContextBuilder(outletId: outletId);

  /// Send a message to the AI via Supabase RPC and receive a response.
  ///
  /// Builds business context automatically and includes conversation history.
  /// The AI call happens server-side in Postgres via the `ai_chat` function.
  Future<AiResponse> sendMessage(
    String message, {
    String? conversationId,
    required String outletId,
    required String userId,
    Map<String, dynamic>? context,
    List<Map<String, String>>? history,
  }) async {
    // Build context if not provided
    final messageContext =
        context ?? await _contextBuilder.buildContext(outletId);

    // Build history for the RPC call
    final historyJson = history
            ?.map((m) => {'role': m['role'] ?? '', 'content': m['content'] ?? ''})
            .toList() ??
        [];

    try {
      // Call the ai_chat RPC function with 35s timeout
      // (slightly longer than the 30s server-side HTTP timeout)
      final response = await _client
          .rpc('ai_chat', params: {
            'p_message': message,
            'p_history': historyJson,
            'p_context': messageContext,
          })
          .timeout(const Duration(seconds: 120));

      final data = Map<String, dynamic>.from(response as Map);

      if (data['error'] == true) {
        throw AiServiceException(
          data['reply'] as String? ?? 'AI service error',
        );
      }

      return AiResponse(
        reply: data['reply'] as String? ?? 'Tidak ada respons.',
        actions: data['actions'] != null
            ? List<Map<String, dynamic>>.from(
                (data['actions'] as List).map(
                  (item) => Map<String, dynamic>.from(item as Map),
                ),
              )
            : const [],
        conversationId: conversationId ?? '',
      );
    } on TimeoutException {
      throw AiServiceException(
        'Permintaan AI memakan waktu terlalu lama. Coba pertanyaan yang lebih singkat.',
      );
    } catch (e) {
      if (e is AiServiceException) rethrow;
      throw AiServiceException(
        'Gagal menghubungi AI: $e',
      );
    }
  }

  /// Dispose of resources.
  void dispose() {
    // No resources to dispose with RPC approach
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
