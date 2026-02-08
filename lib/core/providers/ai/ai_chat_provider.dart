import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/core/services/ai/gemini_service.dart';
import 'package:utter_app/core/services/ai/ai_action_executor.dart';

/// State for the AI chat interface.
class AiChatState {
  final List<AiMessage> messages;
  final bool isLoading;
  final String? conversationId;
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

/// Notifier that manages AI chat with Gemini + function calling.
class AiChatNotifier extends StateNotifier<AiChatState> {
  final GeminiService _geminiService;
  final AiActionExecutor _actionExecutor;

  static const _outletId = 'a0000000-0000-0000-0000-000000000001';

  AiChatNotifier({
    GeminiService? geminiService,
    AiActionExecutor? actionExecutor,
  })  : _geminiService = geminiService ?? GeminiService(),
        _actionExecutor = actionExecutor ?? AiActionExecutor(),
        super(const AiChatState());

  /// Send a text message. Gemini may execute function calls automatically.
  Future<void> sendMessage(
    String text, {
    required String outletId,
    required String userId,
  }) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(clearError: true);

    final effectiveOutletId = outletId.isNotEmpty ? outletId : _outletId;
    final convId = state.conversationId ?? const Uuid().v4();

    // Add user message to UI
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
      // Build history from last 10 messages
      final recentMessages = state.messages.length > 10
          ? state.messages.sublist(state.messages.length - 10)
          : state.messages;

      final history = recentMessages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Track executed actions for display
      final executedActions = <Map<String, dynamic>>[];

      // Send to Gemini with function execution callback
      final response = await _geminiService.sendMessage(
        message: text.trim(),
        outletId: effectiveOutletId,
        history: history.length > 1 ? history.sublist(0, history.length - 1) : null,
        executeFunction: (name, args) async {
          final result = await _actionExecutor.execute(name, args);
          executedActions.add({
            'name': name,
            'arguments': args,
            'result': result,
          });
          return result;
        },
      );

      // Build response content with action summaries
      var replyContent = response.text ?? '';

      // If there were actions but no text, summarize actions
      if (replyContent.isEmpty && executedActions.isNotEmpty) {
        replyContent = executedActions.map((a) {
          final result = a['result'] as Map<String, dynamic>;
          return result['message'] ?? 'Aksi ${a['name']} selesai';
        }).join('\n');
      }

      final assistantMessage = AiMessage(
        id: const Uuid().v4(),
        conversationId: convId,
        role: 'assistant',
        content: replyContent,
        functionCalls: executedActions.isNotEmpty ? executedActions : null,
        tokensUsed: response.tokensUsed,
        model: 'gemini-2.0-flash',
        createdAt: DateTime.now().toUtc(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is GeminiException
            ? e.message
            : 'Gagal mendapat respons dari AI: $e',
      );
    }
  }

  void loadConversation(String conversationId) {
    state = state.copyWith(conversationId: conversationId);
  }

  void newConversation() {
    state = const AiChatState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void removeLastMessage() {
    if (state.messages.isEmpty) return;
    state = state.copyWith(
      messages: List.from(state.messages)..removeLast(),
    );
  }

  @override
  void dispose() {
    _geminiService.dispose();
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
