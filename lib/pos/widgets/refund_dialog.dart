import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/order.dart';
import '../providers/pos_refund_provider.dart';
import '../providers/pos_checkout_provider.dart';

class RefundDialog extends ConsumerStatefulWidget {
  final Order order;
  const RefundDialog({super.key, required this.order});

  @override
  ConsumerState<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends ConsumerState<RefundDialog> {
  late final TextEditingController _amountController;
  final _reasonController = TextEditingController();
  String _selectedReason = '';
  bool _isProcessing = false;
  bool _isFullRefund = true;

  static const _commonReasons = [
    'Pelanggan komplain',
    'Produk bermasalah',
    'Salah hitung',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.order.totalAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _refundAmount {
    return double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
  }

  String get _effectiveReason {
    if (_selectedReason == 'Lainnya') {
      return _reasonController.text.trim();
    }
    return _selectedReason;
  }

  bool get _canSubmit {
    if (_isProcessing) return false;
    if (_selectedReason.isEmpty) return false;
    if (_selectedReason == 'Lainnya' && _reasonController.text.trim().isEmpty) {
      return false;
    }
    if (_refundAmount <= 0) return false;
    if (_refundAmount > widget.order.totalAmount) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.replay, color: AppTheme.accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Refund Pesanan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.orderNumber ?? '#${widget.order.id.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Pesanan: ${FormatUtils.currency(widget.order.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Refund type toggle
              const Text(
                'Tipe Refund',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RefundTypeButton(
                      label: 'Refund Penuh',
                      isSelected: _isFullRefund,
                      onTap: () {
                        setState(() {
                          _isFullRefund = true;
                          _amountController.text =
                              widget.order.totalAmount.toStringAsFixed(0);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RefundTypeButton(
                      label: 'Refund Sebagian',
                      isSelected: !_isFullRefund,
                      onTap: () {
                        setState(() {
                          _isFullRefund = false;
                          _amountController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Refund amount
              const Text(
                'Jumlah Refund',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                enabled: !_isFullRefund,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                  helperText: 'Maksimal: ${FormatUtils.currency(widget.order.totalAmount)}',
                  helperStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  errorText: _refundAmount > widget.order.totalAmount
                      ? 'Melebihi total pesanan'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Refund method display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: AppTheme.successColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kembalikan tunai',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ),
                    Text(
                      FormatUtils.currency(_refundAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              const Text(
                'Alasan Refund *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonReasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return ChoiceChip(
                    label: Text(reason),
                    selected: isSelected,
                    selectedColor: AppTheme.accentColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.accentColor : AppTheme.borderColor,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedReason = selected ? reason : '';
                      });
                    },
                  );
                }).toList(),
              ),

              // Custom reason text field (shown when "Lainnya" is selected)
              if (_selectedReason == 'Lainnya') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Tulis alasan refund...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _processRefund : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Konfirmasi Refund',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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

  Future<void> _processRefund() async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(posRefundRepositoryProvider);
      await repo.refundOrder(
        orderId: widget.order.id,
        refundAmount: _refundAmount,
        reason: _effectiveReason,
      );

      ref.invalidate(posTodayOrdersProvider);

      if (!mounted) return;

      // Close refund dialog
      Navigator.pop(context);
      // Close order detail dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund ${FormatUtils.currency(_refundAmount)} berhasil diproses',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses refund: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _RefundTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _RefundTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
