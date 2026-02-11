import 'package:supabase_flutter/supabase_flutter.dart';

/// DevOps Context Builder - Provides complete backend knowledge to AI
///
/// This context builder gives the DevOps AI full awareness of:
/// - Database schema (tables, columns, relationships)
/// - Backend health status (connections, realtime, storage)
/// - Recent errors and diagnostics
/// - Migration status
/// - Performance metrics
/// - RLS policies
///
/// Used exclusively by DevOps AI for technical troubleshooting.
class DevOpsContextBuilder {
  final SupabaseClient _client;

  DevOpsContextBuilder({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  /// Build complete DevOps context for AI
  Future<Map<String, dynamic>> buildContext() async {
    try {
      final results = await Future.wait([
        _getDatabaseSchema(),
        _getBackendHealth(),
        _getMigrationStatus(),
        _getRecentErrors(),
        _getPerformanceMetrics(),
      ]);

      return {
        'database_schema': results[0],
        'backend_health': results[1],
        'migration_status': results[2],
        'recent_errors': results[3],
        'performance_metrics': results[4],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': 'Failed to build DevOps context: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get complete database schema
  Future<Map<String, dynamic>> _getDatabaseSchema() async {
    // Note: This is a static definition. In production, you could query
    // information_schema to get dynamic schema, but that requires elevated privileges.
    return {
      'tables': [
        {
          'name': 'outlets',
          'columns': ['id', 'name', 'address', 'created_at', 'updated_at'],
          'primary_key': 'id',
          'rls_enabled': true,
        },
        {
          'name': 'products',
          'columns': [
            'id',
            'outlet_id',
            'category_id',
            'name',
            'description',
            'price',
            'image_url',
            'is_active',
            'track_stock',
            'stock_quantity',
            'min_stock',
            'created_at',
            'updated_at'
          ],
          'primary_key': 'id',
          'foreign_keys': [
            'outlet_id → outlets(id)',
            'category_id → categories(id)'
          ],
          'rls_enabled': true,
          'indexes': ['idx_products_outlet', 'idx_products_category'],
        },
        {
          'name': 'categories',
          'columns': ['id', 'outlet_id', 'name', 'icon', 'order_index', 'created_at'],
          'primary_key': 'id',
          'foreign_keys': ['outlet_id → outlets(id)'],
          'rls_enabled': true,
        },
        {
          'name': 'ingredients',
          'columns': [
            'id',
            'outlet_id',
            'name',
            'unit',
            'base_unit',
            'current_stock',
            'min_stock',
            'max_stock',
            'cost_per_unit',
            'category',
            'supplier_id',
            'is_active',
            'created_at',
            'updated_at'
          ],
          'primary_key': 'id',
          'foreign_keys': ['outlet_id → outlets(id)', 'supplier_id → suppliers(id)'],
          'rls_enabled': true,
        },
        {
          'name': 'recipes',
          'columns': ['id', 'product_id', 'ingredient_id', 'quantity', 'created_at'],
          'primary_key': 'id',
          'foreign_keys': [
            'product_id → products(id)',
            'ingredient_id → ingredients(id)'
          ],
          'rls_enabled': true,
        },
        {
          'name': 'orders',
          'columns': [
            'id',
            'outlet_id',
            'order_number',
            'customer_name',
            'table_number',
            'status',
            'payment_status',
            'payment_method',
            'total_amount',
            'created_at',
            'updated_at'
          ],
          'primary_key': 'id',
          'foreign_keys': ['outlet_id → outlets(id)'],
          'rls_enabled': true,
          'realtime_enabled': true,
        },
        {
          'name': 'order_items',
          'columns': [
            'id',
            'order_id',
            'product_id',
            'quantity',
            'price',
            'subtotal',
            'notes',
            'created_at'
          ],
          'primary_key': 'id',
          'foreign_keys': ['order_id → orders(id)', 'product_id → products(id)'],
          'rls_enabled': true,
        },
        {
          'name': 'stock_movements',
          'columns': [
            'id',
            'outlet_id',
            'ingredient_id',
            'movement_type',
            'quantity',
            'notes',
            'created_by',
            'created_at'
          ],
          'primary_key': 'id',
          'foreign_keys': [
            'outlet_id → outlets(id)',
            'ingredient_id → ingredients(id)'
          ],
          'rls_enabled': true,
        },
      ],
      'relationships': [
        'outlets 1 → N products',
        'outlets 1 → N categories',
        'outlets 1 → N ingredients',
        'outlets 1 → N orders',
        'products N → 1 categories',
        'products 1 → N recipes → N ingredients (many-to-many)',
        'orders 1 → N order_items → N products',
        'ingredients 1 → N stock_movements',
      ],
      'total_tables': 8,
    };
  }

  /// Get backend health status
  Future<Map<String, dynamic>> _getBackendHealth() async {
    try {
      // Test database connection with a simple query
      final testQuery = await _client.from('outlets').select('id').limit(1);

      // Check if realtime is available (we can't easily check connection without trying)
      final realtimeStatus = _client.realtime.channels.isNotEmpty
          ? 'connected'
          : 'unknown';

      return {
        'database': {
          'status': 'healthy',
          'connection': 'active',
          'last_query': DateTime.now().toIso8601String(),
        },
        'realtime': {
          'status': realtimeStatus,
          'channels': _client.realtime.channels.length,
        },
        'api': {
          'status': 'healthy',
          'base_url': _client.supabaseUrl,
        },
      };
    } catch (e) {
      return {
        'database': {
          'status': 'error',
          'error': e.toString(),
        },
        'realtime': {
          'status': 'unknown',
        },
        'api': {
          'status': 'error',
        },
      };
    }
  }

  /// Get migration status
  Future<Map<String, dynamic>> _getMigrationStatus() async {
    // In a real implementation, you could query a migrations table
    // For now, we'll return a static list based on what we know
    return {
      'applied_migrations': [
        '001_core_tables.sql',
        '002_ai_tables.sql',
        '003_views_functions_rls.sql',
        '004_seed_data.sql',
        '005_staff_rpc.sql',
        '006_inventory_tables.sql',
        '007_ai_deepseek_rpc.sql',
        '008_refund_void.sql',
        '009_supplier_po.sql',
        '010_loyalty.sql',
        '011_ai_system_prompts.sql',
        '012_customer_tables.sql',
        '013_analytics_views.sql',
        '014_kds_tables.sql',
        '015_online_orders.sql',
        '016_payment_methods.sql',
        '017_ai_memory.sql',
        '018_modifier_groups.sql',
        '019_table_management.sql',
        '020_discount_system.sql',
        '021_tax_system.sql',
        '022_shift_management.sql',
        '023_cashier_system.sql',
        '024_split_payment.sql',
        '025_ai_insights.sql',
        '026_ingredient_category.sql',
        '027_ai_prediction.sql',
        '028_operational_costs.sql',
        '029_supplier_management.sql',
        '030_purchase_orders.sql',
        '031_product_stock.sql',
        '032_modifier_option_ingredients.sql',
        '033_unit_conversion_system.sql',
      ],
      'latest_migration': '033_unit_conversion_system.sql',
      'total_applied': 33,
      'status': 'up_to_date',
    };
  }

  /// Get recent errors (placeholder - will be populated by error tracker)
  Future<List<Map<String, dynamic>>> _getRecentErrors() async {
    // In production, this would query an error_logs table
    // For now, return empty - will be populated by error tracking service
    return [];
  }

  /// Get performance metrics (placeholder - will be populated by performance tracker)
  Future<Map<String, dynamic>> _getPerformanceMetrics() async {
    // In production, this would track query times, API latency, etc.
    return {
      'average_query_time': 'Not yet tracked',
      'slow_queries': [],
      'api_latency': 'Not yet tracked',
    };
  }

  /// Build system instruction for DevOps AI
  String buildSystemInstruction(Map<String, dynamic> context) {
    final schema = context['database_schema'] as Map<String, dynamic>? ?? {};
    final health = context['backend_health'] as Map<String, dynamic>? ?? {};
    final migrations = context['migration_status'] as Map<String, dynamic>? ?? {};
    final errors = context['recent_errors'] as List? ?? [];

    return '''Kamu adalah Utter DevOps AI, technical troubleshooting assistant untuk aplikasi Utter (F&B POS system).

FOKUS: Backend debugging, system health, performance optimization, database diagnostics.

== DATABASE SCHEMA ==
Total Tables: ${schema['total_tables'] ?? 0}

Key Tables:
${(schema['tables'] as List? ?? []).map((t) {
      final table = t as Map<String, dynamic>;
      final name = table['name'];
      final cols = (table['columns'] as List? ?? []).length;
      final rls = table['rls_enabled'] == true ? '🔒 RLS' : '';
      final realtime = table['realtime_enabled'] == true ? '🔔 Realtime' : '';
      return '- $name ($cols columns) $rls $realtime';
    }).join('\n')}

Relationships:
${(schema['relationships'] as List? ?? []).map((r) => '- $r').join('\n')}

== BACKEND HEALTH ==
Database: ${health['database']?['status'] ?? 'unknown'}
Realtime: ${health['realtime']?['status'] ?? 'unknown'} (${health['realtime']?['channels'] ?? 0} channels)
API: ${health['api']?['status'] ?? 'unknown'}

== MIGRATION STATUS ==
Latest: ${migrations['latest_migration'] ?? 'unknown'}
Total Applied: ${migrations['total_applied'] ?? 0}
Status: ${migrations['status'] ?? 'unknown'}

${errors.isNotEmpty ? '== RECENT ERRORS ==\n${errors.map((e) => '⚠️ ${e['timestamp']}: ${e['message']}').join('\n')}' : ''}

== KEMAMPUAN TEKNIS ==
Kamu BISA:
- Diagnose database connection issues
- Check RLS (Row Level Security) policies
- Verify migration status
- Analyze slow queries
- Troubleshoot realtime subscription issues
- Explain PostgreSQL errors
- Suggest performance optimizations
- Guide through Supabase dashboard

KAMU TIDAK BISA:
- Memberikan business insights (itu tugas Office AI)
- Memprediksi penjualan
- Analisa customer behavior
→ Untuk pertanyaan bisnis, redirect ke Office AI Dashboard

ATURAN PENTING:
1. Selalu diagnose dengan systematic approach (check connection → RLS → migration → data)
2. Berikan solusi yang actionable (SQL command, Supabase dashboard steps, or code fix)
3. Explain technical concepts dengan bahasa yang mudah dipahami
4. Jika ada error, explain WHY it happened dan HOW to prevent it
5. Safety first - jangan suggest destructive operations without warning
6. Kalau tidak tau, katakan tidak tau (jangan mengarang)

RESPONSE FORMAT:
🔍 Diagnosis: [What I found]
⚠️ Issue: [Root cause]
✅ Solution: [Step-by-step fix]
💡 Prevention: [How to avoid this in future]

CONTOH:
User: "Order baru tidak masuk ke POS"

Response:
🔍 Diagnosis: Checking realtime subscription...
✅ Database: Connected
✅ Table 'orders': Exists
⚠️ ISSUE FOUND: Realtime not enabled for 'orders' table

⚠️ Root Cause:
Table 'orders' tidak ada di replication publication.

✅ Solution:
1. Buka Supabase Dashboard → Database → Replication
2. Enable realtime untuk table 'orders'
3. Atau run SQL:
   ALTER PUBLICATION supabase_realtime ADD TABLE orders;

💡 Prevention:
Setelah create table baru, selalu enable realtime jika diperlukan.

Ready to help troubleshoot! 🔧''';
  }
}
