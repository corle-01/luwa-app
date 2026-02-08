import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/pos_cart_provider.dart';

class CartSummary extends ConsumerWidget {
  const CartSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: const Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Subtotal
          _SummaryRow(
            label: 'Subtotal',
            value: FormatUtils.currency(cart.subtotal),
            labelStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            valueStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),

          // Discount
          if (cart.discount != null) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Diskon (${cart.discount!.name})',
              value: '- ${FormatUtils.currency(cart.discountAmount)}',
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              valueStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.errorColor,
              ),
            ),
          ],

          // Tax rows
          ...cart.taxes.where((t) => t.type == 'tax' && !t.isInclusive).map((tax) {
            final amount = cart.afterDiscount * (tax.rate / 100);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SummaryRow(
                label: '${tax.name} (${tax.rate.toStringAsFixed(0)}%)',
                value: FormatUtils.currency(amount),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                valueStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            );
          }),

          // Service charge rows
          ...cart.taxes.where((t) => t.type == 'service_charge' && !t.isInclusive).map((tax) {
            final amount = cart.afterDiscount * (tax.rate / 100);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SummaryRow(
                label: '${tax.name} (${tax.rate.toStringAsFixed(0)}%)',
                value: FormatUtils.currency(amount),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                valueStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            );
          }),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.dividerColor,
            ),
          ),

          // Total
          _SummaryRow(
            label: 'Total',
            value: FormatUtils.currency(cart.total),
            labelStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            valueStyle: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
