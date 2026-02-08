import 'package:utter_app/core/models/ai_function_call.dart';

/// AI Message model
///
/// Represents a single message within a conversation. Messages can be
/// from the user, assistant, system, or function calls.
class AiMessage {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final List<Map<String, dynamic>>? functionCalls;
  final int? tokensUsed;
  final String? model;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.functionCalls,
    this.tokensUsed,
    this.model,
    required this.createdAt,
  });

  /// Valid message roles.
  static const List<String> validRoles = [
    'user',
    'assistant',
    'system',
    'function',
  ];

  /// Whether this message was sent by the user.
  bool get isUser => role == 'user';

  /// Whether this message was sent by the assistant.
  bool get isAssistant => role == 'assistant';

  /// Whether this message is a system message.
  bool get isSystem => role == 'system';

  /// Whether this message is a function call result.
  bool get isFunction => role == 'function';

  /// Whether this message includes function calls.
  bool get hasFunctionCalls =>
      functionCalls != null && functionCalls!.isNotEmpty;

  /// Parse function calls into typed objects.
  List<AiFunctionCall> get parsedFunctionCalls {
    if (functionCalls == null) return [];
    return functionCalls!
        .map((fc) => AiFunctionCall.fromJson(fc))
        .toList();
  }

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      functionCalls: json['function_calls'] != null
          ? List<Map<String, dynamic>>.from(
              (json['function_calls'] as List).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : null,
      tokensUsed: json['tokens_used'] as int?,
      model: json['model'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'function_calls': functionCalls,
      'tokens_used': tokensUsed,
      'model': model,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AiMessage copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    List<Map<String, dynamic>>? functionCalls,
    int? tokensUsed,
    String? model,
    DateTime? createdAt,
  }) {
    return AiMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      functionCalls: functionCalls ?? this.functionCalls,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AiMessage(id: $id, role: $role, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
