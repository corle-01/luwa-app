import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/order.dart';
import '../providers/pos_refund_provider.dart';
import '../providers/pos_checkout_provider.dart';

class VoidDialog extends ConsumerStatefulWidget {
  final Order order;
  const VoidDialog({super.key, required this.order});

  @override
  ConsumerState<VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends ConsumerState<VoidDialog> {
  final _reasonController = TextEditingController();
  String _selectedReason = '';
  bool _isProcessing = false;

  static const _commonReasons = [
    'Pesanan salah',
    'Pelanggan batal',
    'Item habis',
    'Lainnya',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
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
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.block, color: AppTheme.errorColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Void Pesanan',
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
                    'Total: ${FormatUtils.currency(widget.order.totalAmount)}',
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

            // Warning
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Void akan membatalkan seluruh pesanan dan mengembalikan stok.',
                      style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason selection
            const Text(
              'Alasan Void *',
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
                  selectedColor: AppTheme.errorColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppTheme.errorColor : AppTheme.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.errorColor : AppTheme.borderColor,
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
                  hintText: 'Tulis alasan void...',
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
                    onPressed: _canSubmit ? _processVoid : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
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
                            'Konfirmasi Void',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processVoid() async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(posRefundRepositoryProvider);
      await repo.voidOrder(
        orderId: widget.order.id,
        reason: _effectiveReason,
        voidedBy: widget.order.cashierId ?? 'cashier',
      );

      ref.invalidate(posTodayOrdersProvider);

      if (!mounted) return;

      // Close void dialog
      Navigator.pop(context);
      // Close order detail dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pesanan ${widget.order.orderNumber ?? ''} berhasil di-void',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal void pesanan: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
