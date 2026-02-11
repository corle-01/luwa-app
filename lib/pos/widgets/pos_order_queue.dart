import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/order.dart';
import '../../core/services/kitchen_print_service.dart';
import '../providers/pos_queue_provider.dart';
import '../providers/pos_checkout_provider.dart';
import 'order_detail_dialog.dart';
import 'receipt_widget.dart';

class PosOrderQueue extends ConsumerStatefulWidget {
  const PosOrderQueue({super.key});

  @override
  ConsumerState<PosOrderQueue> createState() => _PosOrderQueueState();
}

class _PosOrderQueueState extends ConsumerState<PosOrderQueue> {
  String _selectedStatus = 'all'; // 'all', 'pending', 'completed'

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(posTodayOrdersProvider);

    return Column(
      children: [
        // Header with status tabs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(color: AppTheme.dividerColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Antrian Pesanan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => ref.invalidate(posTodayOrdersProvider),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Status filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusChip(
                      label: 'Semua',
                      count: allOrders.when(data: (o) => o.length, loading: () => 0, error: (_, __) => 0),
                      isSelected: _selectedStatus == 'all',
                      onTap: () => setState(() => _selectedStatus = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'Pending',
                      count: ref.watch(posPendingOrderCountProvider),
                      isSelected: _selectedStatus == 'pending',
                      onTap: () => setState(() => _selectedStatus = 'pending'),
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'Selesai',
                      count: allOrders.when(
                        data: (o) => o.where((order) => order.status == 'completed').length,
                        loading: () => 0,
                        error: (_, __) => 0,
                      ),
                      isSelected: _selectedStatus == 'completed',
                      onTap: () => setState(() => _selectedStatus = 'completed'),
                      color: AppTheme.successColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Order list
        Expanded(
          child: allOrders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                  const SizedBox(height: 12),
                  Text('Error: $e', style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            data: (orders) {
              // Filter by selected status
              final filteredOrders = _selectedStatus == 'all'
                  ? orders
                  : orders.where((o) => o.status == _selectedStatus).toList();

              // Sort by created_at descending
              filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedStatus == 'all'
                            ? 'Belum ada pesanan hari ini'
                            : 'Tidak ada pesanan $_selectedStatus',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _OrderCard(order: order);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? chipColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? chipColor : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? chipColor : AppTheme.textTertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(posOrderRepositoryProvider);
    final kitchenPrintService = ref.watch(kitchenPrintServiceProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => OrderDetailDialog(order: order),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: order number + badges
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          order.orderNumber ?? '#${order.id.substring(0, 8)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        _SourceBadge(source: order.orderSource ?? 'pos'),
                      ],
                    ),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),

              // Order info
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    FormatUtils.dateTime(order.createdAt),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (order.tableNumber != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.table_restaurant, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Meja ${order.tableNumber}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                FormatUtils.currency(order.totalAmount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action buttons - different for pending vs completed orders
              _ActionButtons(order: order, repo: repo, kitchenPrintService: kitchenPrintService),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (source.toLowerCase()) {
      case 'self_order':
        color = AppTheme.secondaryColor;
        icon = Icons.phone_android;
        label = 'Self-Order';
        break;
      case 'gofood':
        color = const Color(0xFF00AA13);
        icon = Icons.delivery_dining;
        label = 'GoFood';
        break;
      case 'grabfood':
        color = const Color(0xFF00B14F);
        icon = Icons.delivery_dining;
        label = 'GrabFood';
        break;
      case 'shopeefood':
        color = const Color(0xFFEE4D2D);
        icon = Icons.delivery_dining;
        label = 'ShopeeFood';
        break;
      default:
        color = AppTheme.textTertiary;
        icon = Icons.point_of_sale;
        label = 'POS';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        color = AppTheme.warningColor;
        label = 'Pending';
        break;
      case 'completed':
        color = AppTheme.successColor;
        label = 'Selesai';
        break;
      case 'voided':
        color = AppTheme.errorColor;
        label = 'Void';
        break;
      case 'refunded':
        color = AppTheme.errorColor;
        label = 'Refund';
        break;
      default:
        color = AppTheme.textTertiary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerStatefulWidget {
  final Order order;
  final dynamic repo;
  final dynamic kitchenPrintService;

  const _ActionButtons({
    required this.order,
    required this.repo,
    required this.kitchenPrintService,
  });

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool _processing = false;

  Future<void> _acceptOrder() async {
    if (_processing) return;

    // For UNPAID orders (cash), confirm payment collection first
    if (widget.order.paymentStatus == 'unpaid') {
      final confirmed = await _showPaymentConfirmation();
      if (confirmed != true) return;
    }

    setState(() => _processing = true);

    try {
      // Prepare update data
      final updates = {
        'status': 'completed',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Only update payment_status if it was unpaid (cash order with payment collected)
      // For QRIS (already paid), payment_status stays 'paid'
      if (widget.order.paymentStatus == 'unpaid') {
        updates['payment_status'] = 'paid';
      }

      // Update order status to completed (triggers stock deduction, etc.)
      await Supabase.instance.client
          .from('orders')
          .update(updates)
          .eq('id', widget.order.id);

      // Refresh order list
      ref.invalidate(posTodayOrdersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${widget.order.orderNumber} diterima!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Show confirmation dialog for cash payment collection
  Future<bool?> _showPaymentConfirmation() async {
    final orderNumber = widget.order.orderNumber;
    final total = FormatUtils.currency(widget.order.totalAmount);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pesanan: $orderNumber'),
            const SizedBox(height: 8),
            Text(
              'Total: $total',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan uang sudah diterima dari customer sebelum menerima pesanan!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Uang Sudah Diterima'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // For PENDING orders: show Accept Order button
    if (widget.order.status == 'pending') {
      final isPaid = widget.order.paymentStatus == 'paid';
      final buttonLabel = isPaid ? 'Terima Pesanan' : 'Terima Pesanan & Bayar';
      final indicatorText = isPaid
          ? 'Pembayaran sudah dikonfirmasi (${widget.order.paymentMethod.toUpperCase()})'
          : 'Menunggu pembayaran di kasir';
      final indicatorColor = isPaid ? AppTheme.successColor : AppTheme.warningColor;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Payment status indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: indicatorColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle : Icons.payment,
                  size: 16,
                  color: indicatorColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    indicatorText,
                    style: TextStyle(
                      fontSize: 12,
                      color: indicatorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Accept Order button
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle, size: 20),
              label: Text(_processing ? 'Memproses...' : buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                disabledBackgroundColor: AppTheme.successColor.withValues(alpha: 0.5),
              ),
              onPressed: _processing ? null : _acceptOrder,
            ),
          ),
        ],
      );
    }

    // For COMPLETED orders: show Kitchen Ticket + Print Receipt buttons
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restaurant_menu, size: 18),
            label: const Text('Tiket Dapur'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
              side: const BorderSide(color: AppTheme.accentColor),
            ),
            onPressed: () async {
              final items = await widget.repo.getOrderItems(widget.order.id);
              await widget.kitchenPrintService.printKitchenTicket(
                orderNumber: widget.order.orderNumber ?? '#${widget.order.id.substring(0, 8)}',
                orderType: widget.order.orderType,
                dateTime: widget.order.createdAt,
                items: items,
                tableName: widget.order.tableNumber?.toString(),
                cashierName: widget.order.cashierName,
                notes: widget.order.notes,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tiket dapur dicetak')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Cetak Struk'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () async {
              final items = await widget.repo.getOrderItems(widget.order.id);
              ReceiptPrinter.printReceipt(widget.order, items);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Struk dicetak')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
