import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/online_food_provider.dart';
import 'amount_input_field.dart';

/// Dark-theme color constants for the Online Food feature.
class _C {
  static const background = Color(0xFF13131D);
  static const card = Color(0xFF1A1A28);
  static const border = Color(0xFF1E1E2E);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
  static const textTertiary = Color(0xFF6B7280);
}

/// Platform accent colors.
const _platformColors = <OnlinePlatform, Color>{
  OnlinePlatform.gofood: Color(0xFF00880C),
  OnlinePlatform.grabfood: Color(0xFF00B14F),
  OnlinePlatform.shopeefood: Color(0xFFEE4D2D),
};

/// Right-panel cart widget for the Online Food screen.
///
/// Shows:
/// - Header with "Order Items" + platform badge
/// - Platform order ID display
/// - List of items with qty +/- and delete buttons
/// - Total item count
/// - Final amount input ([AmountInputField])
/// - Submit button colored by the selected platform
class OnlineFoodCart extends ConsumerWidget {
  const OnlineFoodCart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onlineFoodProvider);
    final notifier = ref.read(onlineFoodProvider.notifier);
    final platform = state.selectedPlatform;
    final platformColor =
        platform != null ? _platformColors[platform]! : const Color(0xFF6366F1);

    return Container(
      decoration: const BoxDecoration(
        color: _C.background,
        border: Border(
          left: BorderSide(color: _C.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _C.card,
              border: Border(
                bottom: BorderSide(color: _C.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Order Items',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                if (platform != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: platformColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: platformColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      platform.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: platformColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Platform Order ID ───────────────────────────────────────
          if (state.platformOrderId.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: _C.card,
                border: Border(
                  bottom: BorderSide(color: _C.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: _C.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ID: ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _C.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      state.platformOrderId,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _C.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Item list ───────────────────────────────────────────────
          Expanded(
            child: state.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: _C.textTertiary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada item',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _C.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap produk untuk menambahkan',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _C.textTertiary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _CartItemTile(
                        item: item,
                        onIncrement: () => notifier.addItem(
                          item.productId,
                          item.productName,
                          variantName: item.variantName,
                        ),
                        onDecrement: () => notifier.removeItem(
                          item.productId,
                          variantName: item.variantName,
                        ),
                        onDelete: () => notifier.clearItem(
                          item.productId,
                          variantName: item.variantName,
                        ),
                      );
                    },
                  ),
          ),

          // ── Bottom section ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _C.card,
              border: Border(
                top: BorderSide(color: _C.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _C.textSecondary,
                      ),
                    ),
                    Text(
                      '${state.totalItems} item',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.textPrimary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Final amount input
                const AmountInputField(),

                const SizedBox(height: 16),

                // Error message
                if (state.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      state.error!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFEF4444),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Submit button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: state.canSubmit
                        ? () async {
                            await notifier.submitOrder();
                            final updatedState = ref.read(onlineFoodProvider);
                            if (updatedState.isSuccess && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Order ${platform?.label ?? 'Online'} berhasil disimpan!',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: platformColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: platformColor,
                      disabledBackgroundColor: _C.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Simpan Order${platform != null ? ' ${platform.label}' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single cart item tile
// ---------------------------------------------------------------------------

class _CartItemTile extends StatelessWidget {
  final OnlineFoodItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  const _CartItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variantName != null &&
                    item.variantName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.variantName!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _C.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Qty controls
          Container(
            decoration: BoxDecoration(
              color: _C.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus
                _QtyButton(
                  icon: Icons.remove,
                  onTap: onDecrement,
                ),
                // Qty
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _C.textPrimary,
                    ),
                  ),
                ),
                // Plus
                _QtyButton(
                  icon: Icons.add,
                  onTap: onIncrement,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Delete button
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: _C.textSecondary,
        ),
      ),
    );
  }
}
