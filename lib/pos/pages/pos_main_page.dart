import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../widgets/pos_order_queue.dart';
import '../repositories/pos_cashier_repository.dart';
import '../providers/pos_shift_provider.dart';
import '../providers/pos_cart_provider.dart';
import '../providers/pos_queue_provider.dart';

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

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;

              if (isMobile) {
                // Mobile: full-width product grid + floating cart button + cart as bottom sheet
                return _MobilePosLayout();
              }

              // Desktop/Tablet: side-by-side layout
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
                        child: _RightPanelWithTabs(),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 480 ? screenWidth - 32 : 420.0;

    return Center(
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(screenWidth < 480 ? 20 : 32),
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

/// Mobile POS Layout: product grid full-screen with floating cart FAB
/// Tapping the FAB opens CartPanel as a modal bottom sheet
class _MobilePosLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final itemCount = cart.itemCount;

    return Stack(
      children: [
        Column(
          children: const [
            PosHeader(),
            SizedBox(height: 4),
            ProductSearchBar(),
            SizedBox(height: 4),
            CategoryTabBar(),
            Expanded(child: ProductGrid()),
          ],
        ),

        // Offline indicator
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: OfflineIndicator(),
        ),

        // Floating cart button
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 4),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const Expanded(child: CartPanel()),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                  if (itemCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          '$itemCount',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Right panel with tabs: "Pesanan Baru" (CartPanel) and "Antrian" (Order Queue)
class _RightPanelWithTabs extends ConsumerStatefulWidget {
  const _RightPanelWithTabs();

  @override
  ConsumerState<_RightPanelWithTabs> createState() => _RightPanelWithTabsState();
}

class _RightPanelWithTabsState extends ConsumerState<_RightPanelWithTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize the real-time notification listener
    Future.microtask(() => ref.read(orderQueueCountProvider));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use orderQueueCountProvider which includes notification listener
    final pendingCount = ref.watch(orderQueueCountProvider);

    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(color: AppTheme.dividerColor),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shopping_cart_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Pesanan Baru'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 18),
                    const SizedBox(width: 8),
                    const Text('Antrian'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              CartPanel(),
              PosOrderQueue(),
            ],
          ),
        ),
      ],
    );
  }
}
