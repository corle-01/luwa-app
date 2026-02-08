import 'package:flutter/material.dart';

/// AI Insight model
///
/// Represents an AI-generated insight or recommendation for an outlet.
/// Insights have types (forecast, prediction, anomaly, etc.), severity
/// levels, and lifecycle states.
class AiInsight {
  final String id;
  final String outletId;
  final String insightType;
  final String title;
  final String description;
  final String severity;
  final Map<String, dynamic>? data;
  final String? suggestedAction;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const AiInsight({
    required this.id,
    required this.outletId,
    required this.insightType,
    required this.title,
    required this.description,
    this.severity = 'info',
    this.data,
    this.suggestedAction,
    this.status = 'active',
    this.expiresAt,
    required this.createdAt,
  });

  /// Valid insight types.
  static const List<String> validInsightTypes = [
    'demand_forecast',
    'stock_prediction',
    'anomaly',
    'sales_trend',
    'cost_alert',
    'menu_optimization',
    'staffing',
    'customer_pattern',
  ];

  /// Valid severity levels.
  static const List<String> validSeverities = [
    'info',
    'warning',
    'critical',
    'positive',
  ];

  /// Valid status values.
  static const List<String> validStatuses = [
    'active',
    'dismissed',
    'acted_on',
    'expired',
  ];

  /// Whether this insight is still active.
  bool get isActive => status == 'active';

  /// Whether this insight has expired.
  bool get isExpired {
    if (status == 'expired') return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    return false;
  }

  /// Returns a color associated with the insight severity.
  Color get severityColor {
    switch (severity) {
      case 'info':
        return const Color(0xFF2196F3); // Blue
      case 'warning':
        return const Color(0xFFFF9800); // Orange
      case 'critical':
        return const Color(0xFFF44336); // Red
      case 'positive':
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  /// Returns an icon associated with the insight severity.
  IconData get icon {
    switch (severity) {
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'critical':
        return Icons.error_outline;
      case 'positive':
        return Icons.check_circle_outline;
      default:
        return Icons.lightbulb_outline;
    }
  }

  /// Returns an icon associated with the insight type.
  IconData get typeIcon {
    switch (insightType) {
      case 'demand_forecast':
        return Icons.trending_up;
      case 'stock_prediction':
        return Icons.inventory_2_outlined;
      case 'anomaly':
        return Icons.report_problem_outlined;
      case 'sales_trend':
        return Icons.show_chart;
      case 'cost_alert':
        return Icons.attach_money;
      case 'menu_optimization':
        return Icons.restaurant_menu;
      case 'staffing':
        return Icons.people_outline;
      case 'customer_pattern':
        return Icons.groups_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      insightType: json['insight_type'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      suggestedAction: json['suggested_action'] as String?,
      status: json['status'] as String? ?? 'active',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'insight_type': insightType,
      'title': title,
      'description': description,
      'severity': severity,
      'data': data,
      'suggested_action': suggestedAction,
      'status': status,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AiInsight copyWith({
    String? id,
    String? outletId,
    String? insightType,
    String? title,
    String? description,
    String? severity,
    Map<String, dynamic>? data,
    String? suggestedAction,
    String? status,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return AiInsight(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      insightType: insightType ?? this.insightType,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      data: data ?? this.data,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AiInsight(id: $id, type: $insightType, severity: $severity, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiInsight &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
