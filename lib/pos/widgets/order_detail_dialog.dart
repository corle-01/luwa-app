import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/order.dart';
import '../providers/pos_checkout_provider.dart';
import '../repositories/pos_order_repository.dart';
import 'receipt_widget.dart';
import 'void_dialog.dart';
import 'refund_dialog.dart';

class OrderDetailDialog extends ConsumerWidget {
  final Order order;
  const OrderDetailDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(posOrderRepositoryProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber ?? '#${order.id.substring(0, 8)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FormatUtils.dateTime(order.createdAt),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: order.status),
                const SizedBox(width: 4),
                _PrintButton(order: order, repo: repo),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            // Order info
            _DetailRow('Tipe', order.orderType == 'dine_in' ? 'Dine In' : 'Takeaway'),
            if (order.tableNumber != null)
              _DetailRow('Meja', '${order.tableNumber}'),
            _DetailRow('Pembayaran', order.paymentMethod.toUpperCase()),
            if (order.customerName != null)
              _DetailRow('Pelanggan', order.customerName!),
            const SizedBox(height: 12),

            // Items
            const Text('Item Pesanan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<OrderItem>>(
                future: repo.getOrderItems(order.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Tidak ada item', style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _OrderItemTile(item: items[i]),
                  );
                },
              ),
            ),
            const Divider(height: 24),

            // Totals
            _TotalRow('Subtotal', FormatUtils.currency(order.subtotal)),
            if (order.discountAmount > 0)
              _TotalRow('Diskon', '- ${FormatUtils.currency(order.discountAmount)}', valueColor: AppTheme.errorColor),
            if (order.taxAmount > 0)
              _TotalRow('Pajak', FormatUtils.currency(order.taxAmount)),
            if (order.serviceCharge > 0)
              _TotalRow('Service Charge', FormatUtils.currency(order.serviceCharge)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(FormatUtils.currency(order.totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),

            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Catatan: ${order.notes}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ),
            ],

            // Void & Refund buttons (only for completed orders)
            if (order.status == 'completed') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showVoidDialog(context, ref),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Void'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRefundDialog(context, ref),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Refund'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentColor,
                        side: const BorderSide(color: AppTheme.accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showVoidDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => VoidDialog(order: order),
    );
  }

  void _showRefundDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => RefundDialog(order: order),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (status) {
      case 'completed':
        color = AppTheme.successColor;
        label = 'Selesai';
        break;
      case 'cancelled':
        color = AppTheme.errorColor;
        label = 'Dibatalkan';
        break;
      case 'voided':
        color = AppTheme.errorColor;
        label = 'Dibatalkan (Void)';
        break;
      case 'refunded':
        color = AppTheme.accentColor;
        label = 'Refund';
        break;
      default:
        color = AppTheme.accentColor;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItem item;
  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Text('x${item.quantity}', style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(width: 12),
              Text(FormatUtils.currency(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          // Modifiers
          if (item.modifiers != null && item.modifiers!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.modifiers!.map((mod) {
                  final name = mod['option_name'] ?? mod['name'] ?? '';
                  final price = (mod['price_adjustment'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      price > 0 ? '+ $name (+${FormatUtils.currency(price)})' : '+ $name',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Notes
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 12),
              child: Text('Note: ${item.notes}', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

class _PrintButton extends StatelessWidget {
  final Order order;
  final PosOrderRepository repo;
  const _PrintButton({required this.order, required this.repo});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.receipt_long, size: 20),
      tooltip: 'Cetak Struk',
      onPressed: () async {
        final items = await repo.getOrderItems(order.id);
        ReceiptPrinter.printReceipt(order, items);
      },
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _TotalRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}
