import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../repositories/pos_cashier_repository.dart';

class ShiftOpenDialog extends StatefulWidget {
  final Future<void> Function(String cashierId, double openingCash) onOpen;
  const ShiftOpenDialog({super.key, required this.onOpen});

  @override
  State<ShiftOpenDialog> createState() => _ShiftOpenDialogState();
}

class _ShiftOpenDialogState extends State<ShiftOpenDialog> {
  final _cashController = TextEditingController();
  final _pinController = TextEditingController();
  final _repository = PosCashierRepository();

  List<CashierProfile> _cashiers = [];
  CashierProfile? _selectedCashier;
  bool _loading = false;
  bool _loadingCashiers = true;
  String? _errorMessage;
  bool _pinVerified = false;

  @override
  void initState() {
    super.initState();
    _loadCashiers();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadCashiers() async {
    setState(() {
      _loadingCashiers = true;
      _errorMessage = null;
    });

    try {
      const outletId = 'a0000000-0000-0000-0000-000000000001';
      final cashiers = await _repository.getCashiers(outletId);
      setState(() {
        _cashiers = cashiers;
        _loadingCashiers = false;
        if (cashiers.isEmpty) {
          _errorMessage = 'Tidak ada kasir aktif ditemukan';
        }
      });
    } catch (e) {
      setState(() {
        _loadingCashiers = false;
        _errorMessage = 'Gagal memuat data kasir: $e';
      });
    }
  }

  void _onCashierSelected(CashierProfile? cashier) {
    setState(() {
      _selectedCashier = cashier;
      _pinController.clear();
      _pinVerified = false;
      _errorMessage = null;
    });
  }

  void _verifyPin() {
    if (_selectedCashier == null) return;

    final isValid = _repository.verifyPin(_selectedCashier!, _pinController.text);
    setState(() {
      if (isValid) {
        _pinVerified = true;
        _errorMessage = null;
      } else {
        _errorMessage = 'PIN salah';
        _pinController.clear();
      }
    });
  }

  bool get _canProceed {
    if (_selectedCashier == null) return false;

    // If cashier has PIN, verify it first
    if (_selectedCashier!.hasPin) {
      return _pinVerified && _cashController.text.isNotEmpty;
    }

    // No PIN required
    return _cashController.text.isNotEmpty;
  }

  Future<void> _handleOpen() async {
    if (!_canProceed) return;

    setState(() => _loading = true);
    try {
      final amount = double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0;
      await widget.onOpen(_selectedCashier!.id, amount);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal membuka shift: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_open, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Buka Shift Baru',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih kasir dan masukkan modal awal',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Cashier Selection
            if (_loadingCashiers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_cashiers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage ?? 'Tidak ada kasir tersedia',
                  style: const TextStyle(color: AppTheme.errorColor),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              DropdownButtonFormField<CashierProfile>(
                initialValue: _selectedCashier,
                decoration: const InputDecoration(
                  labelText: 'Pilih Kasir',
                  prefixIcon: Icon(Icons.person),
                ),
                items: _cashiers.map((cashier) {
                  return DropdownMenuItem(
                    value: cashier,
                    child: Row(
                      children: [
                        Text(cashier.fullName),
                        const SizedBox(width: 8),
                        if (cashier.hasPin)
                          const Icon(Icons.lock, size: 16, color: AppTheme.textSecondary),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onCashierSelected,
              ),
              const SizedBox(height: 16),

              // PIN Input (if cashier has PIN and not yet verified)
              if (_selectedCashier != null && _selectedCashier!.hasPin && !_pinVerified) ...[
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'PIN Kasir',
                    prefixIcon: Icon(Icons.pin),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    if (value.length == 4) {
                      _verifyPin();
                    }
                  },
                  onSubmitted: (_) => _verifyPin(),
                ),
                const SizedBox(height: 16),
              ],

              // PIN Verified Indicator
              if (_selectedCashier != null && _selectedCashier!.hasPin && _pinVerified) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'PIN terverifikasi - ${_selectedCashier!.fullName}',
                        style: const TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Opening Cash Input (only show if cashier selected and PIN verified if needed)
              if (_selectedCashier != null && (!_selectedCashier!.hasPin || _pinVerified)) ...[
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal',
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Quick Amount Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [100000, 200000, 300000, 500000].map((amount) {
                    return ActionChip(
                      label: Text(FormatUtils.currency(amount)),
                      onPressed: () {
                        _cashController.text = '$amount';
                        setState(() {});
                      },
                      backgroundColor: AppTheme.backgroundColor,
                      side: const BorderSide(color: AppTheme.borderColor),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ],

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _loading || !_canProceed ? null : _handleOpen,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Buka Shift'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
