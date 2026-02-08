/// AI Trust Setting model
///
/// Represents the trust level configuration for a specific AI feature
/// within an outlet. Trust levels control how autonomously AI can act.
///
/// Trust Levels:
/// - 0: Inform Only - AI only reports, no action taken
/// - 1: Suggest + Confirm - AI suggests actions, user confirms
/// - 2: Auto + Notify - AI acts automatically but notifies user
/// - 3: Full Auto - AI acts silently without notification
class AiTrustSetting {
  final String id;
  final String outletId;
  final String featureKey;
  final int trustLevel;
  final bool isEnabled;
  final Map<String, dynamic> config;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiTrustSetting({
    required this.id,
    required this.outletId,
    required this.featureKey,
    this.trustLevel = 0,
    this.isEnabled = true,
    this.config = const {},
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Human-readable label for the current trust level.
  String get trustLevelLabel {
    switch (trustLevel) {
      case 0:
        return 'Inform Only';
      case 1:
        return 'Suggest + Confirm';
      case 2:
        return 'Auto + Notify';
      case 3:
        return 'Full Auto';
      default:
        return 'Unknown';
    }
  }

  factory AiTrustSetting.fromJson(Map<String, dynamic> json) {
    return AiTrustSetting(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      featureKey: json['feature_key'] as String,
      trustLevel: json['trust_level'] as int? ?? 0,
      isEnabled: json['is_enabled'] as bool? ?? true,
      config: json['config'] != null
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'feature_key': featureKey,
      'trust_level': trustLevel,
      'is_enabled': isEnabled,
      'config': config,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AiTrustSetting copyWith({
    String? id,
    String? outletId,
    String? featureKey,
    int? trustLevel,
    bool? isEnabled,
    Map<String, dynamic>? config,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiTrustSetting(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      featureKey: featureKey ?? this.featureKey,
      trustLevel: trustLevel ?? this.trustLevel,
      isEnabled: isEnabled ?? this.isEnabled,
      config: config ?? this.config,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AiTrustSetting(featureKey: $featureKey, trustLevel: $trustLevel, isEnabled: $isEnabled)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiTrustSetting &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
