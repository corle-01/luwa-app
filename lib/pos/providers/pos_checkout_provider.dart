import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/order.dart';
import '../../core/providers/outlet_provider.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/kitchen_print_service.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/utils/date_utils.dart';
import '../repositories/pos_order_repository.dart';

import 'pos_cart_provider.dart';
import 'pos_shift_provider.dart';
import 'pos_product_provider.dart';
import 'pos_table_provider.dart';
const _uuid = Uuid();

final posOrderRepositoryProvider = Provider((ref) => PosOrderRepository());

class CheckoutResult {
  final bool success;
  final String? orderId;
  final Order? order;
  final List<OrderItem>? items;
  final String? error;
  final bool isOffline;
  CheckoutResult({
    required this.success,
    this.orderId,
    this.order,
    this.items,
    this.error,
    this.isOffline = false,
  });
}

class PosCheckoutNotifier extends StateNotifier<AsyncValue<CheckoutResult?>> {
  final Ref _ref;
  PosCheckoutNotifier(this._ref) : super(const AsyncData(null));

  String get _outletId => _ref.read(currentOutletIdProvider);

  Future<CheckoutResult> processCheckout({
    required String paymentMethod,
    double? amountPaid,
    double? changeAmount,
    List<Map<String, dynamic>>? paymentDetails,
    String? orderSource,
  }) async {
    state = const AsyncLoading();

    try {
      final cart = _ref.read(posCartProvider);
      if (cart.isEmpty) return CheckoutResult(success: false, error: 'Keranjang kosong');

      final shift = _ref.read(posShiftNotifierProvider);
      final shiftData = shift.value;
      if (shiftData == null) return CheckoutResult(success: false, error: 'Shift belum dibuka');

      final isPlatformOrder = orderSource != null &&
          (orderSource == 'gofood' || orderSource == 'grabfood' || orderSource == 'shopeefood');

      // All orders (POS + online) use real selling prices.
      // For online orders, amountPaid = amount received from platform.
      // Difference (total - amountPaid) = platform commission/fee.
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

      // ---------------------------------------------------------------
      // Check connectivity — if offline, queue the order locally
      // ---------------------------------------------------------------
      final connectivity = _ref.read(connectivityServiceProvider);
      final isOnline = connectivity.isOnline;

      if (!isOnline) {
        return _processOfflineCheckout(
          cart: cart,
          shiftData: shiftData,
          paymentMethod: paymentMethod,
          amountPaid: amountPaid ?? cart.total,
          changeAmount: changeAmount ?? 0,
          items: items,
          paymentDetails: paymentDetails,
        );
      }

      // ---------------------------------------------------------------
      // ONLINE path — existing flow, completely unchanged
      // ---------------------------------------------------------------
      final repo = _ref.read(posOrderRepositoryProvider);
      final order = await repo.createOrder(
        outletId: _outletId,
        shiftId: shiftData.id,
        cashierId: shiftData.cashierId,
        orderType: isPlatformOrder ? 'online' : cart.orderType,
        paymentMethod: paymentMethod,
        subtotal: cart.subtotal,
        discountAmount: cart.discountAmount,
        taxAmount: cart.taxAmount,
        serviceChargeAmount: cart.serviceChargeAmount,
        totalAmount: cart.total,
        items: items,
        amountPaid: amountPaid ?? cart.total,
        changeAmount: isPlatformOrder ? 0 : (changeAmount ?? 0),
        discountId: cart.discount?.id,
        customerId: cart.customer?.id,
        tableId: cart.tableId,
        notes: isPlatformOrder
            ? '${orderSource!.toUpperCase()} Order${cart.notes != null ? ' - ${cart.notes}' : ''}'
            : cart.notes,
        paymentDetails: paymentDetails,
        orderSource: orderSource,
      );

      // If this is a platform order, also create a record in online_orders
      // so it appears in the Back Office "Online" management page.
      if (isPlatformOrder) {
        try {
          final onlineItems = cart.items.map((item) => {
            'name': item.product.name,
            'product_id': item.product.id,
            'price': item.unitPrice,
            'quantity': item.quantity,
          }).toList();

          await Supabase.instance.client.from('online_orders').insert({
            'outlet_id': _outletId,
            'order_id': order.id,
            'platform': orderSource,
            'platform_order_id': '${orderSource!.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}',
            'platform_order_number': order.orderNumber,
            'status': 'delivered',
            'subtotal': cart.subtotal,
            'total': cart.total,
            'delivery_fee': 0,
            'platform_fee': cart.total - (amountPaid ?? cart.total) > 0
                ? cart.total - (amountPaid ?? cart.total)
                : 0,
            'items': onlineItems,
            'notes': cart.notes,
            'accepted_at': DateTimeUtils.nowUtc(),
            'delivered_at': DateTimeUtils.nowUtc(),
          });
        } catch (e) {
          debugPrint('Failed to create online_orders record: $e');
        }
      }

      if (cart.orderType == 'dine_in' && cart.tableId != null) {
        try {
          final tableRepo = _ref.read(posTableRepositoryProvider);
          await tableRepo.updateTableStatus(cart.tableId!, 'occupied');
          _ref.invalidate(posTablesProvider);
        } catch (_) {}
      }

      // Fetch inserted items so we can pass them for receipt printing
      List<OrderItem> orderItems = [];
      try {
        orderItems = await repo.getOrderItems(order.id);
      } catch (_) {}

      // Kitchen auto-print — fire and forget
      try {
        final kitchenService = _ref.read(kitchenPrintServiceProvider);
        kitchenService.autoPrintIfEnabled(
          orderNumber: order.orderNumber ?? order.id.substring(0, 8),
          orderType: cart.orderType,
          dateTime: order.createdAt,
          items: orderItems,
          tableName: cart.tableNumber,
          cashierName: order.cashierName,
          notes: cart.notes,
        );
      } catch (_) {}

      _ref.read(posCartProvider.notifier).clear();
      _ref.invalidate(posStockAvailabilityProvider);
      _ref.invalidate(posProductsProvider);
      _ref.invalidate(posTodayOrdersProvider);

      final result = CheckoutResult(success: true, orderId: order.id, order: order, items: orderItems);
      state = AsyncData(result);
      return result;
    } catch (e) {
      // ---------------------------------------------------------------
      // If a network error occurs during the online path, fall back to
      // offline queue so the cashier is not blocked.
      // ---------------------------------------------------------------
      final connectivity = _ref.read(connectivityServiceProvider);
      connectivity.setOffline();

      try {
        final cart = _ref.read(posCartProvider);
        final shift = _ref.read(posShiftNotifierProvider);
        final shiftData = shift.value;
        if (shiftData != null && !cart.isEmpty) {
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

          return _processOfflineCheckout(
            cart: cart,
            shiftData: shiftData,
            paymentMethod: paymentMethod,
            amountPaid: amountPaid ?? cart.total,
            changeAmount: changeAmount ?? 0,
            items: items,
            paymentDetails: paymentDetails,
          );
        }
      } catch (_) {
        // If offline fallback also fails, return original error
      }

      final result = CheckoutResult(success: false, error: e.toString());
      state = AsyncData(result);
      return result;
    }
  }

