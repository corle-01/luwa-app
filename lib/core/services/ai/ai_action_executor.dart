import 'package:supabase_flutter/supabase_flutter.dart';

/// Executes AI function calls against the real database.
///
/// This is the bridge between AI intent and actual system actions.
/// Each method maps to a tool defined in [AiTools].
class AiActionExecutor {
  final SupabaseClient _client;
  static const _outletId = 'a0000000-0000-0000-0000-000000000001';

  AiActionExecutor({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Route a function call to the appropriate handler.
  Future<Map<String, dynamic>> execute(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    switch (functionName) {
      case 'create_product':
        return _createProduct(args);
      case 'update_product':
        return _updateProduct(args);
      case 'delete_product':
        return _deleteProduct(args);
      case 'toggle_product':
        return _toggleProduct(args);
      case 'list_products':
        return _listProducts(args);
      case 'create_category':
        return _createCategory(args);
      case 'delete_category':
        return _deleteCategory(args);
      case 'update_stock':
        return _updateStock(args);
      case 'list_ingredients':
        return _listIngredients(args);
      case 'get_sales_summary':
        return _getSalesSummary(args);
      case 'create_discount':
        return _createDiscount(args);
      default:
        return {'success': false, 'error': 'Unknown function: $functionName'};
    }
  }

  // ── Product Management ──────────────────────────────────────

  Future<Map<String, dynamic>> _createProduct(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final sellingPrice = (args['selling_price'] as num).toDouble();
    final costPrice = (args['cost_price'] as num?)?.toDouble() ?? 0;
    final description = args['description'] as String?;
    final categoryName = args['category_name'] as String?;

    // Find category ID if name provided
    String? categoryId;
    if (categoryName != null && categoryName.isNotEmpty) {
      final cats = await _client
          .from('categories')
          .select('id, name')
          .eq('outlet_id', _outletId)
          .ilike('name', '%$categoryName%')
          .limit(1);
      if ((cats as List).isNotEmpty) {
        categoryId = cats[0]['id'] as String;
      } else {
        // Create category if not found
        final newCat = await _client
            .from('categories')
            .insert({'outlet_id': _outletId, 'name': categoryName, 'is_active': true})
            .select('id')
            .single();
        categoryId = newCat['id'] as String;
      }
    }

    final result = await _client
        .from('products')
        .insert({
          'outlet_id': _outletId,
          'name': name,
          'selling_price': sellingPrice,
          'cost_price': costPrice,
          'category_id': categoryId,
          'description': description,
          'is_active': true,
        })
        .select('id, name, selling_price')
        .single();

    return {
      'success': true,
      'message': 'Produk "$name" berhasil ditambahkan dengan harga Rp ${sellingPrice.toStringAsFixed(0)}',
      'product': result,
    };
  }

  Future<Map<String, dynamic>> _updateProduct(Map<String, dynamic> args) async {
    final productName = args['product_name'] as String;

    // Find product by name (fuzzy)
    final products = await _client
        .from('products')
        .select('id, name, selling_price, cost_price')
        .eq('outlet_id', _outletId)
        .ilike('name', '%$productName%')
        .limit(1);

    if ((products as List).isEmpty) {
      return {'success': false, 'error': 'Produk "$productName" tidak ditemukan'};
    }

    final product = products[0];
    final productId = product['id'] as String;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (args['new_name'] != null) updates['name'] = args['new_name'];
    if (args['selling_price'] != null) updates['selling_price'] = (args['selling_price'] as num).toDouble();
    if (args['cost_price'] != null) updates['cost_price'] = (args['cost_price'] as num).toDouble();
    if (args['description'] != null) updates['description'] = args['description'];

    await _client.from('products').update(updates).eq('id', productId);

    return {
      'success': true,
      'message': 'Produk "${product['name']}" berhasil diupdate',
      'updates': updates,
    };
  }

  Future<Map<String, dynamic>> _deleteProduct(Map<String, dynamic> args) async {
    final productName = args['product_name'] as String;

    final products = await _client
        .from('products')
        .select('id, name')
        .eq('outlet_id', _outletId)
        .ilike('name', '%$productName%')
        .limit(1);

    if ((products as List).isEmpty) {
      return {'success': false, 'error': 'Produk "$productName" tidak ditemukan'};
    }

    final product = products[0];
    await _client.from('products').delete().eq('id', product['id'] as String);

    return {
      'success': true,
      'message': 'Produk "${product['name']}" berhasil dihapus',
    };
  }

  Future<Map<String, dynamic>> _toggleProduct(Map<String, dynamic> args) async {
    final productName = args['product_name'] as String;
    final isActive = args['is_active'] as bool;

    final products = await _client
        .from('products')
        .select('id, name')
        .eq('outlet_id', _outletId)
        .ilike('name', '%$productName%')
        .limit(1);

    if ((products as List).isEmpty) {
      return {'success': false, 'error': 'Produk "$productName" tidak ditemukan'};
    }

    final product = products[0];
    await _client.from('products').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', product['id'] as String);

    return {
      'success': true,
      'message': 'Produk "${product['name']}" ${isActive ? "diaktifkan" : "dinonaktifkan"}',
    };
  }

  Future<Map<String, dynamic>> _listProducts(Map<String, dynamic> args) async {
    final categoryName = args['category_name'] as String?;
    final activeOnly = args['active_only'] as bool? ?? true;

    var query = _client
        .from('products')
        .select('name, selling_price, cost_price, is_active, categories(name)')
        .eq('outlet_id', _outletId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final products = await query.order('name');
    final list = List<Map<String, dynamic>>.from(products);

    // Filter by category name if provided
    var filtered = list;
    if (categoryName != null && categoryName.isNotEmpty) {
      final catLower = categoryName.toLowerCase();
      filtered = list.where((p) {
        final cat = p['categories']?['name']?.toString().toLowerCase() ?? '';
        return cat.contains(catLower);
      }).toList();
    }

    final summary = filtered.map((p) => {
      'name': p['name'],
      'harga': p['selling_price'],
      'modal': p['cost_price'],
      'kategori': p['categories']?['name'] ?? 'Tanpa Kategori',
      'aktif': p['is_active'],
    }).toList();

    return {
      'success': true,
      'total': summary.length,
      'products': summary,
    };
  }

  // ── Category Management ─────────────────────────────────────

  Future<Map<String, dynamic>> _createCategory(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final color = args['color'] as String?;

    await _client.from('categories').insert({
      'outlet_id': _outletId,
      'name': name,
      'color': color,
      'is_active': true,
    });

    return {
      'success': true,
      'message': 'Kategori "$name" berhasil ditambahkan',
    };
  }

  Future<Map<String, dynamic>> _deleteCategory(Map<String, dynamic> args) async {
    final categoryName = args['category_name'] as String;

    final cats = await _client
        .from('categories')
        .select('id, name')
        .eq('outlet_id', _outletId)
        .ilike('name', '%$categoryName%')
        .limit(1);

    if ((cats as List).isEmpty) {
      return {'success': false, 'error': 'Kategori "$categoryName" tidak ditemukan'};
    }

    final cat = cats[0];
    final catId = cat['id'] as String;

    // Uncategorize products first
    await _client.from('products').update({'category_id': null}).eq('category_id', catId);
    await _client.from('categories').delete().eq('id', catId);

    return {
      'success': true,
      'message': 'Kategori "${cat['name']}" berhasil dihapus',
    };
  }

  // ── Inventory Management ────────────────────────────────────

  Future<Map<String, dynamic>> _updateStock(Map<String, dynamic> args) async {
    final ingredientName = args['ingredient_name'] as String;
    final newQuantity = (args['new_quantity'] as num?)?.toDouble();
    final adjustment = (args['adjustment'] as num?)?.toDouble();
    final notes = args['notes'] as String?;

    final ingredients = await _client
        .from('ingredients')
        .select('id, name, current_stock, unit')
        .eq('outlet_id', _outletId)
        .ilike('name', '%$ingredientName%')
        .limit(1);

    if ((ingredients as List).isEmpty) {
      return {'success': false, 'error': 'Bahan "$ingredientName" tidak ditemukan'};
    }

    final ingredient = ingredients[0];
    final ingredientId = ingredient['id'] as String;
    final currentStock = (ingredient['current_stock'] as num?)?.toDouble() ?? 0;

    double finalStock;
    String movementType;
    double movementQty;

    if (newQuantity != null) {
      finalStock = newQuantity;
      movementQty = newQuantity - currentStock;
      movementType = movementQty >= 0 ? 'adjustment_in' : 'adjustment_out';
    } else if (adjustment != null) {
      finalStock = currentStock + adjustment;
      movementQty = adjustment;
      movementType = adjustment >= 0 ? 'adjustment_in' : 'adjustment_out';
    } else {
      return {'success': false, 'error': 'Harus isi new_quantity atau adjustment'};
    }

    // Update stock
    await _client.from('ingredients').update({
      'current_stock': finalStock,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ingredientId);

    // Record stock movement
    await _client.from('stock_movements').insert({
      'ingredient_id': ingredientId,
      'outlet_id': _outletId,
      'movement_type': movementType,
      'quantity': movementQty.abs(),
      'notes': notes ?? 'Updated via AI',
    });

    return {
      'success': true,
      'message': 'Stok ${ingredient['name']} diupdate: $currentStock → $finalStock ${ingredient['unit']}',
      'previous_stock': currentStock,
      'new_stock': finalStock,
      'unit': ingredient['unit'],
    };
  }

  Future<Map<String, dynamic>> _listIngredients(Map<String, dynamic> args) async {
    final lowStockOnly = args['low_stock_only'] as bool? ?? false;

    final ingredients = await _client
        .from('ingredients')
        .select('name, current_stock, min_stock, unit')
        .eq('outlet_id', _outletId)
        .order('name');

    var list = List<Map<String, dynamic>>.from(ingredients);

    if (lowStockOnly) {
      list = list.where((i) {
        final current = (i['current_stock'] as num?)?.toDouble() ?? 0;
        final min = (i['min_stock'] as num?)?.toDouble() ?? 0;
        return current <= min;
      }).toList();
    }

    return {
      'success': true,
      'total': list.length,
      'ingredients': list.map((i) => {
        'name': i['name'],
        'stok': i['current_stock'],
        'min_stok': i['min_stock'],
        'unit': i['unit'],
        'low': ((i['current_stock'] as num?)?.toDouble() ?? 0) <=
            ((i['min_stock'] as num?)?.toDouble() ?? 0),
      }).toList(),
    };
  }

  // ── Sales & Analytics ───────────────────────────────────────

  Future<Map<String, dynamic>> _getSalesSummary(Map<String, dynamic> args) async {
    final period = args['period'] as String? ?? 'today';

    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (period) {
      case 'yesterday':
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'this_week':
        final now = DateTime.now();
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'this_month':
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'custom':
        startDate = DateTime.parse(args['start_date'] as String? ?? DateTime.now().toIso8601String());
        if (args['end_date'] != null) endDate = DateTime.parse(args['end_date'] as String);
        break;
      default: // today
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, now.day);
    }

    final orders = await _client
        .from('orders')
        .select('id, order_number, total, status, payment_method, created_at, order_items(product_name, quantity, subtotal)')
        .eq('outlet_id', _outletId)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: false);

    final orderList = List<Map<String, dynamic>>.from(orders);

    double totalRevenue = 0;
    int completedCount = 0;
    final paymentBreakdown = <String, double>{};
    final productSales = <String, int>{};

    for (final o in orderList) {
      final total = (o['total'] as num?)?.toDouble() ?? 0;
      if (o['status'] == 'completed') {
        totalRevenue += total;
        completedCount++;
        final pm = o['payment_method']?.toString() ?? 'cash';
        paymentBreakdown[pm] = (paymentBreakdown[pm] ?? 0) + total;
      }
      for (final item in (o['order_items'] as List? ?? [])) {
        final pName = item['product_name']?.toString() ?? 'Unknown';
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        productSales[pName] = (productSales[pName] ?? 0) + qty;
      }
    }

    // Sort top products
    final topProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'success': true,
      'period': period,
      'total_orders': orderList.length,
      'completed_orders': completedCount,
      'total_revenue': totalRevenue,
      'average_order': completedCount > 0 ? totalRevenue / completedCount : 0,
      'payment_breakdown': paymentBreakdown,
      'top_products': topProducts.take(10).map((e) => {'name': e.key, 'qty': e.value}).toList(),
    };
  }

  // ── Discount Management ─────────────────────────────────────

  Future<Map<String, dynamic>> _createDiscount(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final type = args['type'] as String;
    final value = (args['value'] as num).toDouble();
    final minPurchase = (args['min_purchase'] as num?)?.toDouble();

    await _client.from('discounts').insert({
      'outlet_id': _outletId,
      'name': name,
      'type': type,
      'value': value,
      'min_purchase': minPurchase,
      'is_active': true,
    });

    return {
      'success': true,
      'message': 'Diskon "$name" (${type == "percentage" ? "$value%" : "Rp $value"}) berhasil dibuat',
    };
  }
}
