import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:utter_app/core/services/ai/devops_context_builder.dart';

/// DevOps Health Provider - Monitors backend health status
///
/// Provides real-time backend health metrics including:
/// - Database connection status
/// - Realtime subscription status
/// - API health
final devopsHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final contextBuilder = DevOpsContextBuilder();
    final context = await contextBuilder.buildContext();

    return context['backend_health'] as Map<String, dynamic>? ?? {
      'database': {'status': 'unknown'},
      'realtime': {'status': 'unknown', 'channels': 0},
      'api': {'status': 'unknown'},
    };
  } catch (e) {
    return {
      'database': {
        'status': 'error',
        'error': e.toString(),
      },
      'realtime': {
        'status': 'error',
      },
      'api': {
        'status': 'error',
      },
    };
  }
});

/// DevOps Context Provider - Full backend context for AI
///
/// Provides complete backend knowledge including:
/// - Database schema
/// - Backend health
/// - Migration status
/// - Recent errors
/// - Performance metrics
final devopsContextProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final contextBuilder = DevOpsContextBuilder();
    return await contextBuilder.buildContext();
  } catch (e) {
    return {
      'error': 'Failed to build DevOps context: $e',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
});
