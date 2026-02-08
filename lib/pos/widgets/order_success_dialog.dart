import 'package:flutter/material.dart';
import '../../core/models/order.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import 'receipt_widget.dart';

class OrderSuccessDialog extends StatelessWidget {
  final Order order;
  final List<OrderItem> items;
  final bool isOffline;

  const OrderSuccessDialog({
    super.key,
    required this.order,
    required this.items,
    this.isOffline = false,
  });

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
              decoration: BoxDecoration(
                color: isOffline
                    ? const Color(0xFFF59E0B) // amber/warning
                    : AppTheme.successColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline ? Icons.cloud_off_rounded : Icons.check,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOffline ? 'Pesanan Tersimpan (Offline)' : 'Pesanan Berhasil!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (isOffline) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Pesanan akan otomatis disinkronkan saat koneksi pulih.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
