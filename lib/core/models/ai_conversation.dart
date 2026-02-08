/// AI Conversation model
///
/// Represents a single conversation thread between the user and AI.
/// Conversations can originate from different sources (chat UI, floating
/// button, voice input).
class AiConversation {
  final String id;
  final String outletId;
  final String userId;
  final String? title;
  final String source;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversation({
    required this.id,
    required this.outletId,
    required this.userId,
    this.title,
    this.source = 'chat',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Valid conversation sources.
  static const List<String> validSources = ['chat', 'floating', 'voice'];

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      source: json['source'] as String? ?? 'chat',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'title': title,
      'source': source,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AiConversation copyWith({
    String? id,
    String? outletId,
    String? userId,
    String? title,
    String? source,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiConversation(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      source: source ?? this.source,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AiConversation(id: $id, title: $title, source: $source)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiConversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
