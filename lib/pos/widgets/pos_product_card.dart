import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/product.dart';
import '../providers/pos_automation_provider.dart';
import '../providers/pos_cart_provider.dart';
import 'modifier_bottom_sheet.dart';

class PosProductCard extends ConsumerStatefulWidget {
  final Product product;
  const PosProductCard({super.key, required this.product});

  @override
  ConsumerState<PosProductCard> createState() => _PosProductCardState();
}

class _PosProductCardState extends ConsumerState<PosProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isAuto = ref.watch(posAutomationProvider);
    final isOutOfStock = isAuto &&
                         widget.product.calculatedAvailableQty != null &&
                         widget.product.calculatedAvailableQty! <= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isOutOfStock ? null : () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => ModifierBottomSheet(
              product: widget.product,
              onAdd: (quantity, modifiers, notes) {
                for (int i = 0; i < quantity; i++) {
                  ref.read(posCartProvider.notifier).addItem(
                    widget.product,
                    modifiers: modifiers,
                    notes: notes,
                  );
                }
              },
            ),
          );
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8), // Reduced from 12 to 8 for compact feel
              border: Border.all(
                color: _isHovered
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.borderColor.withValues(alpha: 0.5),
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // Match container border radius
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image or Initial Container - MUCH SMALLER for compact layout
                      Expanded(
                        flex: 2, // Reduced from 5 to 2 (even more compact!)
                        child: widget.product.primaryImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.product.primaryImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (_, _) => Container(
                                  color: AppTheme.backgroundColor,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),
                      ),

                      // Product Info - Optimized for tablet (compact spacing)
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), // Reduced vertical padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Product Name
                              Text(
                                widget.product.name,
                                style: GoogleFonts.inter(
                                  fontSize: 12, // Reduced from 13
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 1, // Reduced from 2 lines to save space
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2), // Reduced from 4
                              // Price
                              Text(
                                FormatUtils.currency(widget.product.sellingPrice),
                                style: GoogleFonts.inter(
                                  fontSize: 12, // Reduced from 13
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Stock Badge (AUTO mode only)
                  if (isAuto && widget.product.calculatedAvailableQty != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOutOfStock ? AppTheme.errorColor : AppTheme.successColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (isOutOfStock ? AppTheme.errorColor : AppTheme.successColor)
                                  .withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          isOutOfStock ? 'Habis' : '${widget.product.calculatedAvailableQty}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Out of Stock Overlay
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Habis',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final initial = widget.product.name.isNotEmpty
        ? widget.product.name[0].toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.6),
            AppTheme.primaryColor.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 28, // Further reduced for compact layout (was 36, originally 48)
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}
