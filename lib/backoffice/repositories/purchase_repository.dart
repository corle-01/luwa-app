import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/purchase.dart';
import '../../core/utils/date_utils.dart';

class PurchaseRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Purchase>> getPurchases(
    String outletId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _supabase
        .from('purchases')
        .select()
        .eq('outlet_id', outletId);

    if (from != null) {
      query = query.gte('purchase_date', DateTimeUtils.toDateOnly(from));
    }
    if (to != null) {
      query = query.lte('purchase_date', DateTimeUtils.toDateOnly(to));
    }

    final response = await query.order('purchase_date', ascending: false);

    final purchases = (response as List)
        .map((json) => Purchase.fromJson(json))
        .toList();

    if (purchases.isEmpty) return purchases;

    // Batch-query all items for the fetched purchase IDs
    final purchaseIds = purchases.map((p) => p.id).toList();
    final itemsResponse = await _supabase
        .from('purchase_items')
        .select()
        .inFilter('purchase_id', purchaseIds);

    final itemsByPurchaseId = <String, List<PurchaseItem>>{};
    for (final json in itemsResponse as List) {
      final item = PurchaseItem.fromJson(json);
      itemsByPurchaseId.putIfAbsent(item.purchaseId, () => []).add(item);
    }

    // Rebuild purchases with their items
    return purchases.map((p) {
      final items = itemsByPurchaseId[p.id] ?? [];
      return Purchase.fromJson(
        {
          'id': p.id,
          'outlet_id': p.outletId,
          'supplier_id': p.supplierId,
          'supplier_name': p.supplierName,
          'pic_name': p.picName,
          'payment_source': p.paymentSource,
          'payment_detail': p.paymentDetail,
          'shift_id': p.shiftId,
          'receipt_image_url': p.receiptImageUrl,
          'total_amount': p.totalAmount,
          'notes': p.notes,
          'purchase_date': p.purchaseDate.toIso8601String(),
          'created_at': p.createdAt.toIso8601String(),
          'updated_at': p.updatedAt?.toIso8601String(),
        },
        items: items,
      );
    }).toList();
  }

  Future<Purchase> getPurchaseById(String id) async {
    final response = await _supabase
        .from('purchases')
        .select()
        .eq('id', id)
        .single();

    final itemsResponse = await _supabase
        .from('purchase_items')
        .select()
        .eq('purchase_id', id);

    final items = (itemsResponse as List)
        .map((json) => PurchaseItem.fromJson(json))
        .toList();

    return Purchase.fromJson(response, items: items);
  }

  Future<Purchase> createPurchase(
    Purchase purchase,
    List<PurchaseItem> items,
  ) async {
    // Insert purchase row
    final purchaseResponse = await _supabase
        .from('purchases')
        .insert(purchase.toInsertJson())
        .select()
        .single();

    final purchaseId = purchaseResponse['id'] as String;

    // Insert items
    if (items.isNotEmpty) {
      final itemInserts = items
          .map((item) => item.toInsertJson(purchaseId))
          .toList();
      await _supabase.from('purchase_items').insert(itemInserts);
    }

    // Return the created purchase with items
    return getPurchaseById(purchaseId);
  }

  Future<void> deletePurchase(String id) async {
    // Cascade deletes items automatically via FK constraint
    await _supabase
        .from('purchases')
        .delete()
        .eq('id', id);
  }

  Future<PurchaseStats> getPurchaseStats(
    String outletId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _supabase
        .from('purchases')
        .select('total_amount, payment_source')
        .eq('outlet_id', outletId)
        .gte('purchase_date', DateTimeUtils.toDateOnly(from))
        .lte('purchase_date', DateTimeUtils.toDateOnly(to));

    double totalAmount = 0;
    double kasKasirAmount = 0;
    double uangLuarAmount = 0;
    int totalTransactions = 0;

    for (final row in response as List) {
      final amount = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final source = row['payment_source'] as String? ?? 'kas_kasir';
      totalAmount += amount;
      totalTransactions++;
      if (source == 'kas_kasir') {
        kasKasirAmount += amount;
      } else {
        uangLuarAmount += amount;
      }
    }

    return PurchaseStats(
      totalAmount: totalAmount,
      kasKasirAmount: kasKasirAmount,
      uangLuarAmount: uangLuarAmount,
      totalTransactions: totalTransactions,
    );
  }

  Future<void> uploadReceiptImage(String purchaseId, String imageUrl) async {
    await _supabase
        .from('purchases')
        .update({
          'receipt_image_url': imageUrl,
          'updated_at': DateTimeUtils.nowUtc(),
        })
        .eq('id', purchaseId);
  }
}
