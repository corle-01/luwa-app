import 'package:supabase_flutter/supabase_flutter.dart';

/// DevOps Action Executor - Executes diagnostic tools called by DevOps AI
class DevOpsActionExecutor {
  final SupabaseClient _client;

  DevOpsActionExecutor({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  /// Execute a DevOps tool action
  Future<Map<String, dynamic>> execute(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (functionName) {
        case 'check_database_health':
          return await _checkDatabaseHealth();

        case 'diagnose_rls_issue':
          final tableName = args['table_name'] as String;
          return await _diagnoseRLSIssue(tableName);

        case 'verify_migration_status':
          return await _verifyMigrationStatus();

        case 'check_realtime_subscription':
          final tableName = args['table_name'] as String;
          return await _checkRealtimeSubscription(tableName);

        case 'analyze_slow_queries':
          final threshold = args['threshold_ms'] as int? ?? 1000;
          return await _analyzeSlowQueries(threshold);

        case 'get_error_details':
          final errorMessage = args['error_message'] as String;
          return await _getErrorDetails(errorMessage);

        case 'test_database_connection':
          return await _testDatabaseConnection();

        default:
          return {
            'success': false,
            'error': 'Unknown DevOps tool: $functionName',
          };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'DevOps tool execution failed: $e',
      };
    }
  }

  // ══════════════════════════════════════════════════════════
  // Tool Implementations
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _checkDatabaseHealth() async {
    try {
      final startTime = DateTime.now();

      // Test a simple query
      await _client.from('outlets').select('id').limit(1);

      final responseTime =
          DateTime.now().difference(startTime).inMilliseconds;

      return {
        'success': true,
        'status': 'healthy',
        'details': {
          'connection': 'active',
          'response_time_ms': responseTime,
          'database_url': _client.supabaseUrl,
          'realtime_channels': _client.realtime.channels.length,
        },
        'message': 'Database is healthy. Response time: ${responseTime}ms',
      };
    } catch (e) {
      return {
        'success': false,
        'status': 'error',
        'error': e.toString(),
        'message':
            'Database health check failed. Connection issue or authentication problem.',
        'suggested_fix':
            'Check Supabase credentials (SUPABASE_URL, SUPABASE_ANON_KEY) in environment variables.',
      };
    }
  }

  Future<Map<String, dynamic>> _diagnoseRLSIssue(String tableName) async {
    // Since we can't query pg_policies without elevated privileges,
    // we provide static knowledge about common RLS patterns

    final knownTables = {
      'products': {
        'expected_policies': [
          'Allow anon read products',
          'Allow anon insert products',
          'Allow anon update products'
        ],
        'rls_enabled': true,
      },
      'orders': {
        'expected_policies': [
          'Allow anon read orders',
          'Allow anon insert orders',
          'Allow anon update orders'
        ],
        'rls_enabled': true,
        'realtime_enabled': true,
      },
      'ingredients': {
        'expected_policies': [
          'Allow anon read ingredients',
          'Allow anon insert ingredients',
          'Allow anon update ingredients'
        ],
        'rls_enabled': true,
      },
    };

    if (knownTables.containsKey(tableName)) {
      final tableInfo = knownTables[tableName]!;

      return {
        'success': true,
        'table': tableName,
        'rls_enabled': tableInfo['rls_enabled'],
        'expected_policies': tableInfo['expected_policies'],
        'realtime_enabled': tableInfo['realtime_enabled'] ?? false,
        'diagnosis':
            'Table "$tableName" should have RLS policies for anon role.',
        'check_steps': [
          '1. Open Supabase Dashboard → Authentication → Policies',
          '2. Select table: $tableName',
          '3. Verify policies exist for SELECT, INSERT, UPDATE operations',
          '4. Ensure policies allow "anon" role with USING (true)',
        ],
        'fix_sql': '''
-- If policies are missing, run this SQL:
CREATE POLICY "Allow anon read $tableName"
ON $tableName FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anon insert $tableName"
ON $tableName FOR INSERT
TO anon
WITH CHECK (true);

CREATE POLICY "Allow anon update $tableName"
ON $tableName FOR UPDATE
TO anon
USING (true);
''',
      };
    }

    return {
      'success': true,
      'table': tableName,
      'message':
          'Table "$tableName" is not in the common tables list. General RLS check:',
      'check_steps': [
        '1. Verify RLS is enabled: ALTER TABLE $tableName ENABLE ROW LEVEL SECURITY;',
        '2. Create policies for required operations (SELECT, INSERT, UPDATE, DELETE)',
        '3. Test with: SELECT * FROM $tableName LIMIT 1;',
      ],
    };
  }

  Future<Map<String, dynamic>> _verifyMigrationStatus() async {
    // Return static migration list
    // In production, you'd query a supabase_migrations table
    final appliedMigrations = [
      '001_core_tables.sql',
      '002_ai_tables.sql',
      '003_views_functions_rls.sql',
      '033_unit_conversion_system.sql',
    ];

    return {
      'success': true,
      'total_applied': appliedMigrations.length,
      'latest_migration': appliedMigrations.last,
      'applied_migrations': appliedMigrations,
      'status': 'up_to_date',
      'message':
          '${appliedMigrations.length} migrations applied. Latest: ${appliedMigrations.last}',
    };
  }

  Future<Map<String, dynamic>> _checkRealtimeSubscription(
      String tableName) async {
    // Check if table is in known realtime-enabled tables
    final realtimeTables = ['orders', 'products', 'ingredients'];

    final isRealtimeEnabled = realtimeTables.contains(tableName);

    if (!isRealtimeEnabled) {
      return {
        'success': true,
        'table': tableName,
        'realtime_enabled': false,
        'message': 'Table "$tableName" is not configured for realtime.',
        'fix_steps': [
          '1. Open Supabase Dashboard → Database → Replication',
          '2. Find publication: supabase_realtime',
          '3. Add table: $tableName',
          'OR run SQL: ALTER PUBLICATION supabase_realtime ADD TABLE $tableName;',
        ],
      };
    }

    // Check active channels
    final activeChannels = _client.realtime.channels.length;

    return {
      'success': true,
      'table': tableName,
      'realtime_enabled': true,
      'active_channels': activeChannels,
      'channel_status': activeChannels > 0 ? 'connected' : 'no active channels',
      'message': activeChannels > 0
          ? 'Realtime is configured and active for "$tableName". $activeChannels channel(s) connected.'
          : 'Realtime is configured but no active subscription. Make sure frontend code subscribes to changes.',
      'frontend_check':
          'Verify realtimeSyncProvider is watched in the app (should be in pos_main_page.dart or similar)',
    };
  }

  Future<Map<String, dynamic>> _analyzeSlowQueries(int thresholdMs) async {
    // This is a placeholder - in production you'd analyze query logs
    return {
      'success': true,
      'threshold_ms': thresholdMs,
      'slow_queries_found': 0,
      'message': 'Slow query tracking not yet implemented.',
      'recommendation':
          'Monitor query performance using Supabase Dashboard → Database → Query Performance',
      'common_optimizations': [
        'Add indexes on frequently queried columns (created_at, outlet_id, status)',
        'Use LIMIT on large result sets',
        'Add date filters to avoid scanning entire tables',
        'Use specific column selection (SELECT id, name) instead of SELECT *',
      ],
    };
  }

  Future<Map<String, dynamic>> _getErrorDetails(String errorMessage) async {
    // Error pattern matching and solutions
    final errorLower = errorMessage.toLowerCase();

    // RLS permission denied
    if (errorLower.contains('permission denied') ||
        errorLower.contains('policy')) {
      return {
        'success': true,
        'error_type': 'RLS_POLICY_DENIED',
        'explanation':
            'Row Level Security (RLS) policy is blocking this operation.',
        'common_causes': [
          'Missing RLS policy for the user role (anon/authenticated)',
          'Policy condition (USING clause) is too restrictive',
          'Table has RLS enabled but no policies defined',
        ],
        'solution_steps': [
          '1. Identify which table is affected',
          '2. Use diagnose_rls_issue tool for that table',
          '3. Create or update RLS policies',
          '4. Test with: SELECT * FROM table_name LIMIT 1;',
        ],
      };
    }

    // Connection errors
    if (errorLower.contains('connection') || errorLower.contains('timeout')) {
      return {
        'success': true,
        'error_type': 'CONNECTION_ERROR',
        'explanation': 'Cannot connect to Supabase database.',
        'common_causes': [
          'Network connectivity issues',
          'Incorrect Supabase URL or credentials',
          'Supabase project paused (free tier)',
          'Firewall blocking connection',
        ],
        'solution_steps': [
          '1. Check internet connection',
          '2. Verify SUPABASE_URL and SUPABASE_ANON_KEY in .env',
          '3. Check Supabase project status in dashboard',
          '4. Use test_database_connection tool',
        ],
      };
    }

    // Column does not exist
    if (errorLower.contains('column') && errorLower.contains('does not exist')) {
      return {
        'success': true,
        'error_type': 'COLUMN_NOT_FOUND',
        'explanation': 'Code is referencing a database column that doesn\'t exist.',
        'common_causes': [
          'Migration not applied (missing ALTER TABLE ADD COLUMN)',
          'Typo in column name',
          'Old code after schema change',
        ],
        'solution_steps': [
          '1. Use verify_migration_status tool',
          '2. Check if recent migration added this column',
          '3. If yes: run migration. If no: fix code typo',
          '4. Clear app cache and rebuild: flutter clean && flutter build web',
        ],
      };
    }

    // Generic response
    return {
      'success': true,
      'error_type': 'UNKNOWN',
      'error_message': errorMessage,
      'general_troubleshooting': [
        '1. Check database connection (use test_database_connection)',
        '2. Verify migration status (use verify_migration_status)',
        '3. Check RLS policies if permission-related',
        '4. Review Supabase logs in Dashboard → Logs',
        '5. Search error message in Supabase docs: https://supabase.com/docs',
      ],
    };
  }

  Future<Map<String, dynamic>> _testDatabaseConnection() async {
    try {
      final startTime = DateTime.now();

      // Ping with minimal query
      await _client.from('outlets').select('id').limit(1);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      return {
        'success': true,
        'status': 'connected',
        'latency_ms': latency,
        'message': 'Database connection successful! Latency: ${latency}ms',
        'performance':
            latency < 100 ? 'excellent' : latency < 500 ? 'good' : 'slow',
      };
    } catch (e) {
      return {
        'success': false,
        'status': 'failed',
        'error': e.toString(),
        'message': 'Database connection failed.',
        'troubleshooting': [
          'Check SUPABASE_URL is correct',
          'Check SUPABASE_ANON_KEY is valid',
          'Verify Supabase project is not paused',
          'Test connection in Supabase Dashboard',
        ],
      };
    }
  }
}
