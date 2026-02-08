import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/pos_order_provider.dart';
import '../widgets/order_detail_dialog.dart';

class PosOrderHistoryPage extends ConsumerStatefulWidget {
  const PosOrderHistoryPage({super.key});

  @override
  ConsumerState<PosOrderHistoryPage> createState() => _PosOrderHistoryPageState();
}

class _PosOrderHistoryPageState extends ConsumerState<PosOrderHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedDatePreset = 'today'; // today, week, month, custom

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final current = ref.read(posOrderFilterProvider);
    if (query.isEmpty) {
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(clearSearch: true);
    } else {
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(searchQuery: query);
    }
  }

  void _selectDatePreset(String preset) {
    setState(() => _selectedDatePreset = preset);
    final now = DateTime.now();
    final current = ref.read(posOrderFilterProvider);

    switch (preset) {
      case 'today':
        ref.read(posOrderFilterProvider.notifier).state = current.copyWith(
          startDate: DateTime(now.year, now.month, now.day),
          clearEndDate: true,
        );
        break;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        ref.read(posOrderFilterProvider.notifier).state = current.copyWith(
          startDate: DateTime(weekStart.year, weekStart.month, weekStart.day),
          endDate: now,
        );
        break;
      case 'month':
        ref.read(posOrderFilterProvider.notifier).state = current.copyWith(
          startDate: DateTime(now.year, now.month, 1),
          endDate: now,
        );
        break;
      case 'custom':
        _showDateRangePicker();
        break;
    }
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final filter = ref.read(posOrderFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: filter.startDate ?? DateTime(now.year, now.month, now.day),
        end: filter.endDate ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDatePreset = 'custom');
      final current = ref.read(posOrderFilterProvider);
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(
        startDate: picked.start,
        endDate: picked.end,
      );
    }
  }

  void _setStatusFilter(String? status) {
    final current = ref.read(posOrderFilterProvider);
    if (status == null) {
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(clearStatus: true);
    } else {
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(status: status);
    }
  }

  void _setPaymentMethodFilter(String? method) {
    final current = ref.read(posOrderFilterProvider);
    if (method == null) {
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(clearPaymentMethod: true);
    } else {
      ref.read(posOrderFilterProvider.notifier).state = current.copyWith(paymentMethod: method);
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() => _selectedDatePreset = 'today');
    ref.read(posOrderFilterProvider.notifier).state = OrderFilter();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(posFilteredOrdersProvider);
    final orderCount = ref.watch(posFilteredOrderCountProvider);
    final totalSales = ref.watch(posFilteredSalesProvider);
    final filter = ref.watch(posOrderFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Riwayat Pesanan',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (filter.hasFilters)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: Text(
                'Reset',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(posFilteredOrdersProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          _buildFilterSection(filter),

          // Summary cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _SummaryCard(
                  title: 'Total Order',
                  value: '$orderCount',
                  icon: Icons.receipt_long,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                _SummaryCard(
                  title: 'Total Penjualan',
                  value: FormatUtils.currency(totalSales),
                  icon: Icons.payments_outlined,
                  color: AppTheme.successColor,
                ),
              ],
            ),
          ),

          // Order list
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada pesanan',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coba ubah filter untuk melihat pesanan lain',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(posFilteredOrdersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat data',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$e',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(posFilteredOrdersProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(OrderFilter filter) {
    return Container(
      color: AppTheme.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari nomor pesanan...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
          ),

          // Date range chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Hari Ini',
                    selected: _selectedDatePreset == 'today',
                    onSelected: () => _selectDatePreset('today'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Minggu Ini',
                    selected: _selectedDatePreset == 'week',
                    onSelected: () => _selectDatePreset('week'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Bulan Ini',
                    selected: _selectedDatePreset == 'month',
                    onSelected: () => _selectDatePreset('month'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: _selectedDatePreset == 'custom' && filter.startDate != null
                        ? '${FormatUtils.date(filter.startDate!)} - ${FormatUtils.date(filter.endDate ?? DateTime.now())}'
                        : 'Custom',
                    selected: _selectedDatePreset == 'custom',
                    onSelected: () => _selectDatePreset('custom'),
                    icon: Icons.calendar_today,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Status & payment method filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _DropdownFilter(
                    value: filter.status,
                    hint: 'Status',
                    icon: Icons.flag_outlined,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua Status')),
                      DropdownMenuItem(value: 'completed', child: Text('Selesai')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
                      DropdownMenuItem(value: 'voided', child: Text('Void')),
                      DropdownMenuItem(value: 'refunded', child: Text('Refund')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    ],
                    onChanged: _setStatusFilter,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DropdownFilter(
                    value: filter.paymentMethod,
                    hint: 'Pembayaran',
                    icon: Icons.payment,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua Metode')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                      DropdownMenuItem(value: 'debit', child: Text('Debit')),
                      DropdownMenuItem(value: 'e_wallet', child: Text('E-Wallet')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    ],
                    onChanged: _setPaymentMethodFilter,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.dividerColor),
        ],
      ),
    );
  }
}

// --- Filter Chip ---

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dropdown Filter ---

class _DropdownFilter extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                hint,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
              ),
            ],
          ),
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.textSecondary),
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// --- Summary Card ---

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Order Card ---

class _OrderCard extends StatelessWidget {
  final dynamic order;

  const _OrderCard({required this.order});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'voided':
        return AppTheme.errorColor;
      case 'refunded':
        return AppTheme.accentColor;
      case 'pending':
        return AppTheme.infoColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'voided':
        return 'Void';
      case 'refunded':
        return 'Refund';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'qris':
        return 'QRIS';
      case 'debit':
        return 'Debit';
      case 'e_wallet':
        return 'E-Wallet';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method.toUpperCase();
    }
  }

  IconData _paymentMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money;
      case 'qris':
        return Icons.qr_code;
      case 'debit':
        return Icons.credit_card;
      case 'e_wallet':
        return Icons.account_balance_wallet;
      case 'bank_transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order.status as String;
    final color = _statusColor(status);
    final paymentMethod = order.paymentMethod as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (_) => OrderDetailDialog(order: order),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.orderNumber ?? '#${order.id.substring(0, 8)}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: AppTheme.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          FormatUtils.time(order.createdAt),
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          FormatUtils.date(order.createdAt),
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _paymentMethodIcon(paymentMethod),
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _paymentMethodLabel(paymentMethod),
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Total amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.currency(order.totalAmount),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
