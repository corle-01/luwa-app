import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../shared/services/export_service.dart';
import '../../shared/services/export_download.dart';
import '../providers/report_provider.dart';
import '../repositories/report_repository.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  // Filter state
  String _selectedFilter = 'today';
  late DateTime _dateFrom;
  late DateTime _dateTo;

  @override
  void initState() {
    super.initState();
    _applyFilter('today');
  }

  void _applyFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case 'today':
          _dateFrom = DateTime(now.year, now.month, now.day);
          _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          // Start from Monday of current week
          final weekday = now.weekday; // 1=Monday
          _dateFrom = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: weekday - 1));
          _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'month':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
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
      setState(() {
        _selectedFilter = 'custom';
        _dateFrom = picked.start;
        _dateTo = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  DateRange get _dateRange => DateRange(from: _dateFrom, to: _dateTo);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Penjualan',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date filter chips
            _buildDateFilterRow(),
            const SizedBox(height: 8),
            // Date range label
            _buildDateRangeLabel(),
            const SizedBox(height: 20),
            // Summary cards
            _buildSummarySection(),
            const SizedBox(height: 24),
            // Payment breakdown
            _buildPaymentBreakdownSection(),
            const SizedBox(height: 24),
            // Hourly sales chart
            _buildHourlySalesSection(),
            const SizedBox(height: 24),
            // Top products table
            _buildTopProductsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(salesReportProvider(_dateRange));
    ref.invalidate(topProductsProvider(_dateRange));
    ref.invalidate(hourlySalesProvider(_dateFrom));
  }

  void _exportCsv() {
    final salesAsync = ref.read(salesReportProvider(_dateRange));
    final productsAsync = ref.read(topProductsProvider(_dateRange));

    final report = salesAsync.valueOrNull;
    final products = productsAsync.valueOrNull;

    if (report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data belum dimuat. Silakan tunggu atau refresh.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dateRangeStr =
        '${FormatUtils.date(_dateFrom)} - ${FormatUtils.date(_dateTo)}';

    // Build human-readable payment breakdown labels
    final paymentBreakdown = <String, double>{};
    for (final entry in report.paymentBreakdown.entries) {
      paymentBreakdown[_paymentLabel(entry.key)] = entry.value;
    }

    final topProductsList = (products ?? []).map((p) {
      return {
        'name': p.productName,
        'qty': p.quantity,
        'revenue': p.revenue,
      };
    }).toList();

    final csvContent = ExportService.generateSalesReportCsv(
      dateRange: dateRangeStr,
      totalSales: report.totalSales,
      orderCount: report.orderCount,
      avgOrderValue: report.avgOrderValue,
      paymentBreakdown: paymentBreakdown,
      topProducts: topProductsList,
    );

    // Generate filename with date
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = 'laporan_penjualan_$dateStr.csv';

    downloadCsv(csvContent, fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Laporan berhasil diexport',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  // ─── Date Filter Row ───────────────────────────────────────────

  Widget _buildDateFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Hari Ini', 'today'),
          const SizedBox(width: 8),
          _filterChip('Minggu Ini', 'week'),
          const SizedBox(width: 8),
          _filterChip('Bulan Ini', 'month'),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.date_range,
              size: 16,
              color: _selectedFilter == 'custom'
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
            label: Text(
              _selectedFilter == 'custom' ? 'Custom' : 'Pilih Tanggal',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _selectedFilter == 'custom'
                    ? Colors.white
                    : AppTheme.textPrimary,
              ),
            ),
            backgroundColor: _selectedFilter == 'custom'
                ? AppTheme.primaryColor
                : AppTheme.surfaceColor,
            side: BorderSide(
              color: _selectedFilter == 'custom'
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
            ),
            onPressed: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
      onSelected: (_) => _applyFilter(value),
    );
  }

  Widget _buildDateRangeLabel() {
    return Text(
      '${FormatUtils.date(_dateFrom)} - ${FormatUtils.date(_dateTo)}',
      style: GoogleFonts.inter(
        fontSize: 13,
        color: AppTheme.textSecondary,
      ),
    );
  }

  // ─── Summary Cards ─────────────────────────────────────────────

  Widget _buildSummarySection() {
    final salesAsync = ref.watch(salesReportProvider(_dateRange));

    return salesAsync.when(
      data: (report) => _buildSummaryCards(report),
      loading: () => _buildLoadingCard(height: 120),
      error: (e, _) => _buildErrorCard('Gagal memuat ringkasan: $e'),
    );
  }

  Widget _buildSummaryCards(SalesReport report) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.account_balance_wallet,
            iconColor: AppTheme.successColor,
            title: 'Total Penjualan',
            value: FormatUtils.currency(report.totalSales),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.receipt_long,
            iconColor: AppTheme.primaryColor,
            title: 'Jumlah Order',
            value: FormatUtils.number(report.orderCount),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.trending_up,
            iconColor: AppTheme.accentColor,
            title: 'Rata-rata Order',
            value: FormatUtils.currency(report.avgOrderValue),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Payment Breakdown ─────────────────────────────────────────

  Widget _buildPaymentBreakdownSection() {
    final salesAsync = ref.watch(salesReportProvider(_dateRange));

    return salesAsync.when(
      data: (report) => _buildPaymentBreakdown(report),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPaymentBreakdown(SalesReport report) {
    if (report.paymentBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by value descending
    final entries = report.paymentBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metode Pembayaran',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final fraction =
                report.totalSales > 0 ? entry.value / report.totalSales : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _paymentMethodBar(
                method: entry.key,
                amount: entry.value,
                fraction: fraction,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _paymentMethodBar({
    required String method,
    required double amount,
    required double fraction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _paymentIcon(method),
                  size: 16,
                  color: _paymentColor(method),
                ),
                const SizedBox(width: 8),
                Text(
                  _paymentLabel(method),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              FormatUtils.currency(amount),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: _paymentColor(method),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            FormatUtils.percentage(fraction),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return 'E-Wallet';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'card':
        return 'Kartu Debit/Kredit';
      case 'e_wallet':
        return 'E-Wallet';
      case 'split':
        return 'Split Payment';
      default:
        return FormatUtils.titleCase(method.replaceAll('_', ' '));
    }
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'qris':
        return Icons.qr_code;
      case 'ewallet':
        return Icons.account_balance_wallet_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      case 'card':
        return Icons.credit_card;
      case 'e_wallet':
        return Icons.account_balance_wallet_outlined;
      case 'split':
        return Icons.call_split;
      default:
        return Icons.payment;
    }
  }

  Color _paymentColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.successColor;
      case 'qris':
        return AppTheme.primaryColor;
      case 'ewallet':
        return AppTheme.accentColor;
      case 'bank_transfer':
        return AppTheme.infoColor;
      case 'card':
        return AppTheme.aiPrimary;
      case 'e_wallet':
        return AppTheme.accentColor;
      case 'split':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  // ─── Hourly Sales Chart ────────────────────────────────────────

  Widget _buildHourlySalesSection() {
    final hourlyAsync = ref.watch(hourlySalesProvider(_dateFrom));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Penjualan Per Jam',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            FormatUtils.date(_dateFrom),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          hourlyAsync.when(
            data: (hourlyData) => _buildHourlyChart(hourlyData),
            loading: () => _buildLoadingCard(height: 200),
            error: (e, _) => _buildErrorCard('Gagal memuat chart: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(List<HourlySales> data) {
    // Only show hours 6-23 (typical business hours) to keep chart readable
    final filtered = data.where((h) => h.hour >= 6 && h.hour <= 23).toList();
    final maxY = filtered.fold<double>(
        0, (prev, h) => h.total > prev ? h.total : prev);

    if (maxY == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 8),
              Text(
                'Belum ada data penjualan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Round maxY up to a nice number for the axis
    final roundedMaxY = _ceilToNice(maxY);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: roundedMaxY,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hour = filtered[group.x.toInt()].hour;
                return BarTooltipItem(
                  '${hour.toString().padLeft(2, '0')}:00\n',
                  GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: FormatUtils.currency(rod.toY),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= filtered.length) {
                    return const SizedBox.shrink();
                  }
                  final hour = filtered[index].hour;
                  // Show every 2 hours to avoid crowding
                  if (hour % 2 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      FormatUtils.currencyCompact(value),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: roundedMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.dividerColor,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: filtered.asMap().entries.map((entry) {
            final index = entry.key;
            final h = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: h.total,
                  color: h.total > 0
                      ? AppTheme.primaryColor
                      : AppTheme.dividerColor,
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Round a number up to a "nice" axis value
  double _ceilToNice(double value) {
    if (value <= 0) return 100;
    final magnitude = _magnitude(value);
    final step = magnitude / 2;
    return ((value / step).ceil() * step).toDouble();
  }

  double _magnitude(double value) {
    if (value <= 0) return 1;
    double mag = 1;
    while (mag * 10 <= value) {
      mag *= 10;
    }
    return mag;
  }

  // ─── Top Products Table ────────────────────────────────────────

  Widget _buildTopProductsSection() {
    final productsAsync = ref.watch(topProductsProvider(_dateRange));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produk Terlaris',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Top 10 berdasarkan jumlah terjual',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          productsAsync.when(
            data: (products) => _buildProductsTable(products),
            loading: () => _buildLoadingCard(height: 200),
            error: (e, _) => _buildErrorCard('Gagal memuat produk: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(List<TopProduct> products) {
    if (products.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 40, color: AppTheme.textTertiary),
              const SizedBox(height: 8),
              Text(
                'Belum ada data produk',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Produk',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Qty',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Pendapatan',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Data rows
        ...products.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final product = entry.value;
          final isEven = rank % 2 == 0;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isEven
                  ? AppTheme.backgroundColor.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? _rankColor(rank).withValues(alpha: 0.15)
                          : AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$rank',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: rank <= 3
                            ? _rankColor(rank)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    product.productName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${product.quantity}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    FormatUtils.currency(product.revenue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFD97706); // Gold
      case 2:
        return const Color(0xFF6B7280); // Silver
      case 3:
        return const Color(0xFFB45309); // Bronze
      default:
        return AppTheme.textSecondary;
    }
  }

  // ─── Common Widgets ────────────────────────────────────────────

  Widget _buildLoadingCard({double height = 120}) {
    return SizedBox(
      height: height,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 40, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
