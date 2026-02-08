import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/cart.dart';
import '../../core/models/discount.dart';
import '../../core/models/product.dart';
import 'pos_automation_provider.dart';

class PosCartNotifier extends StateNotifier<CartState> {
  final Ref _ref;
  static const _uuid = Uuid();

  PosCartNotifier(this._ref) : super(CartState(items: [], orderType: 'dine_in'));

  void addItem(Product product, {List<SelectedModifier> modifiers = const [], String? notes}) {
    final isAuto = _ref.read(posAutomationProvider);

    if (isAuto && product.calculatedAvailableQty != null) {
      final currentInCart = state.items
          .where((item) => item.product.id == product.id)
          .fold(0, (sum, item) => sum + item.quantity);
      if (currentInCart >= product.calculatedAvailableQty!) return;
    }

    final existingIndex = state.items.indexWhere((item) =>
        item.product.id == product.id &&
        _modifiersMatch(item.selectedModifiers, modifiers) &&
        item.notes == notes);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedItems = [...state.items];
      updatedItems[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(id: _uuid.v4(), product: product, quantity: 1, selectedModifiers: modifiers, notes: notes),
      ]);
    }
  }

  bool _modifiersMatch(List<SelectedModifier> a, List<SelectedModifier> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].optionName != b[i].optionName) return false;
    }
    return true;
  }

  void updateQuantity(String cartItemId, int qty) {
    if (qty <= 0) { removeItem(cartItemId); return; }
    final item = state.items.firstWhere((i) => i.id == cartItemId);
    final isAuto = _ref.read(posAutomationProvider);
    if (isAuto && item.product.calculatedAvailableQty != null) {
      if (qty > item.product.calculatedAvailableQty!) return;
    }
    state = state.copyWith(
      items: state.items.map((i) => i.id == cartItemId ? i.copyWith(quantity: qty) : i).toList(),
    );
  }

  void removeItem(String cartItemId) {
    state = state.copyWith(items: state.items.where((i) => i.id != cartItemId).toList());
  }

  void setOrderType(String type) => state = state.copyWith(orderType: type);
  void setTable(String? id, String? number) => state = state.copyWith(tableId: id, tableNumber: number);
  void setDiscount(CartDiscount? discount) => state = discount == null
      ? state.copyWith(clearDiscount: true)
      : state.copyWith(discount: discount);
  void setCustomer(CartCustomer? customer) => state = customer == null
      ? state.copyWith(clearCustomer: true)
      : state.copyWith(customer: customer);
  void setTaxes(List<Tax> taxes) => state = state.copyWith(taxes: taxes);
  void restoreState(CartState cartState) => state = cartState;
  void clear() => state = CartState(items: [], orderType: 'dine_in');
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, CartState>(
  (ref) => PosCartNotifier(ref),
);
