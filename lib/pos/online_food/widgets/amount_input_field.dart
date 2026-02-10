import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/online_food_provider.dart';

/// Dark-theme color constants for the Online Food feature.
class _C {
  static const card = Color(0xFF1A1A28);
  static const border = Color(0xFF1E1E2E);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
  static const textTertiary = Color(0xFF6B7280);
}

/// Styled number input for the final amount received from the online food
/// platform.
///
/// - Label: "Final Amount dari Platform"
/// - Prefix: "Rp"
/// - Number keyboard
/// - Shows the formatted Rupiah value below the input
/// - Calls [OnlineFoodNotifier.setFinalAmount] on change
class AmountInputField extends ConsumerStatefulWidget {
  const AmountInputField({super.key});

  @override
  ConsumerState<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends ConsumerState<AmountInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  double? _parsedAmount;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });

    // Seed from provider if already set
    final current = ref.read(onlineFoodProvider).finalAmount;
    if (current != null && current > 0) {
      _controller.text = current.toInt().toString();
      _parsedAmount = current;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatRupiah(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return 'Rp ${formatter.format(amount).replaceAll(',', '.')}';
  }

  void _onChanged(String raw) {
    // Strip non-digits
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => _parsedAmount = null);
      ref.read(onlineFoodProvider.notifier).setFinalAmount(null);
      return;
    }
    final amount = double.tryParse(digits);
    setState(() => _parsedAmount = amount);
    ref.read(onlineFoodProvider.notifier).setFinalAmount(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Revenue Diterima',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _C.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Input
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? const Color(0xFF6366F1) : _C.border,
              width: _isFocused ? 1.5 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _onChanged,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _C.textPrimary,
            ),
            decoration: InputDecoration(
              prefixText: 'Rp  ',
              prefixStyle: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _C.textSecondary,
              ),
              hintText: '0',
              hintStyle: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _C.textTertiary,
              ),
              filled: true,
              fillColor: _C.card,
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
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Hint text
        Text(
          'Jumlah yang masuk ke rekening',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _C.textTertiary,
          ),
        ),

        // Formatted amount preview
        if (_parsedAmount != null && _parsedAmount! > 0) ...[
          const SizedBox(height: 4),
          Text(
            _formatRupiah(_parsedAmount!),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ],
    );
  }
}
