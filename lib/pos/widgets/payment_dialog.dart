import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/pos_cart_provider.dart';
import '../providers/pos_checkout_provider.dart';
import 'order_success_dialog.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  String _paymentMethod = 'cash';
  final _cashController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  double get _cashAmount => double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(posCartProvider);
    final total = cart.total;
    final change = _cashAmount - total;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pembayaran', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${cart.itemCount} item', style: const TextStyle(color: AppTheme.textSecondary)),
                  Text(FormatUtils.currency(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MethodCard(label: 'Cash', icon: Icons.money, isSelected: _paymentMethod == 'cash', onTap: () => setState(() => _paymentMethod = 'cash')),
                _MethodCard(label: 'QRIS', icon: Icons.qr_code, isSelected: _paymentMethod == 'qris', onTap: () => setState(() => _paymentMethod = 'qris')),
                _MethodCard(label: 'Debit', icon: Icons.credit_card, isSelected: _paymentMethod == 'card', onTap: () => setState(() => _paymentMethod = 'card')),
                _MethodCard(label: 'E-Wallet', icon: Icons.account_balance_wallet, isSelected: _paymentMethod == 'e_wallet', onTap: () => setState(() => _paymentMethod = 'e_wallet')),
                _MethodCard(label: 'Transfer', icon: Icons.account_balance, isSelected: _paymentMethod == 'bank_transfer', onTap: () => setState(() => _paymentMethod = 'bank_transfer')),
              ],
            ),
            if (_paymentMethod == 'cash') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah Tunai', prefixText: 'Rp '),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [50000, 100000, 200000, 500000].map((amount) => ActionChip(
                  label: Text(FormatUtils.currency(amount)),
                  onPressed: () { _cashController.text = '$amount'; setState(() {}); },
                )).toList(),
              ),
              if (_cashAmount >= total)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(FormatUtils.currency(change), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || (_paymentMethod == 'cash' && _cashAmount < total)
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Proses Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    final cart = ref.read(posCartProvider);
    final total = cart.total;

    final double amountPaid;
    final double changeAmount;

    if (_paymentMethod == 'cash') {
      amountPaid = _cashAmount;
      changeAmount = _cashAmount - total;
    } else {
      amountPaid = total;
      changeAmount = 0;
    }

    final result = await ref.read(posCheckoutProvider.notifier).processCheckout(
      paymentMethod: _paymentMethod,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.success && result.order != null) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => OrderSuccessDialog(
          order: result.order!,
          items: result.items ?? [],
        ),
      );
    } else if (result.success) {
      // Fallback: order created but data not available (should not happen)
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Gagal memproses'), backgroundColor: AppTheme.errorColor));
    }
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _MethodCard({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
