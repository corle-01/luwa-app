import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/purchase_order_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final purchaseOrderRepositoryProvider =
    Provider((ref) => PurchaseOrderRepository());

final purchaseOrderListProvider =
    FutureProvider<List<PurchaseOrderModel>>((ref) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  return repo.getPurchaseOrders(_outletId);
});

final purchaseOrderDetailProvider =
    FutureProvider.family<PurchaseOrderModel, String>((ref, poId) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  return repo.getPurchaseOrder(poId);
});