  // -----------------------------------------------------------------------
  // Offline checkout — queues order locally, returns a synthetic Order
  // -----------------------------------------------------------------------
  CheckoutResult _processOfflineCheckout({
    required dynamic cart,
    required dynamic shiftData,
    required String paymentMethod,
    required double amountPaid,
    required double changeAmount,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>>? paymentDetails,
  }) {
    final localOrderId = _uuid.v4();
    final now = DateTime.now();
    final localOrderNumber = 'OFF-${now.millisecondsSinceEpoch}';

    // Build the order data payload (same shape as what _syncCreateOrder expects)
    final orderData = <String, dynamic>{
      'id': localOrderId,
      'outlet_id': _outletId,
      'order_number': localOrderNumber,
      'shift_id': shiftData.id,
      'cashier_id': shiftData.cashierId,
      'customer_id': cart.customer?.id,
      'order_type': cart.orderType,
      'table_id': cart.tableId,
      'status': 'pending',
      'payment_method': paymentMethod,
      'payment_status': 'unpaid',
      'subtotal': cart.subtotal,
      'discount_amount': cart.discountAmount,
      'discount_id': cart.discount?.id,
      'tax_amount': cart.taxAmount,
      'service_charge_amount': cart.serviceChargeAmount,
      'total': cart.total,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'payment_details': paymentDetails,
      'notes': cart.notes,
      'created_at': now.toUtc().toIso8601String(),
    };

    // Build item data list (without order_id — will be set during sync)
    final itemsData = items.map((item) => Map<String, dynamic>.from(item)).toList();

    // Enqueue the operation for later sync
    final queue = _ref.read(offlineQueueProvider.notifier);
    queue.enqueue(QueuedOperation(
      id: localOrderId,
      type: QueueOperationType.createOrder,
      data: {
        'order': orderData,
        'items': itemsData,
      },
      createdAt: now,
    ));

    // Build a synthetic Order object so the UI can show success
    final offlineOrder = Order(
      id: localOrderId,
      orderNumber: localOrderNumber,
      outletId: _outletId,
      shiftId: shiftData.id as String,
      cashierId: shiftData.cashierId as String,
      cashierName: shiftData.cashierName as String?,
      customerId: cart.customer?.id,
      orderType: cart.orderType,
      tableId: cart.tableId,
      status: 'pending_sync',
      paymentMethod: paymentMethod,
      paymentStatus: 'paid',
      subtotal: cart.subtotal,
      discountAmount: cart.discountAmount,
      taxAmount: cart.taxAmount,
      serviceCharge: cart.serviceChargeAmount,
      totalAmount: cart.total,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      paymentDetails: paymentDetails,
      notes: cart.notes,
      createdAt: now,
    );

    // Build synthetic OrderItem objects for receipt display
    final offlineItems = items.asMap().entries.map((entry) {
      final item = entry.value;
      return OrderItem(
        id: _uuid.v4(),
        orderId: localOrderId,
        productId: item['product_id'] as String,
        productName: item['product_name'] as String,
        quantity: item['quantity'] as int,
        unitPrice: (item['unit_price'] as num).toDouble(),
        totalPrice: (item['total'] as num).toDouble(),
        notes: item['notes'] as String?,
        modifiers: item['modifiers'] != null
            ? List<Map<String, dynamic>>.from(item['modifiers'] as List)
            : null,
      );
    }).toList();

    // Clear the cart — the cashier is done
    _ref.read(posCartProvider.notifier).clear();

    final result = CheckoutResult(
      success: true,
      orderId: localOrderId,
      order: offlineOrder,
      items: offlineItems,
      isOffline: true,
    );
    state = AsyncData(result);
    return result;
  }
}

final posCheckoutProvider = StateNotifierProvider<PosCheckoutNotifier, AsyncValue<CheckoutResult?>>(
  (ref) => PosCheckoutNotifier(ref),
);

final posTodayOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(posOrderRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTodayOrders(outletId);
});
