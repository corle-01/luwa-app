import 'package:flutter/material.dart';
import '../../core/models/order.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import 'receipt_widget.dart';

class OrderSuccessDialog extends StatelessWidget {
  final Order order;
  final List<OrderItem> items;

  const OrderSuccessDialog({super.key, required this.order, required this.items});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Pesanan Berhasil!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              FormatUtils.currency(order.totalAmount),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            if (order.orderNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                order.orderNumber!,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ReceiptPrinter.printReceipt(order, items),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Cetak Struk'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
