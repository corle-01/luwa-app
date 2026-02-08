import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/pos_cart_provider.dart';
import '../providers/pos_held_orders_provider.dart';
import 'payment_dialog.dart';
import 'discount_selector_dialog.dart';
import 'customer_selector_dialog.dart';
import 'table_selector_dialog.dart';
import 'held_orders_dialog.dart';

class CartActionButtons extends ConsumerWidget {
  const CartActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final heldOrders = ref.watch(posHeldOrdersProvider);
    final heldCount = heldOrders.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Top row: small icon buttons for Diskon, Customer, Meja, Tahan
          Row(
            children: [
              Expanded(
                child: _IconButton(
                  icon: Icons.discount_outlined,
                  label: 'Diskon',
                  onTap: () => _showDiscountDialog(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IconButton(
                  icon: Icons.person_outline,
                  label: 'Customer',
                  onTap: () => _showCustomerDialog(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IconButton(
                  icon: Icons.table_restaurant_outlined,
                  label: 'Meja',
                  onTap: () => _showTableDialog(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IconButtonWithBadge(
                  icon: Icons.pause_circle_outline,
                  label: 'Tahan',
                  badgeCount: heldCount,
                  onTap: () => _holdCurrentOrder(context, ref),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Clear button (text link style) and Pay button
          Row(
            children: [
              // Clear button as text link
              if (!cart.isEmpty)
                TextButton.icon(
                  onPressed: () => _confirmClear(context, ref),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                  ),
                  label: Text(
                    'Hapus',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

              const Spacer(),

              // Pay button with gradient background
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: cart.isEmpty
                          ? [AppTheme.textTertiary, AppTheme.textTertiary]
                          : [AppTheme.successColor, AppTheme.secondaryColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: cart.isEmpty
                        ? []
                        : [
                            BoxShadow(
                              color: AppTheme.successColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: cart.isEmpty ? null : () => _showPaymentDialog(context, ref),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.payment,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bayar',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (!cart.isEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                FormatUtils.currency(cart.total),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _holdCurrentOrder(BuildContext context, WidgetRef ref) {
    final cart = ref.read(posCartProvider);
    if (cart.isEmpty) {
      // Cart is empty, show held orders dialog if there are any
      final heldOrders = ref.read(posHeldOrdersProvider);
      if (heldOrders.isNotEmpty) {
        showDialog(
          context: context,
          builder: (_) => const HeldOrdersDialog(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Keranjang kosong, tidak ada yang bisa ditahan',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: AppTheme.textSecondary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Hold the current order
    ref.read(posHeldOrdersProvider.notifier).holdOrder(cart);
    ref.read(posCartProvider.notifier).clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pesanan ditahan',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: AppTheme.accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'LIHAT',
          textColor: Colors.white,
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const HeldOrdersDialog(),
            );
          },
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Hapus Semua?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Semua item di keranjang akan dihapus.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(posCartProvider.notifier).clear();
              Navigator.pop(context);
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

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PaymentDialog(),
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const DiscountSelectorDialog(),
    );
  }

  void _showCustomerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const CustomerSelectorDialog(),
    );
  }

  void _showTableDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const TableSelectorDialog(),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.surfaceColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButtonWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _IconButtonWithBadge({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: badgeCount > 0 ? AppTheme.accentColor : AppTheme.borderColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: badgeCount > 0
                ? AppTheme.accentColor.withValues(alpha: 0.05)
                : AppTheme.surfaceColor,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: badgeCount > 0 ? AppTheme.accentColor : AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: badgeCount > 0 ? AppTheme.accentColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -6,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
