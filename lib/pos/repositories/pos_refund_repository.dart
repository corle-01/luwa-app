import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/date_utils.dart';

class PosRefundRepository {
  final _supabase = Supabase.instance.client;

  /// Void an order - cancels entirely, restores stock via DB trigger
  Future<void> voidOrder({
    required String orderId,
    required String reason,
    required String voidedBy,
  }) async {
    await _supabase.from('orders').update({
      'status': 'voided',
      'void_reason': reason,
      'voided_at': DateTimeUtils.nowUtc(),
      'voided_by': voidedBy,
      'updated_at': DateTimeUtils.nowUtc(),
    }).eq('id', orderId);
  }

  /// Refund an order - marks as refunded with amount, restores stock via DB trigger
  Future<void> refundOrder({
    required String orderId,
    required double refundAmount,
    required String reason,
  }) async {
    await _supabase.from('orders').update({
      'status': 'refunded',
      'refund_amount': refundAmount,
      'refund_reason': reason,
      'updated_at': DateTimeUtils.nowUtc(),
    }).eq('id', orderId);
  }
}
