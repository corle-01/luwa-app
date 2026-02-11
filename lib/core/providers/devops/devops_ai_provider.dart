import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:utter_app/core/models/ai_message.dart';
import 'package:utter_app/core/services/ai/gemini_service.dart';
import 'package:utter_app/core/services/ai/devops_context_builder.dart';
import 'package:utter_app/core/services/ai/devops_action_executor.dart';
import 'package:utter_app/core/services/ai/devops_tools.dart';

/// DevOps Message - Simple message for DevOps chat
class DevOpsMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  DevOpsMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// State for DevOps AI chat
class DevOpsAiState {
  final List<DevOpsMessage> messages;
  final bool isLoading;
  final String? error;

  const DevOpsAiState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  DevOpsAiState copyWith({
    List<DevOpsMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DevOpsAiState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// DevOps AI Notifier - Manages DevOps AI chat with technical context
class DevOpsAiNotifier extends StateNotifier<DevOpsAiState> {
  final DevOpsContextBuilder _contextBuilder;
  final DevOpsActionExecutor _actionExecutor;
  GeminiService? _geminiService;
  String? _systemInstruction;

  DevOpsAiNotifier({
    DevOpsContextBuilder? contextBuilder,
    DevOpsActionExecutor? actionExecutor,
  })  : _contextBuilder = contextBuilder ?? DevOpsContextBuilder(),
        _actionExecutor = actionExecutor ?? DevOpsActionExecutor(),
        super(const DevOpsAiState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Build DevOps context
      final context = await _contextBuilder.buildContext();

      // Build system instruction
      _systemInstruction = _contextBuilder.buildSystemInstruction(context);

      // Initialize GeminiService with DevOps context
      _geminiService = GeminiService(
        customSystemInstruction: _systemInstruction,
        customTools: DevOpsTools.toolDeclarations,
        outletId: 'devops', // Special ID for DevOps AI
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to initialize DevOps AI: $e',
      );
    }
  }

  /// Send message to DevOps AI
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_geminiService == null) {
      await _initialize();
      if (_geminiService == null) {
        state = state.copyWith(
          error: 'DevOps AI not initialized',
        );
        return;
      }
    }

    state = state.copyWith(clearError: true);

    // Add user message
    final userMessage = DevOpsMessage(
      role: 'user',
      content: text.trim(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      // Build history from last 10 messages
      final recentMessages = state.messages.length > 10
          ? state.messages.sublist(state.messages.length - 10)
          : state.messages;

      final history = recentMessages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Track executed tools
      final executedTools = <String>[];

      // Send to AI with DevOps tools (tools already configured in GeminiService)
      final response = await _geminiService!.sendMessage(
        message: text.trim(),
        outletId: 'devops',
        history: history.length > 1 ? history.sublist(0, history.length - 1) : null,
        executeFunction: (name, args) async {
          executedTools.add(name);
          return await _actionExecutor.execute(name, args);
        },
      );

      // Build response content
      var replyContent = response.text ?? '';

      // If AI executed tools but gave no text, provide feedback
      if (replyContent.isEmpty && executedTools.isNotEmpty) {
        replyContent = '✅ Executed diagnostic tools: ${executedTools.join(", ")}';
      }

      // Add assistant message
      final assistantMessage = DevOpsMessage(
        role: 'assistant',
        content: replyContent,
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
            : 'DevOps AI error: $e',
      );

      // Add error message to chat
      final errorMessage = DevOpsMessage(
        role: 'assistant',
        content: '❌ Error: ${e.toString()}\n\nPlease try again or rephrase your question.',
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
      );
    }
  }

  /// Clear chat history
  void clearChat() {
    state = const DevOpsAiState();
  }

  /// Refresh DevOps context (e.g., after migration or schema change)
  Future<void> refreshContext() async {
    state = state.copyWith(isLoading: true);

    try {
      final context = await _contextBuilder.buildContext();
      _systemInstruction = _contextBuilder.buildSystemInstruction(context);

      // Reinitialize Gemini with new context
      _geminiService?.dispose();
      _geminiService = GeminiService(
        customSystemInstruction: _systemInstruction,
        customTools: DevOpsTools.toolDeclarations,
        outletId: 'devops',
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to refresh context: $e',
      );
    }
  }

  @override
  void dispose() {
    _geminiService?.dispose();
    super.dispose();
  }
}

/// Provider for DevOps AI chat
final devopsAiProvider =
    StateNotifierProvider<DevOpsAiNotifier, DevOpsAiState>((ref) {
  return DevOpsAiNotifier();
});

/// Provider that exposes just the messages
final devopsAiMessagesProvider = Provider<List<DevOpsMessage>>((ref) {
  return ref.watch(devopsAiProvider).messages;
});

/// Provider that exposes loading state
final devopsAiLoadingProvider = Provider<bool>((ref) {
  return ref.watch(devopsAiProvider).isLoading;
});
