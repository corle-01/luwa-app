import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/held_order.dart';
import '../../core/models/cart.dart';

class PosHeldOrdersNotifier extends StateNotifier<List<HeldOrder>> {
  PosHeldOrdersNotifier() : super([]);
  static const _uuid = Uuid();

  /// Hold current cart state
  void holdOrder(CartState cartState, {String? label}) {
    if (cartState.isEmpty) return;
    final held = HeldOrder(
      id: _uuid.v4(),
      cartState: cartState,
      heldAt: DateTime.now(),
      label: label,
    );
    state = [...state, held];
  }

  /// Recall a held order (remove from held list, return the cart state)
  CartState? recallOrder(String id) {
    final order = state.firstWhere(
      (o) => o.id == id,
      orElse: () => throw Exception('Held order not found'),
    );
    state = state.where((o) => o.id != id).toList();
    return order.cartState;
  }

  /// Delete a held order without recalling
  void deleteHeldOrder(String id) {
    state = state.where((o) => o.id != id).toList();
  }

  int get count => state.length;
}

final posHeldOrdersProvider =
    StateNotifierProvider<PosHeldOrdersNotifier, List<HeldOrder>>(
  (ref) => PosHeldOrdersNotifier(),
);
