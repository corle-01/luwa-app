/// AI Action Log model
///
/// Records every action taken by the AI, whether it was informed, suggested,
/// auto-executed, or silent. Supports undo functionality with a time-limited
/// undo window.
class AiActionLog {
  final String id;
  final String outletId;
  final String featureKey;
  final int trustLevel;
  final String actionType;
  final String actionDescription;
  final Map<String, dynamic>? actionData;
  final String? source;
  final String? conversationId;
  final String? triggeredBy;
  final String? approvedBy;
  final bool isUndone;
  final DateTime? undoDeadline;
  final DateTime createdAt;

  const AiActionLog({
    required this.id,
    required this.outletId,
    required this.featureKey,
    required this.trustLevel,
    required this.actionType,
    required this.actionDescription,
    this.actionData,
    this.source,
    this.conversationId,
    this.triggeredBy,
    this.approvedBy,
    this.isUndone = false,
    this.undoDeadline,
    required this.createdAt,
  });

  /// Valid action types.
  static const List<String> validActionTypes = [
    'informed',
    'suggested',
    'auto_executed',
    'silent_executed',
    'approved',
    'rejected',
    'edited',
    'undone',
  ];

  /// Whether this action can still be undone.
  /// An action can be undone if:
  /// - It has not already been undone
  /// - It has an undo deadline that is still in the future
  bool get canUndo {
    if (isUndone) return false;
    if (undoDeadline == null) return false;
    return DateTime.now().isBefore(undoDeadline!);
  }

  /// Remaining time before the undo window closes.
  Duration? get undoTimeRemaining {
    if (!canUndo || undoDeadline == null) return null;
    return undoDeadline!.difference(DateTime.now());
  }

  factory AiActionLog.fromJson(Map<String, dynamic> json) {
    return AiActionLog(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      featureKey: json['feature_key'] as String,
      trustLevel: json['trust_level'] as int? ?? 0,
      actionType: json['action_type'] as String,
      actionDescription: json['action_description'] as String? ?? '',
      actionData: json['action_data'] != null
          ? Map<String, dynamic>.from(json['action_data'] as Map)
          : null,
      source: json['source'] as String?,
      conversationId: json['conversation_id'] as String?,
      triggeredBy: json['triggered_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      isUndone: json['is_undone'] as bool? ?? false,
      undoDeadline: json['undo_deadline'] != null
          ? DateTime.parse(json['undo_deadline'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'feature_key': featureKey,
      'trust_level': trustLevel,
      'action_type': actionType,
      'action_description': actionDescription,
      'action_data': actionData,
      'source': source,
      'conversation_id': conversationId,
      'triggered_by': triggeredBy,
      'approved_by': approvedBy,
      'is_undone': isUndone,
      'undo_deadline': undoDeadline?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AiActionLog copyWith({
    String? id,
    String? outletId,
    String? featureKey,
    int? trustLevel,
    String? actionType,
    String? actionDescription,
    Map<String, dynamic>? actionData,
    String? source,
    String? conversationId,
    String? triggeredBy,
    String? approvedBy,
    bool? isUndone,
    DateTime? undoDeadline,
    DateTime? createdAt,
  }) {
    return AiActionLog(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      featureKey: featureKey ?? this.featureKey,
      trustLevel: trustLevel ?? this.trustLevel,
      actionType: actionType ?? this.actionType,
      actionDescription: actionDescription ?? this.actionDescription,
      actionData: actionData ?? this.actionData,
      source: source ?? this.source,
      conversationId: conversationId ?? this.conversationId,
      triggeredBy: triggeredBy ?? this.triggeredBy,
      approvedBy: approvedBy ?? this.approvedBy,
      isUndone: isUndone ?? this.isUndone,
      undoDeadline: undoDeadline ?? this.undoDeadline,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AiActionLog(id: $id, featureKey: $featureKey, actionType: $actionType, canUndo: $canUndo)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiActionLog &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
