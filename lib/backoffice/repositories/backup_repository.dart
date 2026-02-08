import 'package:supabase_flutter/supabase_flutter.dart';

/// Summary of row counts per table for display.
class BackupSummary {
  final Map<String, int> tableCounts;
  final DateTime fetchedAt;

  BackupSummary({
    required this.tableCounts,
    required this.fetchedAt,
  });

  int get totalRows => tableCounts.values.fold(0, (a, b) => a + b);
}

/// Repository for exporting and importing all critical business data.
class BackupRepository {
  final _supabase = Supabase.instance.client;

  /// All critical tables to back up, in dependency order.
  static const _tables = [
    'categories',
    'products',
    'customers',
    'ingredients',
    'recipes',
    'taxes',
    'discounts',
    'tables',
    'staff_profiles',
    'orders',
    'order_items',
  ];

  /// Human-readable labels for each table.
  static const tableLabels = {
    'categories': 'Kategori',
    'products': 'Produk',
    'customers': 'Pelanggan',
    'ingredients': 'Bahan Baku',
    'recipes': 'Resep',
    'taxes': 'Pajak',
    'discounts': 'Diskon',
    'tables': 'Meja',
    'staff_profiles': 'Staff',
    'orders': 'Pesanan',
    'order_items': 'Item Pesanan',
  };

  /// Export all critical data for an outlet as a JSON-serializable map.
  Future<Map<String, dynamic>> exportAllData(String outletId) async {
    final data = <String, dynamic>{};

    // Categories
    data['categories'] = await _supabase
        .from('categories')
        .select()
        .eq('outlet_id', outletId);

    // Products
    data['products'] = await _supabase
        .from('products')
        .select()
        .eq('outlet_id', outletId);

    // Customers
    data['customers'] = await _supabase
        .from('customers')
        .select()
        .eq('outlet_id', outletId);

    // Ingredients
    data['ingredients'] = await _supabase
        .from('ingredients')
        .select()
        .eq('outlet_id', outletId);

    // Recipes — linked to products in this outlet
    final productIds = (data['products'] as List)
        .map((p) => p['id'] as String)
        .toList();
    if (productIds.isNotEmpty) {
      data['recipes'] = await _supabase
          .from('recipes')
          .select()
          .inFilter('product_id', productIds);
    } else {
      data['recipes'] = [];
    }

    // Taxes
    data['taxes'] = await _supabase
        .from('taxes')
        .select()
        .eq('outlet_id', outletId);

    // Discounts
    data['discounts'] = await _supabase
        .from('discounts')
        .select()
        .eq('outlet_id', outletId);

    // Tables
    data['tables'] = await _supabase
        .from('tables')
        .select()
        .eq('outlet_id', outletId);

    // Staff profiles
    data['staff_profiles'] = await _supabase
        .from('staff_profiles')
        .select()
        .eq('outlet_id', outletId);

    // Orders
    data['orders'] = await _supabase
        .from('orders')
        .select()
        .eq('outlet_id', outletId);

    // Order items — linked to orders
    final orderIds = (data['orders'] as List)
        .map((o) => o['id'] as String)
        .toList();
    if (orderIds.isNotEmpty) {
      // Fetch in batches to avoid overly large IN clauses
      final allItems = <dynamic>[];
      const batchSize = 100;
      for (var i = 0; i < orderIds.length; i += batchSize) {
        final batch = orderIds.sublist(
          i,
          i + batchSize > orderIds.length ? orderIds.length : i + batchSize,
        );
        final items = await _supabase
            .from('order_items')
            .select()
            .inFilter('order_id', batch);
        allItems.addAll(items as List);
      }
      data['order_items'] = allItems;
    } else {
      data['order_items'] = [];
    }

    // Metadata
    data['_meta'] = {
      'version': '1.0',
      'outlet_id': outletId,
      'exported_at': DateTime.now().toIso8601String(),
      'table_counts': {
        for (final table in _tables)
          table: (data[table] as List).length,
      },
    };

    return data;
  }

