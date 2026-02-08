import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/pos_cart_provider.dart';
import '../providers/pos_checkout_provider.dart';
import 'order_success_dialog.dart';

/// Data class representing one payment split entry.
class _SplitEntry {
  String method;
  final TextEditingController controller;

  _SplitEntry({required this.method, String? initialAmount})
      : controller = TextEditingController(text: initialAmount ?? '');

  double get amount =>
      double.tryParse(controller.text.replaceAll('.', '')) ?? 0;

  void dispose() => controller.dispose();
}

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  // Normal (single) payment state
  String _paymentMethod = 'cash';
  final _cashController = TextEditingController();
  bool _isProcessing = false;

  // Split payment state
  bool _isSplitMode = false;
  final List<_SplitEntry> _splitEntries = [];

  @override
  void initState() {
    super.initState();
    // Initialize with 2 split entries by default
    _splitEntries.add(_SplitEntry(method: 'cash'));
    _splitEntries.add(_SplitEntry(method: 'qris'));
  }

  @override
  void dispose() {
    _cashController.dispose();
    for (final entry in _splitEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  double get _cashAmount =>
      double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0;

  double get _splitTotal =>
      _splitEntries.fold(0.0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(posCartProvider);
    final total = cart.total;
    final change = _paymentMethod == 'cash' ? _cashAmount - total : 0.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 450,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed header section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Pembayaran',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Total display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${cart.itemCount} item',
                            style: const TextStyle(
                                color: AppTheme.textSecondary)),
                        Text(FormatUtils.currency(total),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Split payment toggle
                  _buildSplitToggle(),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _isSplitMode
                    ? _buildSplitPaymentContent(total)
                    : _buildSinglePaymentContent(total, change),
              ),
            ),

            // Fixed bottom button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing || !_canProcess(total)
                      ? null
                      : _processPayment,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isSplitMode
                              ? 'Proses Split Payment'
                              : 'Proses Pembayaran',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle button between single and split payment
  Widget _buildSplitToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isSplitMode = !_isSplitMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isSplitMode
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _isSplitMode ? AppTheme.primaryColor : AppTheme.borderColor,
            width: _isSplitMode ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.call_split,
              size: 18,
              color: _isSplitMode
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Split Payment',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isSplitMode
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                color: _isSplitMode
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(9),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _isSplitMode
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single payment mode content (existing behavior)
  Widget _buildSinglePaymentContent(double total, double change) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Metode Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MethodCard(
                label: 'Cash',
                icon: Icons.money,
                isSelected: _paymentMethod == 'cash',
                onTap: () => setState(() => _paymentMethod = 'cash')),
            _MethodCard(
                label: 'QRIS',
                icon: Icons.qr_code,
                isSelected: _paymentMethod == 'qris',
                onTap: () => setState(() => _paymentMethod = 'qris')),
            _MethodCard(
                label: 'Debit',
                icon: Icons.credit_card,
                isSelected: _paymentMethod == 'card',
                onTap: () => setState(() => _paymentMethod = 'card')),
            _MethodCard(
                label: 'E-Wallet',
                icon: Icons.account_balance_wallet,
                isSelected: _paymentMethod == 'e_wallet',
                onTap: () => setState(() => _paymentMethod = 'e_wallet')),
            _MethodCard(
                label: 'Transfer',
                icon: Icons.account_balance,
                isSelected: _paymentMethod == 'bank_transfer',
                onTap: () =>
                    setState(() => _paymentMethod = 'bank_transfer')),
          ],
        ),
        if (_paymentMethod == 'cash') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _cashController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Jumlah Tunai', prefixText: 'Rp '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [50000, 100000, 200000, 500000]
                .map((amount) => ActionChip(
                      label: Text(FormatUtils.currency(amount)),
                      onPressed: () {
                        _cashController.text = '$amount';
                        setState(() {});
                      },
                    ))
                .toList(),
          ),
          if (_cashAmount >= total)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color:
                        AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(FormatUtils.currency(change),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  /// Split payment mode content
  Widget _buildSplitPaymentContent(double total) {
    final remaining = total - _splitTotal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Split entries list
        ...List.generate(_splitEntries.length, (index) {
          return _buildSplitEntryRow(index, total);
        }),

        const SizedBox(height: 8),

        // Add split entry button
        if (_splitEntries.length < 5)
          TextButton.icon(
            onPressed: () {
              setState(() {
                // Pick a method not yet used, fallback to 'cash'
                final usedMethods =
                    _splitEntries.map((e) => e.method).toSet();
                final allMethods = [
                  'cash',
                  'qris',
                  'card',
                  'e_wallet',
                  'bank_transfer'
                ];
                final available = allMethods
                    .where((m) => !usedMethods.contains(m))
                    .toList();
                final nextMethod =
                    available.isNotEmpty ? available.first : 'cash';
                _splitEntries.add(_SplitEntry(method: nextMethod));
              });
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Tambah Metode',
                style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
          ),

        const SizedBox(height: 12),

        // Summary: paid vs remaining
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: remaining <= 0.001
                ? AppTheme.successColor.withValues(alpha: 0.1)
                : AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: remaining <= 0.001
                  ? AppTheme.successColor.withValues(alpha: 0.3)
                  : AppTheme.warningColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pesanan',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  Text(FormatUtils.currency(total),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sudah Dibayar',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  Text(FormatUtils.currency(_splitTotal),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    remaining <= 0.001 ? 'Lunas' : 'Sisa',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: remaining <= 0.001
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                  ),
                  Text(
                    remaining <= 0.001
                        ? FormatUtils.currency(0)
                        : FormatUtils.currency(remaining),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: remaining <= 0.001
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// A single split entry row: method dropdown + amount input + delete
  Widget _buildSplitEntryRow(int index, double total) {
    final entry = _splitEntries[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // Method selector dropdown
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<String>(
                value: entry.method,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                  labelText: 'Metode',
                  labelStyle: TextStyle(fontSize: 12),
                ),
                items: _methodDropdownItems,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => entry.method = val);
                  }
                },
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            // Amount input
            Expanded(
              flex: 4,
              child: TextField(
                controller: entry.controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                  labelText: 'Jumlah',
                  labelStyle: TextStyle(fontSize: 12),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
              ),
            ),
            // Quick-fill remaining
            const SizedBox(width: 4),
            SizedBox(
              width: 32,
              height: 32,
              child: Tooltip(
                message: 'Isi sisa',
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  color: AppTheme.primaryColor,
                  onPressed: () {
                    final otherTotal = _splitEntries
                        .asMap()
                        .entries
                        .where((e) => e.key != index)
                        .fold(0.0, (sum, e) => sum + e.value.amount);
                    final remaining = total - otherTotal;
                    if (remaining > 0) {
                      entry.controller.text =
                          remaining.toStringAsFixed(0);
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
            // Delete button (only if more than 2 entries)
            if (_splitEntries.length > 2)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 16),
                  color: AppTheme.errorColor,
                  onPressed: () {
                    setState(() {
                      _splitEntries[index].dispose();
                      _splitEntries.removeAt(index);
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Dropdown items for payment method selection
  List<DropdownMenuItem<String>> get _methodDropdownItems => const [
        DropdownMenuItem(value: 'cash', child: Text('Cash')),
        DropdownMenuItem(value: 'qris', child: Text('QRIS')),
        DropdownMenuItem(value: 'card', child: Text('Debit Card')),
        DropdownMenuItem(value: 'e_wallet', child: Text('E-Wallet')),
        DropdownMenuItem(
            value: 'bank_transfer', child: Text('Transfer')),
      ];

  /// Determines if the process button should be enabled
  bool _canProcess(double total) {
    if (_isSplitMode) {
      // All entries must have amount > 0 and total must match
      final allHaveAmount = _splitEntries.every((e) => e.amount > 0);
      final totalMatches = (_splitTotal - total).abs() < 1;
      return allHaveAmount && totalMatches;
    } else {
      if (_paymentMethod == 'cash') {
        return _cashAmount >= total;
      }
      return true;
    }
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    final cart = ref.read(posCartProvider);
    final total = cart.total;

    final String paymentMethod;
    final double amountPaid;
    final double changeAmount;
    List<Map<String, dynamic>>? paymentDetails;

    if (_isSplitMode) {
      paymentMethod = 'split';
      amountPaid = _splitTotal;
      changeAmount = 0;
      paymentDetails = _splitEntries
          .where((e) => e.amount > 0)
          .map((e) => {
                'method': e.method,
                'amount': e.amount,
                'label': _methodLabel(e.method),
              })
          .toList();
    } else if (_paymentMethod == 'cash') {
      paymentMethod = 'cash';
      amountPaid = _cashAmount;
      changeAmount = _cashAmount - total;
    } else {
      paymentMethod = _paymentMethod;
      amountPaid = total;
      changeAmount = 0;
    }

    final result =
        await ref.read(posCheckoutProvider.notifier).processCheckout(
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
              changeAmount: changeAmount,
              paymentDetails: paymentDetails,
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
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error ?? 'Gagal memproses'),
          backgroundColor: AppTheme.errorColor));
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'card':
        return 'Debit';
      case 'e_wallet':
        return 'E-Wallet';
      case 'bank_transfer':
        return 'Transfer';
      default:
        return method;
    }
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _MethodCard(
      {required this.label,
      required this.icon,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
