import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/core/repositories/ai_conversation_repository.dart';
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
/// Handles sending messages, loading conversation history,
/// and managing the conversation lifecycle.
class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiService _aiService;
  final AiConversationRepository _conversationRepo;

  AiChatNotifier({
    AiService? aiService,
    AiConversationRepository? conversationRepo,
  })  : _aiService = aiService ?? AiService(),
        _conversationRepo =
            conversationRepo ?? AiConversationRepository(),
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

    // Optimistically add the user message to the UI
    final userMessage = AiMessage(
      id: const Uuid().v4(),
      conversationId: state.conversationId ?? '',
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      // Send to AI service
      final response = await _aiService.sendMessage(
        text.trim(),
        conversationId: state.conversationId,
        outletId: outletId,
        userId: userId,
      );

      // Create the assistant message from the response
      final assistantMessage = AiMessage(
        id: const Uuid().v4(),
        conversationId: response.conversationId,
        role: 'assistant',
        content: response.reply,
        functionCalls:
            response.actions.isNotEmpty ? response.actions : null,
        createdAt: DateTime.now().toUtc(),
      );

      // Update state with the conversation ID and the assistant's reply
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
        conversationId: response.conversationId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AiServiceException
            ? e.message
            : 'Failed to get response from AI. Please try again.',
      );
    }
  }

  /// Load an existing conversation and its messages.
  Future<void> loadConversation(String conversationId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final messages = await _conversationRepo.getMessages(
        conversationId,
        limit: 50,
      );

      state = state.copyWith(
        messages: messages,
        conversationId: conversationId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load conversation: $e',
      );
    }
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
