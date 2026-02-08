import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../shared/themes/app_theme.dart';
import '../providers/self_order_provider.dart';
import '../repositories/self_order_repository.dart';
import 'self_order_confirmation_page.dart';

// ---------------------------------------------------------------------------
// Currency formatter
// ---------------------------------------------------------------------------
final _currencyFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

const _outletId = 'a0000000-0000-0000-0000-000000000001';

/// Cart page for customer self-order flow.
///
/// Displays the items the customer has added, allows quantity edits,
/// item removal (swipe), order-level notes, and order submission.
class SelfOrderCartPage extends ConsumerStatefulWidget {
  final String tableId;

  const SelfOrderCartPage({super.key, required this.tableId});

  @override
  ConsumerState<SelfOrderCartPage> createState() => _SelfOrderCartPageState();
}

class _SelfOrderCartPageState extends ConsumerState<SelfOrderCartPage>
    with SingleTickerProviderStateMixin {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _emptyCartController;
  late Animation<double> _emptyCartScale;

  @override
  void initState() {
    super.initState();
    _emptyCartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _emptyCartScale = CurvedAnimation(
      parent: _emptyCartController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _emptyCartController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    final cartItems = ref.read(selfOrderCartProvider);
    if (cartItems.isEmpty) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(selfOrderRepositoryProvider);
      final orderId = await repo.submitOrder(
        outletId: _outletId,
        tableId: widget.tableId,
        orderType: 'dine_in',
        items: cartItems,
        customerNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Clear cart after successful submission
      ref.read(selfOrderCartProvider.notifier).clearCart();

      if (!mounted) return;

      // Navigate to confirmation page, replacing this route
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SelfOrderConfirmationPage(
            orderId: orderId,
            tableId: widget.tableId,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gagal mengirim pesanan. Coba lagi.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(selfOrderCartProvider);
    final cartTotal = ref.watch(selfOrderCartTotalProvider);
    final cartCount = ref.watch(selfOrderCartItemCountProvider);

    // Trigger empty cart animation
    if (cartItems.isEmpty) {
      _emptyCartController.forward(from: 0);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF8F9FC),
            appBar: _buildAppBar(cartCount),
            body: cartItems.isEmpty
                ? _buildEmptyCart()
                : Column(
                    children: [
                      // Cart items list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: cartItems.length + 1, // +1 for notes section
                          itemBuilder: (context, index) {
                            if (index < cartItems.length) {
                              return _buildCartItem(cartItems[index], index);
                            }
                            // Last item: notes + summary
                            return _buildOrderFooter(cartTotal);
                          },
                        ),
                      ),

                      // Bottom bar
                      _buildBottomBar(cartTotal, cartCount),
                    ],
                  ),
          ),

          // Loading overlay during submission
          if (_isSubmitting) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================
  PreferredSizeWidget _buildAppBar(int cartCount) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        color: AppTheme.textPrimary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Text(
            'Keranjang Kamu',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (cartCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$cartCount',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY CART STATE
  // ===========================================================================
  Widget _buildEmptyCart() {
    return Center(
      child: ScaleTransition(
        scale: _emptyCartScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 56,
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Keranjang Masih Kosong',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                'Yuk, pilih menu favoritmu dan tambahkan ke keranjang!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                  label: Text(
                    'Lihat Menu',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CART ITEM CARD
  // ===========================================================================
  Widget _buildCartItem(SelfOrderItem item, int index) {
    final modifierSummary = _buildModifierText(item.modifiers);
    final unitPriceWithMod = item.unitPrice + item.modifierTotal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(item.cartKey),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          ref.read(selfOrderCartProvider.notifier).removeItem(item.cartKey);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${item.productName} dihapus dari keranjang',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: AppTheme.textSecondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Batal',
                textColor: Colors.white,
                onPressed: () {
                  ref.read(selfOrderCartProvider.notifier).addItem(item);
                },
              ),
            ),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppTheme.errorColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                'Hapus',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name and subtotal row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),

                        // Modifier summary
                        if (modifierSummary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            modifierSummary,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],

                        // Notes
                        if (item.notes != null && item.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 13,
                                color: AppTheme.accentColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.notes!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.accentColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 6),
                        // Unit price
                        Text(
                          _currencyFormat.format(unitPriceWithMod),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Subtotal
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(item.totalPrice),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // Divider
              Container(
                height: 1,
                color: AppTheme.dividerColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),

              // Quantity controls + swipe hint
              Row(
                children: [
                  // Swipe hint
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe_left_rounded,
                        size: 14,
                        color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Geser untuk hapus',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textTertiary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuantityButton(
                          icon: item.quantity > 1
                              ? Icons.remove_rounded
                              : Icons.delete_outline_rounded,
                          iconColor: item.quantity > 1
                              ? AppTheme.textPrimary
                              : AppTheme.errorColor,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (item.quantity > 1) {
                              ref
                                  .read(selfOrderCartProvider.notifier)
                                  .updateQuantity(
                                      item.cartKey, item.quantity - 1);
                            } else {
                              ref
                                  .read(selfOrderCartProvider.notifier)
                                  .removeItem(item.cartKey);
                            }
                          },
                        ),
                        SizedBox(
                          width: 36,
                          child: Center(
                            child: Text(
                              '${item.quantity}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        _QuantityButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(selfOrderCartProvider.notifier)
                                .updateQuantity(
                                    item.cartKey, item.quantity + 1);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ORDER FOOTER (Notes + Summary)
  // ===========================================================================
  Widget _buildOrderFooter(double cartTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Customer notes field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Catatan untuk Dapur',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Contoh: minta sendok extra, alergi kacang...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Order summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Subtotal row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(cartTotal),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tax info note
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.infoColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pajak & biaya layanan dihitung di kasir',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.infoColor.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Spacer for bottom bar
        const SizedBox(height: 100),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM BAR
  // ===========================================================================
  Widget _buildBottomBar(double cartTotal, int cartCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  _currencyFormat.format(cartTotal),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Pesan Sekarang',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$cartCount item',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // LOADING OVERLAY
  // ===========================================================================
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.shadowLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mengirim Pesanan...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mohon tunggu sebentar',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  String _buildModifierText(List<Map<String, dynamic>>? modifiers) {
    if (modifiers == null || modifiers.isEmpty) return '';
    return modifiers.map((m) {
      final option = m['option'] as String? ?? '';
      final price = (m['price'] as num?)?.toDouble() ?? 0;
      if (price > 0) {
        return '$option (+${_currencyFormat.format(price)})';
      }
      return option;
    }).join(', ');
  }
}

// =============================================================================
// QUANTITY BUTTON
// =============================================================================
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _QuantityButton({
    required this.icon,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: isDisabled
                ? AppTheme.textTertiary.withValues(alpha: 0.4)
                : (iconColor ?? AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}
