/// DevOps Tools - Diagnostic functions for technical troubleshooting
///
/// These tools are ONLY available to DevOps AI, not Business AI.
/// They provide deep backend access for diagnosing issues.
class DevOpsTools {
  /// Get all DevOps tool declarations for AI
  static List<Map<String, dynamic>> get toolDeclarations => [
        checkDatabaseHealthTool,
        diagnoseRLSIssueTool,
        verifyMigrationStatusTool,
        checkRealtimeSubscriptionTool,
        analyzeSlowQueriesTool,
        getErrorDetailsTool,
        testDatabaseConnectionTool,
      ];

  // ══════════════════════════════════════════════════════════
  // Tool Declarations
  // ══════════════════════════════════════════════════════════

  static const checkDatabaseHealthTool = {
    'name': 'check_database_health',
    'description':
        'Check Supabase database health: connection status, active connections, query performance. Use this when user reports database connectivity issues or slow performance.',
    'parameters': {
      'type': 'object',
      'properties': {},
    },
  };

  static const diagnoseRLSIssueTool = {
    'name': 'diagnose_rls_issue',
    'description':
        'Diagnose Row Level Security (RLS) policy issues for a specific table. Use when user gets "permission denied" or "policy violation" errors. Returns policy status and suggested fixes.',
    'parameters': {
      'type': 'object',
      'properties': {
        'table_name': {
          'type': 'string',
          'description': 'Name of the table to check RLS policies for',
        },
      },
      'required': ['table_name'],
    },
  };

  static const verifyMigrationStatusTool = {
    'name': 'verify_migration_status',
    'description':
        'Verify which database migrations have been applied and which are pending. Use when user reports missing features or database structure issues.',
    'parameters': {
      'type': 'object',
      'properties': {},
    },
  };

  static const checkRealtimeSubscriptionTool = {
    'name': 'check_realtime_subscription',
    'description':
        'Check if Supabase realtime is properly configured and working for a specific table. Use when user reports data not updating in real-time (e.g., orders not appearing in POS).',
    'parameters': {
      'type': 'object',
      'properties': {
        'table_name': {
          'type': 'string',
          'description': 'Name of the table to check realtime for',
        },
      },
      'required': ['table_name'],
    },
  };

  static const analyzeSlowQueriesTool = {
    'name': 'analyze_slow_queries',
    'description':
        'Identify slow database queries and suggest optimizations (indexes, query structure). Use when user reports slow page loads or performance issues.',
    'parameters': {
      'type': 'object',
      'properties': {
        'threshold_ms': {
          'type': 'number',
          'description':
              'Query time threshold in milliseconds (default: 1000ms)',
        },
      },
    },
  };

  static const getErrorDetailsTool = {
    'name': 'get_error_details',
    'description':
        'Get detailed information about a specific error including stack trace, context, and suggested solutions. Use when user reports an error message.',
    'parameters': {
      'type': 'object',
      'properties': {
        'error_message': {
          'type': 'string',
          'description': 'The error message or error code to investigate',
        },
      },
      'required': ['error_message'],
    },
  };

  static const testDatabaseConnectionTool = {
    'name': 'test_database_connection',
    'description':
        'Test database connection to Supabase and measure response time. Use for basic connectivity troubleshooting.',
    'parameters': {
      'type': 'object',
      'properties': {},
    },
  };
}
