import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order.dart';
import '../repositories/pos_order_repository.dart';

import 'pos_cart_provider.dart';
import 'pos_shift_provider.dart';
import 'pos_product_provider.dart';
import 'pos_table_provider.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final posOrderRepositoryProvider = Provider((ref) => PosOrderRepository());

class CheckoutResult {
  final bool success;
  final String? orderId;
  final String? error;
  CheckoutResult({required this.success, this.orderId, this.error});
}

class PosCheckoutNotifier extends StateNotifier<AsyncValue<CheckoutResult?>> {
  final Ref _ref;
  PosCheckoutNotifier(this._ref) : super(const AsyncData(null));

  Future<CheckoutResult> processCheckout({
    required String paymentMethod,
    double? amountPaid,
    double? changeAmount,
  }) async {
    state = const AsyncLoading();

    try {
      final cart = _ref.read(posCartProvider);
      if (cart.isEmpty) return CheckoutResult(success: false, error: 'Keranjang kosong');

      final shift = _ref.read(posShiftNotifierProvider);
      final shiftData = shift.value;
      if (shiftData == null) return CheckoutResult(success: false, error: 'Shift belum dibuka');

      final items = cart.items.map((item) => {
        'product_id': item.product.id,
        'product_name': item.product.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'subtotal': item.itemTotal,
        'total': item.itemTotal,
        'notes': item.notes,
        'modifiers': item.selectedModifiers.map((m) => {
          'group_name': m.groupName,
          'option_name': m.optionName,
          'price_adjustment': m.priceAdjustment,
        }).toList(),
      }).toList();

      final repo = _ref.read(posOrderRepositoryProvider);
      final order = await repo.createOrder(
        outletId: _outletId,
        shiftId: shiftData.id,
        cashierId: shiftData.cashierId,
        orderType: cart.orderType,
        paymentMethod: paymentMethod,
        subtotal: cart.subtotal,
        discountAmount: cart.discountAmount,
        taxAmount: cart.taxAmount,
        serviceChargeAmount: cart.serviceChargeAmount,
        totalAmount: cart.total,
        items: items,
        amountPaid: amountPaid ?? cart.total,
        changeAmount: changeAmount ?? 0,
        discountId: cart.discount?.id,
        customerId: cart.customer?.id,
        tableId: cart.tableId,
      );

      if (cart.orderType == 'dine_in' && cart.tableId != null) {
        try {
          final tableRepo = _ref.read(posTableRepositoryProvider);
          await tableRepo.updateTableStatus(cart.tableId!, 'occupied');
          _ref.invalidate(posTablesProvider);
        } catch (_) {}
      }

      _ref.read(posCartProvider.notifier).clear();
      _ref.invalidate(posStockAvailabilityProvider);
      _ref.invalidate(posProductsProvider);
      _ref.invalidate(posTodayOrdersProvider);

      final result = CheckoutResult(success: true, orderId: order.id);
      state = AsyncData(result);
      return result;
    } catch (e) {
      final result = CheckoutResult(success: false, error: e.toString());
      state = AsyncData(result);
      return result;
    }
  }
}

final posCheckoutProvider = StateNotifierProvider<PosCheckoutNotifier, AsyncValue<CheckoutResult?>>(
  (ref) => PosCheckoutNotifier(ref),
);

final posTodayOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(posOrderRepositoryProvider);
  return repo.getTodayOrders(_outletId);
});
