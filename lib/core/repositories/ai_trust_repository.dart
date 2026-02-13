import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:luwa_app/core/config/app_constants.dart';
import 'package:luwa_app/core/models/ai_trust_setting.dart';

/// Repository for managing AI trust settings in Supabase.
///
/// Trust settings control how autonomously AI can act for each feature
/// within a specific outlet.
class AiTrustRepository {
  final SupabaseClient _client;

  AiTrustRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all trust settings for a specific outlet.
  Future<List<AiTrustSetting>> getTrustSettings(String outletId) async {
    final response = await _client
        .from(AppConstants.tableAITrustSettings)
        .select()
        .eq('outlet_id', outletId)
        .order('feature_key', ascending: true);

    return (response as List)
        .map((json) =>
            AiTrustSetting.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Get the trust level for a specific feature in an outlet.
  ///
  /// Returns the [AiTrustSetting] if found, or `null` if no setting exists
  /// for the given feature key.
  Future<AiTrustSetting?> getTrustLevel(
    String outletId,
    String featureKey,
  ) async {
    final response = await _client
        .from(AppConstants.tableAITrustSettings)
        .select()
        .eq('outlet_id', outletId)
        .eq('feature_key', featureKey)
        .maybeSingle();

    if (response == null) return null;
    return AiTrustSetting.fromJson(Map<String, dynamic>.from(response));
  }

  /// Update the trust level for a specific setting.
  ///
  /// [id] is the trust setting record ID.
  /// [level] must be between 0 and 3 inclusive.
  /// [updatedBy] is the user ID who made the change.
  Future<AiTrustSetting> updateTrustLevel(
    String id,
    int level,
    String updatedBy,
  ) async {
    assert(level >= 0 && level <= 3, 'Trust level must be between 0 and 3');

    final response = await _client
        .from(AppConstants.tableAITrustSettings)
        .update({
          'trust_level': level,
          'updated_by': updatedBy,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return AiTrustSetting.fromJson(Map<String, dynamic>.from(response));
  }

  /// Enable or disable a specific trust setting.
  Future<AiTrustSetting> toggleEnabled(
    String id,
    bool isEnabled,
    String updatedBy,
  ) async {
    final response = await _client
        .from(AppConstants.tableAITrustSettings)
        .update({
          'is_enabled': isEnabled,
          'updated_by': updatedBy,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return AiTrustSetting.fromJson(Map<String, dynamic>.from(response));
  }

  /// Update the configuration for a trust setting.
  Future<AiTrustSetting> updateConfig(
    String id,
    Map<String, dynamic> config,
    String updatedBy,
  ) async {
    final response = await _client
        .from(AppConstants.tableAITrustSettings)
        .update({
          'config': config,
          'updated_by': updatedBy,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return AiTrustSetting.fromJson(Map<String, dynamic>.from(response));
  }

  /// Create a new trust setting for an outlet and feature.
  ///
  /// This is typically called when initializing default trust settings
  /// for a newly created outlet.
  Future<AiTrustSetting> createTrustSetting({
    required String outletId,
    required String featureKey,
    int trustLevel = 0,
    bool isEnabled = true,
    Map<String, dynamic> config = const {},
    String? updatedBy,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final data = {
      'outlet_id': outletId,
      'feature_key': featureKey,
      'trust_level': trustLevel,
      'is_enabled': isEnabled,
      'config': config,
      'updated_by': updatedBy,
      'created_at': now,
      'updated_at': now,
    };

    final response = await _client
        .from(AppConstants.tableAITrustSettings)
        .insert(data)
        .select()
        .single();

    return AiTrustSetting.fromJson(Map<String, dynamic>.from(response));
  }
}
