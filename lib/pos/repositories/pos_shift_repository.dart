import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/shift.dart';
import '../../core/utils/date_utils.dart';

class PosShiftRepository {
  final _supabase = Supabase.instance.client;

  Future<Shift?> getActiveShift(String outletId) async {
    final response = await _supabase
        .from('shifts')
        .select('*, profiles(full_name)')
        .eq('outlet_id', outletId)
        .eq('status', 'open')
        .order('opened_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return Shift.fromJson(response);
  }

  Future<Shift> openShift({
    required String outletId,
    required String cashierId,
    required double openingCash,
  }) async {
    try {
      await _supabase.rpc('open_shift', params: {
        'p_outlet_id': outletId,
        'p_cashier_id': cashierId,
        'p_opening_cash': openingCash,
      });
    } catch (_) {
      await _supabase
          .from('shifts')
          .insert({
            'outlet_id': outletId,
            'cashier_id': cashierId,
            'opening_cash': openingCash,
            'status': 'open',
            'opened_at': DateTimeUtils.nowUtc(),
          })
          .select()
          .single();
    }
    // Always re-fetch with profiles join so cashierName is populated
    return await getActiveShift(outletId) ?? (throw Exception('Failed to open shift'));
  }

  Future<void> closeShift({
    required String shiftId,
    required double closingCash,
    String? notes,
  }) async {
    try {
      await _supabase.rpc('close_shift', params: {
        'p_shift_id': shiftId,
        'p_closing_cash': closingCash,
        'p_notes': notes,
      });
    } catch (_) {
      await _supabase
          .from('shifts')
          .update({
            'closing_cash': closingCash,
            'status': 'closed',
            'closed_at': DateTimeUtils.nowUtc(),
            'notes': notes,
          })
          .eq('id', shiftId);
    }
  }

  Future<ShiftSummary> getShiftSummary(String shiftId) async {
    final orders = await _supabase
        .from('orders')
        .select()
        .eq('shift_id', shiftId);

    double totalSales = 0, totalCash = 0, totalNonCash = 0;
    final ordersByStatus = <String, int>{};
    final salesByPayment = <String, double>{};

    for (final order in orders as List) {
      final amount = (order['total'] as num?)?.toDouble() ?? 0;
      final status = order['status'] as String? ?? 'unknown';
      final payment = order['payment_method'] as String? ?? 'unknown';

      if (status == 'completed') {
        totalSales += amount;
        if (payment == 'split') {
          // For split payments, break down cash vs non-cash from payment_details
          final details = order['payment_details'] as List?;
          if (details != null) {
            for (final entry in details) {
              final method = entry['method'] as String? ?? '';
              final entryAmount = (entry['amount'] as num?)?.toDouble() ?? 0;
              if (method == 'cash') {
                totalCash += entryAmount;
              } else {
                totalNonCash += entryAmount;
              }
            }
          } else {
            totalNonCash += amount;
          }
        } else if (payment == 'cash') {
          totalCash += amount;
        } else {
          totalNonCash += amount;
        }
      }
      ordersByStatus[status] = (ordersByStatus[status] ?? 0) + 1;
      if (status == 'completed') {
        salesByPayment[payment] = (salesByPayment[payment] ?? 0) + amount;
      }
    }

    final shift = await _supabase.from('shifts').select().eq('id', shiftId).single();
    final openingCash = (shift['opening_cash'] as num?)?.toDouble() ?? 0;
    final closingCash = (shift['closing_cash'] as num?)?.toDouble();

    return ShiftSummary(
      totalSales: totalSales,
      totalOrders: (orders as List).length,
      totalCash: totalCash,
      totalNonCash: totalNonCash,
      expectedCash: openingCash + totalCash,
      actualCash: closingCash,
      difference: closingCash != null ? closingCash - (openingCash + totalCash) : null,
      ordersByStatus: ordersByStatus,
      salesByPayment: salesByPayment,
    );
  }
}
