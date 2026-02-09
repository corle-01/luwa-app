import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/self_order_repository.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------
final selfOrderRepositoryProvider = Provider<SelfOrderRepository>((ref) {
  return SelfOrderRepository();
});

// ---------------------------------------------------------------------------
// Categories provider
// ---------------------------------------------------------------------------
final selfOrderCategoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(selfOrderRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getCategories(outletId);
});

// ---------------------------------------------------------------------------
// Menu products provider — returns products grouped by category
// Key = category name, Value = list of products in that category
// ---------------------------------------------------------------------------
final selfOrderMenuProvider =
    FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final repo = ref.watch(selfOrderRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  final products = await repo.getMenuProducts(outletId);

  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final product in products) {
    final category = product['categories'] as Map<String, dynamic>?;
    final categoryName = category?['name'] as String? ?? 'Lainnya';
    grouped.putIfAbsent(categoryName, () => []);
    grouped[categoryName]!.add(product);
  }
  return grouped;
});

// ---------------------------------------------------------------------------
// Selected category for filtering (null = show all)
// Uses category name for regular categories, category ID for featured
// ---------------------------------------------------------------------------
final selfOrderSelectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Whether the currently selected category is a featured category
final _selfOrderSelectedIsFeaturedProvider = Provider<bool>((ref) {
  final selected = ref.watch(selfOrderSelectedCategoryProvider);
  if (selected == null) return false;
  final categories = ref.watch(selfOrderCategoriesProvider).valueOrNull ?? [];
  return categories.any((c) => c['name'] == selected && c['is_featured'] == true);
});

/// The ID of the currently selected featured category (or null)
final _selfOrderSelectedFeaturedIdProvider = Provider<String?>((ref) {
  final selected = ref.watch(selfOrderSelectedCategoryProvider);
  final isFeatured = ref.watch(_selfOrderSelectedIsFeaturedProvider);
  if (!isFeatured || selected == null) return null;
  final categories = ref.watch(selfOrderCategoriesProvider).valueOrNull ?? [];
  final match = categories.where((c) => c['name'] == selected).toList();
  return match.isNotEmpty ? match.first['id'] as String? : null;
});

// ---------------------------------------------------------------------------
// Filtered products based on selected category
// ---------------------------------------------------------------------------
final selfOrderFilteredProductsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final menuAsync = ref.watch(selfOrderMenuProvider);
  final selectedCategory = ref.watch(selfOrderSelectedCategoryProvider);
  final isFeatured = ref.watch(_selfOrderSelectedIsFeaturedProvider);
  final featuredId = ref.watch(_selfOrderSelectedFeaturedIdProvider);

  return menuAsync.whenData((grouped) {
    if (selectedCategory == null) {
      return grouped.values.expand((list) => list).toList();
    }

    if (isFeatured && featuredId != null) {
      // Filter by junction table: products tagged with this featured category
      final allProducts = grouped.values.expand((list) => list).toList();
      return allProducts.where((p) {
        final pfc = p['product_featured_categories'];
        if (pfc is! List) return false;
        return pfc.any((tag) => tag['featured_category_id'] == featuredId);
      }).toList();
    }

    return grouped[selectedCategory] ?? [];
  });
});

// ---------------------------------------------------------------------------
// Cart state notifier
// ---------------------------------------------------------------------------
class SelfOrderCartNotifier extends StateNotifier<List<SelfOrderItem>> {
  SelfOrderCartNotifier() : super([]);

  /// Add item to cart. If an item with the same cartKey exists, increment qty.
  void addItem(SelfOrderItem item) {
    final existingIndex =
        state.indexWhere((i) => i.cartKey == item.cartKey);

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final updated = existing.copyWith(quantity: existing.quantity + item.quantity);
      final newState = [...state];
      newState[existingIndex] = updated;
      state = newState;
    } else {
      state = [...state, item];
    }
  }

  /// Remove item by cartKey
  void removeItem(String cartKey) {
    state = state.where((i) => i.cartKey != cartKey).toList();
  }

  /// Update quantity for item by cartKey. Removes if qty <= 0.
  void updateQuantity(String cartKey, int qty) {
    if (qty <= 0) {
      removeItem(cartKey);
      return;
    }
    state = state.map((i) {
      if (i.cartKey == cartKey) {
        return i.copyWith(quantity: qty);
      }
      return i;
    }).toList();
  }

  /// Clear all items from cart
  void clearCart() {
    state = [];
  }

  /// Total monetary amount of all items in cart
  double get totalAmount {
    return state.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Total number of individual items (sum of quantities)
  int get totalItems {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }
}

final selfOrderCartProvider =
    StateNotifierProvider<SelfOrderCartNotifier, List<SelfOrderItem>>(
  (ref) => SelfOrderCartNotifier(),
);

// ---------------------------------------------------------------------------
// Convenience providers for cart totals (reactive)
// ---------------------------------------------------------------------------
final selfOrderCartTotalProvider = Provider<double>((ref) {
  final items = ref.watch(selfOrderCartProvider);
  return items.fold(0.0, (sum, item) => sum + item.totalPrice);
});

final selfOrderCartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(selfOrderCartProvider);
  return items.fold(0, (sum, item) => sum + item.quantity);
});

// ---------------------------------------------------------------------------
// Table info provider (by tableId)
// ---------------------------------------------------------------------------
final selfOrderTableInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, tableId) async {
  final repo = ref.watch(selfOrderRepositoryProvider);
  return repo.getTableInfo(tableId);
});

// ---------------------------------------------------------------------------
// Order tracking provider (by orderId) — auto-refreshes every 10 seconds
// ---------------------------------------------------------------------------
final selfOrderTrackingProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, orderId) async {
  final repo = ref.watch(selfOrderRepositoryProvider);
  final result = await repo.getOrderStatus(orderId);

  // Auto-refresh: invalidate self after 10 seconds so status updates
  // are picked up without manual pull-to-refresh.
  final timer = Timer(const Duration(seconds: 10), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return result;
});

// ---------------------------------------------------------------------------
// Table orders provider (active orders for a specific table)
// ---------------------------------------------------------------------------
final selfOrderTableOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, tableId) async {
  final repo = ref.watch(selfOrderRepositoryProvider);
  return repo.getTableOrders(tableId);
});

// ---------------------------------------------------------------------------
// Modifier groups provider (by productId, for self-order modifier selection)
// ---------------------------------------------------------------------------
final selfOrderModifierGroupsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, productId) async {
  final repo = ref.watch(selfOrderRepositoryProvider);
  return repo.getModifierGroups(productId);
});
