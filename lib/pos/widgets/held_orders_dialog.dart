import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/held_order.dart';
import '../providers/pos_held_orders_provider.dart';
import '../providers/pos_cart_provider.dart';

class HeldOrdersDialog extends ConsumerWidget {
  const HeldOrdersDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldOrders = ref.watch(posHeldOrdersProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 440,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: AppTheme.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pesanan Tertahan',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (heldOrders.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${heldOrders.length}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Content
            if (heldOrders.isEmpty)
              _buildEmptyState()
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: heldOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _HeldOrderCard(
                    heldOrder: heldOrders[index],
                    onRecall: () =>
                        _handleRecall(context, ref, heldOrders[index]),
                    onDelete: () =>
                        _handleDelete(context, ref, heldOrders[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: 56,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada pesanan tertahan',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tekan tombol "Tahan" untuk menahan pesanan aktif',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRecall(
      BuildContext context, WidgetRef ref, HeldOrder heldOrder) {
    final currentCart = ref.read(posCartProvider);

    if (!currentCart.isEmpty) {
      // Current cart is not empty, ask what to do
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            'Keranjang Tidak Kosong',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Keranjang saat ini memiliki ${currentCart.itemCount} item. '
            'Apa yang ingin Anda lakukan?',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Hold current cart first, then recall
                ref
                    .read(posHeldOrdersProvider.notifier)
                    .holdOrder(currentCart);
                final recalledState = ref
                    .read(posHeldOrdersProvider.notifier)
                    .recallOrder(heldOrder.id);
                if (recalledState != null) {
                  ref.read(posCartProvider.notifier).restoreState(recalledState);
                }
                Navigator.pop(context); // close confirmation dialog
                Navigator.pop(context); // close held orders dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Pesanan sebelumnya ditahan, "${heldOrder.displayLabel}" dipanggil kembali',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: Text(
                'Tahan & Panggil',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Discard current cart, then recall
                final recalledState = ref
                    .read(posHeldOrdersProvider.notifier)
                    .recallOrder(heldOrder.id);
                if (recalledState != null) {
                  ref.read(posCartProvider.notifier).restoreState(recalledState);
                }
                Navigator.pop(context); // close confirmation dialog
                Navigator.pop(context); // close held orders dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '"${heldOrder.displayLabel}" dipanggil kembali',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                'Buang & Panggil',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Cart is empty, just recall directly
      final recalledState = ref
          .read(posHeldOrdersProvider.notifier)
          .recallOrder(heldOrder.id);
      if (recalledState != null) {
        ref.read(posCartProvider.notifier).restoreState(recalledState);
      }
      Navigator.pop(context); // close held orders dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${heldOrder.displayLabel}" dipanggil kembali',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDelete(
      BuildContext context, WidgetRef ref, HeldOrder heldOrder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Hapus Pesanan Tertahan?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Pesanan "${heldOrder.displayLabel}" akan dihapus permanen. '
          'Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(posHeldOrdersProvider.notifier)
                  .deleteHeldOrder(heldOrder.id);
              Navigator.pop(context); // close confirmation dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Pesanan "${heldOrder.displayLabel}" dihapus',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  backgroundColor: AppTheme.textSecondary,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeldOrderCard extends StatelessWidget {
  final HeldOrder heldOrder;
  final VoidCallback onRecall;
  final VoidCallback onDelete;

  const _HeldOrderCard({
    required this.heldOrder,
    required this.onRecall,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cart = heldOrder.cartState;
    final elapsed = DateTime.now().difference(heldOrder.heldAt);
    final elapsedText = _formatElapsed(elapsed);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + elapsed time
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: 18,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  heldOrder.displayLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _getElapsedColor(elapsed).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: _getElapsedColor(elapsed),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      elapsedText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getElapsedColor(elapsed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Order info row: item count, order type, total
          Row(
            children: [
              _InfoChip(
                icon: Icons.shopping_bag_outlined,
                text: '${cart.itemCount} item',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: cart.orderType == 'dine_in'
                    ? Icons.restaurant
                    : Icons.takeout_dining,
                text: cart.orderType == 'dine_in' ? 'Dine In' : 'Takeaway',
              ),
              if (cart.tableNumber != null) ...[
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.table_restaurant,
                  text: 'Meja ${cart.tableNumber}',
                ),
              ],
              const Spacer(),
              Text(
                FormatUtils.currency(cart.total),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          // Items preview (first 3 items)
          if (cart.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...cart.items.take(3).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Text(
                              '${item.quantity}x',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.product.name,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              FormatUtils.currency(item.itemTotal),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (cart.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+${cart.items.length - 3} item lainnya',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              // Delete button
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(
                  'Hapus',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Spacer(),
              // Recall button
              ElevatedButton.icon(
                onPressed: onRecall,
                icon: const Icon(Icons.replay, size: 16),
                label: Text(
                  'Panggil Kembali',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatElapsed(Duration elapsed) {
    if (elapsed.inSeconds < 60) {
      return 'Baru saja';
    } else if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes} mnt lalu';
    } else if (elapsed.inHours < 24) {
      return '${elapsed.inHours} jam lalu';
    } else {
      return '${elapsed.inDays} hari lalu';
    }
  }

  Color _getElapsedColor(Duration elapsed) {
    if (elapsed.inMinutes < 10) {
      return AppTheme.successColor;
    } else if (elapsed.inMinutes < 30) {
      return AppTheme.accentColor;
    } else {
      return AppTheme.errorColor;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: AppTheme.textTertiary,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
