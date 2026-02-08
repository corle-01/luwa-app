import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../shared/widgets/offline_indicator.dart';
import '../../core/services/sync_service.dart';
import '../../core/providers/outlet_provider.dart';
import '../widgets/pos_header.dart';
import '../widgets/product_search_bar.dart';
import '../widgets/category_tab_bar.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../repositories/pos_cashier_repository.dart';
import '../providers/pos_shift_provider.dart';

class PosMainPage extends ConsumerWidget {
  const PosMainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftAsync = ref.watch(posShiftNotifierProvider);

    // Ensure the SyncService is alive so it auto-syncs when back online
    ref.watch(syncServiceProvider);

    return Scaffold(
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text('Error: $e', style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(posShiftNotifierProvider.notifier).refresh(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (shift) {
          if (shift == null) {
            return const _ShiftGatePage();
          }
          return Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: const [
                        PosHeader(),
                        SizedBox(height: 8),
                        ProductSearchBar(),
                        SizedBox(height: 8),
                        CategoryTabBar(),
                        Expanded(child: ProductGrid()),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  const Expanded(
                    flex: 4,
                    child: CartPanel(),
                  ),
                ],
              ),
              // Offline indicator banner at the top
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OfflineIndicator(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full-screen gate: must open shift before accessing POS
class _ShiftGatePage extends ConsumerStatefulWidget {
  const _ShiftGatePage();

  @override
  ConsumerState<_ShiftGatePage> createState() => _ShiftGatePageState();
}

class _ShiftGatePageState extends ConsumerState<_ShiftGatePage> {
  final _cashController = TextEditingController();
  final _pinController = TextEditingController();
  final _repo = PosCashierRepository();

  List<CashierProfile> _cashiers = [];
  CashierProfile? _selectedCashier;
  bool _loadingCashiers = true;
  bool _opening = false;
  bool _pinVerified = false;
  String? _error;

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
    setState(() { _loadingCashiers = true; _error = null; });
    try {
      _cashiers = await _repo.getCashiers(ref.read(currentOutletIdProvider));
      if (_cashiers.isEmpty) _error = 'Tidak ada kasir aktif. Tambahkan kasir di Back Office.';
    } catch (e) {
      _error = 'Gagal memuat kasir: $e';
    }
    if (mounted) setState(() => _loadingCashiers = false);
  }

  bool get _canOpen =>
      _selectedCashier != null &&
      (!_selectedCashier!.hasPin || _pinVerified) &&
      _cashController.text.isNotEmpty;

  Future<void> _openShift() async {
    if (!_canOpen) return;
    setState(() => _opening = true);
    final amount = double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0;
    final result = await ref.read(posShiftNotifierProvider.notifier).openShift(_selectedCashier!.id, amount);
    if (result == null && mounted) {
      setState(() { _opening = false; _error = 'Gagal membuka shift. Coba lagi.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.point_of_sale, size: 32, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text('Buka Shift', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Pilih kasir dan masukkan modal awal', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),

            if (_loadingCashiers)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_error != null && _cashiers.isEmpty)
              Column(
                children: [
                  Text(_error!, style: const TextStyle(color: AppTheme.errorColor), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _loadCashiers, child: const Text('Coba Lagi')),
                ],
              )
            else ...[
              // Cashier picker
              DropdownButtonFormField<CashierProfile>(
                initialValue: _selectedCashier,
                decoration: const InputDecoration(
                  labelText: 'Kasir',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                items: _cashiers.map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Text(c.fullName),
                      if (c.hasPin) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.lock, size: 14, color: AppTheme.textTertiary),
                      ],
                    ],
                  ),
                )).toList(),
                onChanged: (c) => setState(() {
                  _selectedCashier = c;
                  _pinVerified = false;
                  _pinController.clear();
                }),
              ),

              // PIN input
              if (_selectedCashier != null && _selectedCashier!.hasPin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    counterText: '',
                    suffixIcon: _pinVerified
                        ? const Icon(Icons.check_circle, color: AppTheme.successColor)
                        : null,
                  ),
                  onChanged: (val) {
                    if (val.length == 4) {
                      final ok = _repo.verifyPin(_selectedCashier!, val);
                      setState(() => _pinVerified = ok);
                      if (!ok) {
                        setState(() => _error = 'PIN salah');
                      } else {
                        setState(() => _error = null);
                      }
                    } else {
                      setState(() { _pinVerified = false; _error = null; });
                    }
                  },
                ),
              ],

              const SizedBox(height: 16),
              // Opening cash
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Modal Awal',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [100000, 200000, 300000, 500000].map((amount) => ActionChip(
                  label: Text(FormatUtils.currency(amount)),
                  onPressed: () { _cashController.text = '$amount'; setState(() {}); },
                )).toList(),
              ),

              if (_error != null && _cashiers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _opening || !_canOpen ? null : _openShift,
                  icon: _opening
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open),
                  label: Text(_opening ? 'Membuka...' : 'Buka Shift'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