  /// Import data from a backup JSON map, upserting rows with conflict handling.
  /// Returns a summary of how many rows were imported per table.
  Future<Map<String, int>> importData(Map<String, dynamic> jsonData) async {
    final counts = <String, int>{};

    // Import in dependency order so foreign keys resolve
    for (final table in _tables) {
      final rows = jsonData[table];
      if (rows == null || rows is! List || rows.isEmpty) {
        counts[table] = 0;
        continue;
      }

      final rowMaps = rows.cast<Map<String, dynamic>>();

      // Upsert in batches
      const batchSize = 50;
      for (var i = 0; i < rowMaps.length; i += batchSize) {
        final batch = rowMaps.sublist(
          i,
          i + batchSize > rowMaps.length ? rowMaps.length : i + batchSize,
        );
        await _supabase
            .from(table)
            .upsert(batch, onConflict: 'id');
      }
      counts[table] = rowMaps.length;
    }

    return counts;
  }

  /// Get row counts per table for display (backup summary).
  Future<BackupSummary> getBackupSummary(String outletId) async {
    final counts = <String, int>{};

    // Categories
    final categories = await _supabase
        .from('categories')
        .select('id')
        .eq('outlet_id', outletId);
    counts['categories'] = (categories as List).length;

    // Products
    final products = await _supabase
        .from('products')
        .select('id')
        .eq('outlet_id', outletId);
    counts['products'] = (products as List).length;

    // Customers
    final customers = await _supabase
        .from('customers')
        .select('id')
        .eq('outlet_id', outletId);
    counts['customers'] = (customers as List).length;

    // Ingredients
    final ingredients = await _supabase
        .from('ingredients')
        .select('id')
        .eq('outlet_id', outletId);
    counts['ingredients'] = (ingredients as List).length;

    // Taxes
    final taxes = await _supabase
        .from('taxes')
        .select('id')
        .eq('outlet_id', outletId);
    counts['taxes'] = (taxes as List).length;

    // Discounts
    final discounts = await _supabase
        .from('discounts')
        .select('id')
        .eq('outlet_id', outletId);
    counts['discounts'] = (discounts as List).length;

    // Tables
    final tables = await _supabase
        .from('tables')
        .select('id')
        .eq('outlet_id', outletId);
    counts['tables'] = (tables as List).length;

    // Staff profiles
    final staff = await _supabase
        .from('staff_profiles')
        .select('id')
        .eq('outlet_id', outletId);
    counts['staff_profiles'] = (staff as List).length;

    // Orders
    final orders = await _supabase
        .from('orders')
        .select('id')
        .eq('outlet_id', outletId);
    counts['orders'] = (orders as List).length;

    // Recipes — count all
    final productIds = (products as List).map((p) => p['id'] as String).toList();
    if (productIds.isNotEmpty) {
      final recipes = await _supabase
          .from('recipes')
          .select('id')
          .inFilter('product_id', productIds);
      counts['recipes'] = (recipes as List).length;
    } else {
      counts['recipes'] = 0;
    }

    // Order items — count all
    final orderIds = (orders as List).map((o) => o['id'] as String).toList();
    if (orderIds.isNotEmpty) {
      int totalItems = 0;
      const batchSize = 100;
      for (var i = 0; i < orderIds.length; i += batchSize) {
        final batch = orderIds.sublist(
          i,
          i + batchSize > orderIds.length ? orderIds.length : i + batchSize,
        );
        final items = await _supabase
            .from('order_items')
            .select('id')
            .inFilter('order_id', batch);
        totalItems += (items as List).length;
      }
      counts['order_items'] = totalItems;
    } else {
      counts['order_items'] = 0;
    }

    return BackupSummary(
      tableCounts: counts,
      fetchedAt: DateTime.now(),
    );
  }

  /// Validate that a JSON map is a valid backup file.
  /// Returns null if valid, or an error message if invalid.
  String? validateBackup(Map<String, dynamic> jsonData) {
    // Must have metadata
    if (jsonData['_meta'] == null) {
      return 'File backup tidak valid: metadata tidak ditemukan';
    }

    final meta = jsonData['_meta'] as Map<String, dynamic>;
    if (meta['version'] == null) {
      return 'File backup tidak valid: versi tidak ditemukan';
    }

    // Must have at least one data table
    bool hasData = false;
    for (final table in _tables) {
      if (jsonData[table] is List && (jsonData[table] as List).isNotEmpty) {
        hasData = true;
        break;
      }
    }

    if (!hasData) {
      return 'File backup kosong: tidak ada data yang ditemukan';
    }

    return null;
  }
}
