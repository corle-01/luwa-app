import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/report_provider.dart';
import '../providers/operational_cost_provider.dart';
import '../repositories/report_repository.dart';

class HppReportPage extends ConsumerStatefulWidget {
  const HppReportPage({super.key});

  @override
  ConsumerState<HppReportPage> createState() => _HppReportPageState();
}

class _HppReportPageState extends ConsumerState<HppReportPage> {
  // Filter state
  String _selectedFilter = 'today';
  late DateTime _dateFrom;
  late DateTime _dateTo;

  // Sort state
  String _sortColumn = 'totalRevenue';
  bool _sortAscending = false;

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
          final weekday = now.weekday;
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

  void _refreshAll() {
    ref.invalidate(hppReportProvider(_dateRange));
  }

  void _onSortColumn(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
    });
  }

  List<HppReportItem> _sortItems(List<HppReportItem> items) {
    final sorted = List<HppReportItem>.from(items);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'productName':
          cmp = a.productName.compareTo(b.productName);
          break;
        case 'costPrice':
          cmp = a.costPrice.compareTo(b.costPrice);
          break;
        case 'sellingPrice':
          cmp = a.sellingPrice.compareTo(b.sellingPrice);
          break;
        case 'qtySold':
          cmp = a.qtySold.compareTo(b.qtySold);
          break;
        case 'totalRevenue':
          cmp = a.totalRevenue.compareTo(b.totalRevenue);
          break;
        case 'totalCost':
          cmp = a.totalCost.compareTo(b.totalCost);
          break;
        case 'grossProfit':
          cmp = a.grossProfit.compareTo(b.grossProfit);
          break;
        case 'marginPercent':
          cmp = a.marginPercent.compareTo(b.marginPercent);
          break;
        default:
          cmp = a.totalRevenue.compareTo(b.totalRevenue);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan HPP (COGS)',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
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
            // Bar chart: Revenue vs Cost per product (top 10)
            _buildBarChartSection(),
            const SizedBox(height: 24),
            // Sortable products table
            _buildProductsTableSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Date Filter Row ──────────────────────────────────────────

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

  // ── Summary Cards ────────────────────────────────────────────

  Widget _buildSummarySection() {
    final hppAsync = ref.watch(hppReportProvider(_dateRange));

    return hppAsync.when(
      data: (summary) => _buildSummaryCards(summary),
      loading: () => _buildLoadingCard(height: 120),
      error: (e, _) => _buildErrorCard('Gagal memuat ringkasan HPP: $e'),
    );
  }

  Widget _buildSummaryCards(HppSummary summary) {
    final opCostAsync = ref.watch(totalMonthlyCostProvider);
    final bonusPctAsync = ref.watch(bonusPercentageProvider);
    final totalOpCost = opCostAsync.valueOrNull ?? 0.0;
    final bonusPct = bonusPctAsync.valueOrNull ?? 0.0;
    final totalQty = summary.items.fold<int>(0, (s, i) => s + i.qtySold);
    final overheadPerPortion = totalQty > 0 ? totalOpCost / totalQty : 0.0;
    final netProfit = summary.grossProfit - totalOpCost;
    final bonusAmount = netProfit > 0 ? netProfit * (bonusPct / 100) : 0.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          icon: Icons.trending_up,
          iconColor: AppTheme.successColor,
          title: 'Total Pendapatan',
          value: FormatUtils.currency(summary.totalRevenue),
        ),
        _summaryCard(
          icon: Icons.money_off,
          iconColor: AppTheme.errorColor,
          title: 'Total HPP Bahan',
          value: FormatUtils.currency(summary.totalCost),
        ),
        _summaryCard(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppTheme.warningColor,
          title: 'Biaya Operasional/bln',
          value: FormatUtils.currency(totalOpCost),
        ),
        _summaryCard(
          icon: Icons.pie_chart_outline,
          iconColor: AppTheme.accentColor,
          title: 'Overhead/porsi',
          value: FormatUtils.currency(overheadPerPortion),
        ),
        _summaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: netProfit >= 0 ? AppTheme.infoColor : AppTheme.errorColor,
          title: 'Laba Bersih',
          value: FormatUtils.currency(netProfit),
        ),
        if (bonusPct > 0)
          _summaryCard(
            icon: Icons.card_giftcard,
            iconColor: AppTheme.warningColor,
            title: 'Bonus (${bonusPct.toStringAsFixed(0)}%)',
            value: FormatUtils.currency(bonusAmount),
          ),
        _summaryCard(
          icon: Icons.percent,
          iconColor: AppTheme.aiPrimary,
          title: 'Rata-rata Margin',
          value: '${summary.avgMargin.toStringAsFixed(1)}%',
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
    return SizedBox(
      width: 220,
      child: Container(
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
      ),
    );
  }

  // ── Bar Chart Section ────────────────────────────────────────

  Widget _buildBarChartSection() {
    final hppAsync = ref.watch(hppReportProvider(_dateRange));

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
            'Pendapatan vs HPP per Produk',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Top 10 produk berdasarkan pendapatan',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          hppAsync.when(
            data: (summary) => _buildBarChart(summary),
            loading: () => _buildLoadingCard(height: 280),
            error: (e, _) => _buildErrorCard('Gagal memuat chart: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(HppSummary summary) {
    if (summary.items.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 8),
              Text(
                'Belum ada data HPP',
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

    // Take top 10 by revenue
    final top10 = summary.items.take(10).toList();
    final maxY = top10.fold<double>(
        0, (prev, item) => item.totalRevenue > prev ? item.totalRevenue : prev);

    if (maxY == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Belum ada data pendapatan',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
      );
    }

    final roundedMaxY = _ceilToNice(maxY);

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(AppTheme.primaryColor, 'Pendapatan'),
            const SizedBox(width: 20),
            _legendDot(AppTheme.errorColor, 'HPP'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: roundedMaxY,
              minY: 0,
              groupsSpace: 16,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final item = top10[group.x.toInt()];
                    final label =
                        rodIndex == 0 ? 'Pendapatan' : 'HPP';
                    final value = rodIndex == 0
                        ? item.totalRevenue
                        : item.totalCost;
                    return BarTooltipItem(
                      '${item.productName}\n',
                      GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '$label: ${FormatUtils.currency(value)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
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
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= top10.length) {
                        return const SizedBox.shrink();
                      }
                      final name = top10[index].productName;
                      final displayName =
                          name.length > 8 ? '${name.substring(0, 8)}...' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppTheme.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
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
              barGroups: top10.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: item.totalRevenue,
                      color: AppTheme.primaryColor,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                    BarChartRodData(
                      toY: item.totalCost,
                      color: AppTheme.errorColor,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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

  // ── Products Table Section ───────────────────────────────────

  Widget _buildProductsTableSection() {
    final hppAsync = ref.watch(hppReportProvider(_dateRange));

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
            'Detail HPP per Produk',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Klik header kolom untuk mengurutkan',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          hppAsync.when(
            data: (summary) => _buildProductsTable(summary.items),
            loading: () => _buildLoadingCard(height: 200),
            error: (e, _) => _buildErrorCard('Gagal memuat tabel: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(List<HppReportItem> items) {
    if (items.isEmpty) {
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
                'Belum ada data HPP',
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

    final sortedItems = _sortItems(items);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: Column(
          children: [
            // Header row
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  _headerCell('#', null, width: 36),
                  _headerCell('Produk', 'productName', width: 140, flex: true),
                  _headerCell('HPP/unit', 'costPrice', width: 100),
                  _headerCell('Harga Jual', 'sellingPrice', width: 100),
                  _headerCell('Qty', 'qtySold', width: 60),
                  _headerCell('Total Pendapatan', 'totalRevenue', width: 130),
                  _headerCell('Total HPP', 'totalCost', width: 120),
                  _headerCell('Laba Kotor', 'grossProfit', width: 120),
                  _headerCell('Margin %', 'marginPercent', width: 90),
                ],
              ),
            ),
            const Divider(height: 1),
            // Data rows
            ...sortedItems.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final isEven = rank % 2 == 0;

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isEven
                      ? AppTheme.backgroundColor.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    // # column
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$rank',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    // Produk
                    SizedBox(
                      width: 140,
                      child: Text(
                        item.productName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // HPP/unit
                    SizedBox(
                      width: 100,
                      child: Text(
                        FormatUtils.currency(item.costPrice),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // Harga Jual
                    SizedBox(
                      width: 100,
                      child: Text(
                        FormatUtils.currency(item.sellingPrice),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // Qty
                    SizedBox(
                      width: 60,
                      child: Text(
                        FormatUtils.number(item.qtySold),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // Total Pendapatan
                    SizedBox(
                      width: 130,
                      child: Text(
                        FormatUtils.currency(item.totalRevenue),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ),
                    // Total HPP
                    SizedBox(
                      width: 120,
                      child: Text(
                        FormatUtils.currency(item.totalCost),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                    // Laba Kotor
                    SizedBox(
                      width: 120,
                      child: Text(
                        FormatUtils.currency(item.grossProfit),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.grossProfit >= 0
                              ? AppTheme.infoColor
                              : AppTheme.errorColor,
                        ),
                      ),
                    ),
                    // Margin %
                    SizedBox(
                      width: 90,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _marginColor(item.marginPercent)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.marginPercent.toStringAsFixed(1)}%',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _marginColor(item.marginPercent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String label, String? sortKey,
      {double width = 80, bool flex = false}) {
    final isSorted = _sortColumn == sortKey && sortKey != null;
    final child = InkWell(
      onTap: sortKey != null ? () => _onSortColumn(sortKey) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    isSorted ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sortKey != null) ...[
            const SizedBox(width: 2),
            Icon(
              isSorted
                  ? (_sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 12,
              color:
                  isSorted ? AppTheme.primaryColor : AppTheme.textTertiary,
            ),
          ],
        ],
      ),
    );

    return SizedBox(width: width, child: child);
  }

  Color _marginColor(double margin) {
    if (margin > 30) return AppTheme.successColor;
    if (margin >= 15) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  // ── Common Widgets ───────────────────────────────────────────

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
