import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/core/services/ai/ai_service.dart';

/// State for the AI chat interface.
class AiChatState {
  /// The list of messages in the current conversation.
  final List<AiMessage> messages;

  /// Whether a message is currently being sent/processed.
  final bool isLoading;

  /// The current conversation ID, if any.
  final String? conversationId;

  /// Error message from the last failed operation, if any.
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.conversationId,
    this.error,
  });

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? isLoading,
    String? conversationId,
    String? error,
    bool clearError = false,
    bool clearConversationId = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      conversationId: clearConversationId
          ? null
          : (conversationId ?? this.conversationId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier that manages the AI chat state.
///
/// Keeps conversation history in memory and sends it with each request
/// to the ai_chat RPC function for context continuity.
class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiService _aiService;

  static const _outletId = 'a0000000-0000-0000-0000-000000000001';

  AiChatNotifier({
    AiService? aiService,
  })  : _aiService = aiService ?? AiService(),
        super(const AiChatState());

  /// Send a text message from the user.
  ///
  /// Creates an optimistic user message in the UI immediately,
  /// then sends it to the AI service for a response.
  Future<void> sendMessage(
    String text, {
    required String outletId,
    required String userId,
  }) async {
    if (text.trim().isEmpty) return;

    // Clear previous errors
    state = state.copyWith(clearError: true);

    final effectiveOutletId = outletId.isNotEmpty ? outletId : _outletId;
    final convId = state.conversationId ?? const Uuid().v4();

    // Optimistically add the user message to the UI
    final userMessage = AiMessage(
      id: const Uuid().v4(),
      conversationId: convId,
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      conversationId: convId,
    );

    try {
      // Build history from existing messages (last 10 messages for context)
      final recentMessages = state.messages.length > 10
          ? state.messages.sublist(state.messages.length - 10)
          : state.messages;

      final history = recentMessages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Send to AI service via RPC
      final response = await _aiService.sendMessage(
        text.trim(),
        conversationId: convId,
        outletId: effectiveOutletId,
        userId: userId,
        history: history,
      );

      // Create the assistant message from the response
      final assistantMessage = AiMessage(
        id: const Uuid().v4(),
        conversationId: convId,
        role: 'assistant',
        content: response.reply,
        functionCalls:
            response.actions.isNotEmpty ? response.actions : null,
        createdAt: DateTime.now().toUtc(),
      );

      // Update state with the assistant's reply
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AiServiceException
            ? e.message
            : 'Gagal mendapat respons dari AI. Silakan coba lagi.',
      );
    }
  }

  /// Load a conversation by ID (no-op for now, conversations are in-memory only).
  Future<void> loadConversation(String conversationId) async {
    // Conversations are kept in memory only for now.
    // This method exists for compatibility with the conversation history page.
    state = state.copyWith(conversationId: conversationId);
  }

  /// Start a new conversation, clearing the current messages.
  void newConversation() {
    state = const AiChatState();
  }

  /// Clear the current error state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Remove the last message (e.g., if retry is requested).
  void removeLastMessage() {
    if (state.messages.isEmpty) return;
    state = state.copyWith(
      messages: List.from(state.messages)..removeLast(),
    );
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}

/// Provider for the AI chat state.
final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier();
});

/// Provider that exposes just the messages list.
final aiChatMessagesProvider = Provider<List<AiMessage>>((ref) {
  return ref.watch(aiChatProvider).messages;
});

/// Provider that exposes the loading state.
final aiChatLoadingProvider = Provider<bool>((ref) {
  return ref.watch(aiChatProvider).isLoading;
});

/// Provider that exposes the error state.
final aiChatErrorProvider = Provider<String?>((ref) {
  return ref.watch(aiChatProvider).error;
});
