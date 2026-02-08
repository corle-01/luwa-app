import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/purchase_order_repository.dart';

final purchaseOrderRepositoryProvider =
    Provider((ref) => PurchaseOrderRepository());

final purchaseOrderListProvider =
    FutureProvider<List<PurchaseOrderModel>>((ref) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getPurchaseOrders(outletId);
});

final purchaseOrderDetailProvider =
    FutureProvider.family<PurchaseOrderModel, String>((ref, poId) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  return repo.getPurchaseOrder(poId);
});
