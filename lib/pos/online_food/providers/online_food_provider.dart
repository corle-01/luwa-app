import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/outlet_provider.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum OnlinePlatform { gofood, grabfood, shopeefood }

extension OnlinePlatformX on OnlinePlatform {
  String get label {
    switch (this) {
      case OnlinePlatform.gofood:
        return 'GoFood';
      case OnlinePlatform.grabfood:
        return 'GrabFood';
      case OnlinePlatform.shopeefood:
        return 'ShopeeFood';
    }
  }

  /// Value stored in the `order_source` DB column.
  String get sourceName {
    switch (this) {
      case OnlinePlatform.gofood:
        return 'gofood';
      case OnlinePlatform.grabfood:
        return 'grabfood';
      case OnlinePlatform.shopeefood:
        return 'shopeefood';
    }
  }

  /// Prefix used when generating the order number (e.g. GF-001).
  String get orderPrefix {
    switch (this) {
      case OnlinePlatform.gofood:
        return 'GF';
      case OnlinePlatform.grabfood:
        return 'GB';
      case OnlinePlatform.shopeefood:
        return 'SF';
    }
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class OnlineFoodItem {
  final String productId;
  final String productName;
  final String? variantName;
  final int quantity;

  const OnlineFoodItem({
    required this.productId,
    required this.productName,
    this.variantName,
    this.quantity = 1,
  });

  /// Unique key for deduplication inside the cart.
  /// Items with the same product + variant are treated as the same line.
  String get cartKey => '$productId::${variantName ?? ''}';

  OnlineFoodItem copyWith({
    String? productId,
    String? productName,
    String? variantName,
    int? quantity,
  }) {
    return OnlineFoodItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantName: variantName ?? this.variantName,
      quantity: quantity ?? this.quantity,
    );
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class OnlineFoodState {
  final OnlinePlatform? selectedPlatform;
  final String platformOrderId;
  final String platformNotes;
  final List<OnlineFoodItem> items;
  final double? finalAmount;
  final bool isSubmitting;
  final String? error;
  final bool isSuccess;

  const OnlineFoodState({
    this.selectedPlatform,
    this.platformOrderId = '',
    this.platformNotes = '',
    this.items = const [],
    this.finalAmount,
    this.isSubmitting = false,
    this.error,
    this.isSuccess = false,
  });

  bool get canSubmit =>
      selectedPlatform != null &&
      platformOrderId.isNotEmpty &&
      items.isNotEmpty &&
      finalAmount != null &&
      finalAmount! > 0 &&
      !isSubmitting;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  OnlineFoodState copyWith({
    OnlinePlatform? selectedPlatform,
    String? platformOrderId,
    String? platformNotes,
    List<OnlineFoodItem>? items,
    double? finalAmount,
    bool? isSubmitting,
    String? error,
    bool? isSuccess,
    bool clearPlatform = false,
    bool clearFinalAmount = false,
    bool clearError = false,
  }) {
    return OnlineFoodState(
      selectedPlatform:
          clearPlatform ? null : (selectedPlatform ?? this.selectedPlatform),
      platformOrderId: platformOrderId ?? this.platformOrderId,
      platformNotes: platformNotes ?? this.platformNotes,
      items: items ?? this.items,
      finalAmount:
          clearFinalAmount ? null : (finalAmount ?? this.finalAmount),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class OnlineFoodNotifier extends StateNotifier<OnlineFoodState> {
  final String outletId;
  OnlineFoodNotifier({required this.outletId}) : super(const OnlineFoodState());

  final _supabase = Supabase.instance.client;

  // -- Platform / meta fields ------------------------------------------------

  void selectPlatform(OnlinePlatform platform) {
    state = state.copyWith(selectedPlatform: platform, clearError: true);
  }

  void setPlatformOrderId(String id) {
    state = state.copyWith(platformOrderId: id, clearError: true);
  }

  void setPlatformNotes(String notes) {
    state = state.copyWith(platformNotes: notes);
  }

  void setFinalAmount(double? amount) {
    if (amount == null) {
      state = state.copyWith(clearFinalAmount: true, clearError: true);
    } else {
      state = state.copyWith(finalAmount: amount, clearError: true);
    }
  }

  // -- Item management -------------------------------------------------------

  void addItem(String productId, String productName, {String? variantName}) {
    final key = '$productId::${variantName ?? ''}';
    final existingIndex = state.items.indexWhere((i) => i.cartKey == key);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedItems = [...state.items];
      updatedItems[existingIndex] =
          existing.copyWith(quantity: existing.quantity + 1);
      state = state.copyWith(items: updatedItems, clearError: true);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          OnlineFoodItem(
            productId: productId,
            productName: productName,
            variantName: variantName,
          ),
        ],
        clearError: true,
      );
    }
  }

  void removeItem(String productId, {String? variantName}) {
    final key = '$productId::${variantName ?? ''}';
    final existingIndex = state.items.indexWhere((i) => i.cartKey == key);
    if (existingIndex < 0) return;

    final existing = state.items[existingIndex];
    if (existing.quantity > 1) {
      final updatedItems = [...state.items];
      updatedItems[existingIndex] =
          existing.copyWith(quantity: existing.quantity - 1);
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(
        items: state.items.where((i) => i.cartKey != key).toList(),
      );
    }
  }

  void updateQuantity(String productId, int qty, {String? variantName}) {
    if (qty <= 0) {
      clearItem(productId, variantName: variantName);
      return;
    }

    final key = '$productId::${variantName ?? ''}';
    final updatedItems = state.items.map((item) {
      if (item.cartKey == key) return item.copyWith(quantity: qty);
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void clearItem(String productId, {String? variantName}) {
    final key = '$productId::${variantName ?? ''}';
    state = state.copyWith(
      items: state.items.where((i) => i.cartKey != key).toList(),
    );
  }

  // -- Submit ----------------------------------------------------------------

  Future<void> submitOrder() async {
    if (!state.canSubmit) return;

    state = state.copyWith(isSubmitting: true, clearError: true, isSuccess: false);

    try {
      final platform = state.selectedPlatform!;

      // Generate order number with platform prefix (GF-xxx, GB-xxx, SF-xxx)
      final orderNumber =
          '${platform.orderPrefix}-${DateTime.now().millisecondsSinceEpoch}';

      // Step 1: INSERT order as 'pending'
      // DB triggers fire on UPDATE, not INSERT -- so we must insert first,
      // then update to 'completed' to trigger stock deduction, shift update,
      // and customer update.
      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'outlet_id': outletId,
            'order_number': orderNumber,
            'order_type': 'online',
            'order_source': platform.sourceName,
            'platform_order_id': state.platformOrderId.trim(),
            'platform_final_amount': state.finalAmount,
            'platform_notes':
                state.platformNotes.trim().isEmpty ? null : state.platformNotes.trim(),
            'status': 'pending',
            'payment_method': 'platform',
            'payment_status': 'unpaid',
            'subtotal': 0,
            'discount_amount': 0,
            'tax_amount': 0,
            'service_charge_amount': 0,
            'total': 0,
            'amount_paid': 0,
            'change_amount': 0,
            'notes': state.platformNotes.trim().isEmpty ? null : state.platformNotes.trim(),
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      // Step 2: Insert order items (prices are 0 for online food)
      final orderItems = state.items
          .map((item) => {
                'order_id': orderId,
                'product_id': item.productId,
                'product_name': item.variantName != null && item.variantName!.isNotEmpty
                    ? '${item.productName} (${item.variantName})'
                    : item.productName,
                'quantity': item.quantity,
                'unit_price': 0,
                'subtotal': 0,
                'total': 0,
              })
          .toList();

      await _supabase.from('order_items').insert(orderItems);

      // Step 3: UPDATE to 'completed' -- triggers fire on this transition
      await _supabase.from('orders').update({
        'status': 'completed',
        'payment_status': 'paid',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Success -- reset the form
      state = const OnlineFoodState(isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
        isSuccess: false,
      );
    }
  }

  // -- Reset -----------------------------------------------------------------

  void reset() {
    state = const OnlineFoodState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final onlineFoodProvider =
    StateNotifierProvider<OnlineFoodNotifier, OnlineFoodState>(
  (ref) => OnlineFoodNotifier(outletId: ref.watch(currentOutletIdProvider)),
);
