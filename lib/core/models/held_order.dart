import 'cart.dart';

class HeldOrder {
  final String id;
  final CartState cartState;
  final DateTime heldAt;
  final String? label;

  HeldOrder({
    required this.id,
    required this.cartState,
    required this.heldAt,
    this.label,
  });

  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    if (cartState.customer != null) return cartState.customer!.name;
    if (cartState.tableNumber != null) return 'Meja ${cartState.tableNumber}';
    return 'Pesanan ${id.substring(0, 6)}';
  }
}
