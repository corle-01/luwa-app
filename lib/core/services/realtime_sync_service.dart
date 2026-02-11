import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/outlet_provider.dart';
import '../../backoffice/providers/product_provider.dart';
import '../../backoffice/providers/recipe_provider.dart';
import '../../backoffice/providers/modifier_provider.dart';
import '../../backoffice/providers/inventory_provider.dart';
import '../../backoffice/providers/product_stock_provider.dart';
import '../../backoffice/providers/dashboard_provider.dart';
import '../../backoffice/providers/purchase_provider.dart';
import '../../backoffice/providers/operational_cost_provider.dart';
import '../../backoffice/providers/customer_provider.dart';
import '../../backoffice/providers/online_order_provider.dart';
import '../../pos/providers/pos_product_provider.dart';
import '../../pos/providers/pos_table_provider.dart';
import '../../pos/providers/pos_checkout_provider.dart';
import '../../kds/providers/kds_provider.dart';

/// Subscribes to Supabase Realtime and auto-invalidates Riverpod providers
/// when database tables change. Debounces rapid changes (500ms).
///
/// Usage: `ref.watch(realtimeSyncProvider)` in any shell/root widget.
final realtimeSyncProvider = Provider<void>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  final supabase = Supabase.instance.client;

  // Debounce timers per table to avoid rapid-fire invalidation
  final timers = <String, Timer>{};

  void debounced(String table, void Function() invalidate) {
    timers[table]?.cancel();
    timers[table] = Timer(const Duration(milliseconds: 500), invalidate);
  }

  final channel = supabase.channel('realtime-sync-$outletId');

  // ── Products ──────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'products',
    callback: (_) => debounced('products', () {
      ref.invalidate(boProductsProvider);
      ref.invalidate(posProductsProvider);
      ref.invalidate(productStockListProvider);
      ref.invalidate(productsWithRecipesProvider);
      ref.invalidate(dashboardStatsProvider);
    }),
  );

  // ── Categories ────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'categories',
    callback: (_) => debounced('categories', () {
      ref.invalidate(boCategoriesProvider);
      ref.invalidate(posCategoriesProvider);
    }),
  );

  // ── Ingredients ───────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'ingredients',
    callback: (_) => debounced('ingredients', () {
      ref.invalidate(ingredientsProvider);
      ref.invalidate(ingredientListForRecipeProvider);
      ref.invalidate(dashboardStatsProvider);
    }),
  );

  // ── Recipes ───────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'recipes',
    callback: (_) => debounced('recipes', () {
      ref.invalidate(productsWithRecipesProvider);
    }),
  );

  // ── Orders ────────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'orders',
    callback: (payload) {
      debugPrint('📦 RealtimeSync: Orders table changed - ${payload.eventType}');
      debounced('orders', () {
        debugPrint('🔄 RealtimeSync: Invalidating order providers');
        ref.invalidate(kdsOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentOrdersProvider);
        ref.invalidate(posTodayOrdersProvider);
      });
    },
  );

  // ── Stock Movements (ingredients) ─────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'stock_movements',
    callback: (_) => debounced('stock_movements', () {
      ref.invalidate(stockMovementsProvider);
      ref.invalidate(ingredientsProvider);
    }),
  );

  // ── Product Stock Movements ───────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'product_stock_movements',
    callback: (_) => debounced('product_stock_movements', () {
      ref.invalidate(allProductStockMovementsProvider);
      ref.invalidate(productStockListProvider);
    }),
  );

  // ── Purchases ─────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'purchases',
    callback: (_) => debounced('purchases', () {
      ref.invalidate(purchaseListProvider);
      ref.invalidate(purchaseStatsProvider);
    }),
  );

  // ── Operational Costs ───────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'operational_costs',
    callback: (_) => debounced('operational_costs', () {
      ref.invalidate(operationalCostsProvider);
      ref.invalidate(totalMonthlyCostProvider);
      ref.invalidate(costsByCategoryProvider);
      ref.invalidate(bonusPercentageProvider);
    }),
  );

  // ── Customers ─────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'customers',
    callback: (_) => debounced('customers', () {
      ref.invalidate(customerListProvider);
      ref.invalidate(dashboardStatsProvider);
    }),
  );

  // ── Tables ────────────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'tables',
    callback: (_) => debounced('tables', () {
      ref.invalidate(posTablesProvider);
    }),
  );

  // ── Online Orders ──────────────────────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'online_orders',
    callback: (_) => debounced('online_orders', () {
      ref.invalidate(onlineOrdersProvider);
      ref.invalidate(onlineOrderStatsProvider);
    }),
  );

  // ── Modifier Option Ingredients ───────────────────────────
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'modifier_option_ingredients',
    callback: (_) => debounced('modifier_option_ingredients', () {
      ref.invalidate(boModifierGroupsProvider);
    }),
  );

  debugPrint('🔌 RealtimeSync: Subscribing to channel for outlet $outletId');

  channel.subscribe((status, error) {
    if (error != null) {
      debugPrint('❌ RealtimeSync: Subscription error - $error');
    } else {
      debugPrint('✅ RealtimeSync: Subscription status - $status');
    }
  });

  ref.onDispose(() {
    debugPrint('🔌 RealtimeSync: Disposing channel for outlet $outletId');
    for (final t in timers.values) {
      t.cancel();
    }
    supabase.removeChannel(channel);
  });
});
