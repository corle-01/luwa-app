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
            // Print receipt button — full width, prominent
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => ReceiptPrinter.printReceipt(order, items),
                icon: const Icon(Icons.print, size: 22),
                label: const Text('Cetak Struk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Struk akan dicetak melalui browser',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
