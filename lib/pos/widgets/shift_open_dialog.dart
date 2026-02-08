import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../repositories/pos_cashier_repository.dart';

class ShiftOpenDialog extends StatefulWidget {
  final Future<void> Function(String cashierId, double openingCash) onOpen;
  final String outletId;
  const ShiftOpenDialog({super.key, required this.onOpen, required this.outletId});

  @override
  State<ShiftOpenDialog> createState() => _ShiftOpenDialogState();
}

class _ShiftOpenDialogState extends State<ShiftOpenDialog>
    with SingleTickerProviderStateMixin {
  final _cashController = TextEditingController();
  final _pinController = TextEditingController();
  final _repository = PosCashierRepository();
  final _pinFocusNode = FocusNode();

  List<CashierProfile> _cashiers = [];
  CashierProfile? _selectedCashier;
  bool _loading = false;
  bool _loadingCashiers = true;
  String? _errorMessage;
  bool _pinVerified = false;
  bool _pinError = false;

  // Shake animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadCashiers();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _cashController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadCashiers() async {
    setState(() {
      _loadingCashiers = true;
      _errorMessage = null;
    });

    try {
      final cashiers = await _repository.getCashiers(widget.outletId);
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
      _pinError = false;
      _errorMessage = null;
    });

    // Auto-focus PIN field if cashier has a PIN
    if (cashier != null && cashier.hasPin) {
      // Use a post-frame callback to ensure the PIN field is rendered first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pinFocusNode.requestFocus();
      });
    }
  }

  void _verifyPin() {
    if (_selectedCashier == null) return;
    if (_pinController.text.isEmpty) return;

    final isValid =
        _repository.verifyPin(_selectedCashier!, _pinController.text);
    setState(() {
      if (isValid) {
        _pinVerified = true;
        _pinError = false;
        _errorMessage = null;
      } else {
        _pinError = true;
        _errorMessage = 'PIN salah';
        _pinController.clear();
        // Trigger shake animation
        _shakeController.forward(from: 0);
        // Re-focus PIN field after clearing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pinFocusNode.requestFocus();
        });
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
    // If cashier has PIN and not yet verified, verify first
    if (_selectedCashier != null &&
        _selectedCashier!.hasPin &&
        !_pinVerified) {
      _verifyPin();
      return;
    }

    if (!_canProceed) return;

    setState(() => _loading = true);
    try {
      final amount =
          double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0;
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
            const Icon(Icons.lock_open,
                size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Buka Shift Baru',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih kasir dan masukkan modal awal',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
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
                  style: GoogleFonts.inter(color: AppTheme.errorColor),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              DropdownButtonFormField<CashierProfile>(
                value: _selectedCashier,
                decoration: InputDecoration(
                  labelText: 'Pilih Kasir',
                  labelStyle: GoogleFonts.inter(),
                  prefixIcon: const Icon(Icons.person),
                ),
                items: _cashiers.map((cashier) {
                  return DropdownMenuItem(
                    value: cashier,
                    child: Row(
                      children: [
                        Text(
                          cashier.fullName,
                          style: GoogleFonts.inter(),
                        ),
                        const SizedBox(width: 8),
                        if (cashier.hasPin)
                          const Icon(Icons.lock,
                              size: 16, color: AppTheme.textSecondary),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onCashierSelected,
              ),
              const SizedBox(height: 16),

              // PIN Input (if cashier has PIN and not yet verified)
              if (_selectedCashier != null &&
                  _selectedCashier!.hasPin &&
                  !_pinVerified) ...[
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Masukkan PIN',
                      labelStyle: GoogleFonts.inter(),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      counterText: '',
                      errorText: _pinError ? 'PIN salah' : null,
                      errorStyle: GoogleFonts.inter(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _pinError
                              ? AppTheme.errorColor
                              : AppTheme.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _pinError
                              ? AppTheme.errorColor
                              : AppTheme.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _pinError
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      // Clear error state when user types
                      if (_pinError) {
                        setState(() {
                          _pinError = false;
                          _errorMessage = null;
                        });
                      }
                    },
                    onSubmitted: (_) => _verifyPin(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan PIN kasir (4-6 digit)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // PIN Verified Indicator
              if (_selectedCashier != null &&
                  _selectedCashier!.hasPin &&
                  _pinVerified) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            AppTheme.successColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'PIN terverifikasi - ${_selectedCashier!.fullName}',
                        style: GoogleFonts.inter(
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
              if (_selectedCashier != null &&
                  (!_selectedCashier!.hasPin || _pinVerified)) ...[
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Modal Awal',
                    labelStyle: GoogleFonts.inter(),
                    prefixText: 'Rp ',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                  ),
                  style: GoogleFonts.inter(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Quick Amount Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children:
                      [100000, 200000, 300000, 500000].map((amount) {
                    return ActionChip(
                      label: Text(
                        FormatUtils.currency(amount),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
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

            // Error Message (only show general errors, not PIN errors which are inline)
            if (_errorMessage != null && !_pinError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                            color: AppTheme.errorColor),
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
                    onPressed:
                        _loading ? null : () => Navigator.pop(context),
                    child: Text('Batal', style: GoogleFonts.inter()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _loading || !_canProceed ? null : _handleOpen,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Buka Shift',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600)),
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
