import 'discount.dart';
import 'product.dart';

class CartItem {
  final String id;
  final Product product;
  final int quantity;
  final List<SelectedModifier> selectedModifiers;
  final String? notes;

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.selectedModifiers = const [],
    this.notes,
  });

  double get unitPrice {
    double base = product.sellingPrice;
    for (final mod in selectedModifiers) {
      base += mod.priceAdjustment;
    }
    return base;
  }

  double get itemTotal => unitPrice * quantity;

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    List<SelectedModifier>? selectedModifiers,
    String? notes,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      notes: notes ?? this.notes,
    );
  }
}

class SelectedModifier {
  final String groupName;
  final String optionName;
  final double priceAdjustment;

  SelectedModifier({
    required this.groupName,
    required this.optionName,
    this.priceAdjustment = 0,
  });
}

class CartState {
  final List<CartItem> items;
  final String orderType;
  final String? tableId;
  final String? tableNumber;
  final CartDiscount? discount;
  final CartCustomer? customer;
  final String? notes;
  final List<Tax> taxes;

  CartState({
    this.items = const [],
    this.orderType = 'dine_in',
    this.tableId,
    this.tableNumber,
    this.discount,
    this.customer,
    this.notes,
    this.taxes = const [],
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.itemTotal);

  double get discountAmount {
    if (discount == null) return 0;
    if (discount!.type == 'percentage') {
      return subtotal * (discount!.value / 100);
    }
    return discount!.value > subtotal ? subtotal : discount!.value;
  }

  double get afterDiscount => subtotal - discountAmount;

  double get taxAmount {
    double total = 0;
    for (final tax in taxes) {
      if (tax.type == 'tax' && !tax.isInclusive) {
        total += afterDiscount * (tax.rate / 100);
      }
    }
    return total;
  }

  double get serviceChargeAmount {
    double total = 0;
    for (final tax in taxes) {
      if (tax.type == 'service_charge' && !tax.isInclusive) {
        total += afterDiscount * (tax.rate / 100);
      }
    }
    return total;
  }

  double get total => afterDiscount + taxAmount + serviceChargeAmount;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? orderType,
    String? tableId,
    String? tableNumber,
    CartDiscount? discount,
    CartCustomer? customer,
    String? notes,
    List<Tax>? taxes,
    bool clearDiscount = false,
    bool clearCustomer = false,
    bool clearTable = false,
  }) {
    return CartState(
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      tableId: clearTable ? null : (tableId ?? this.tableId),
      tableNumber: clearTable ? null : (tableNumber ?? this.tableNumber),
      discount: clearDiscount ? null : (discount ?? this.discount),
      customer: clearCustomer ? null : (customer ?? this.customer),
      notes: notes ?? this.notes,
      taxes: taxes ?? this.taxes,
    );
  }
}

class CartDiscount {
  final String id;
  final String name;
  final String type;
  final double value;

  CartDiscount({required this.id, required this.name, required this.type, required this.value});
}

class CartCustomer {
  final String id;
  final String name;
  final String? phone;

  CartCustomer({required this.id, required this.name, this.phone});
}
