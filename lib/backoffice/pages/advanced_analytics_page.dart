import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/analytics_provider.dart';
import '../providers/report_provider.dart';
import '../repositories/analytics_repository.dart';

class AdvancedAnalyticsPage extends ConsumerStatefulWidget {
  const AdvancedAnalyticsPage({super.key});

  @override
  ConsumerState<AdvancedAnalyticsPage> createState() =>
      _AdvancedAnalyticsPageState();
}

class _AdvancedAnalyticsPageState
    extends ConsumerState<AdvancedAnalyticsPage> {
  // Date range for date-dependent queries
  late DateTime _dateFrom;
  late DateTime _dateTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  DateRange get _dateRange => DateRange(from: _dateFrom, to: _dateTo);

  void _refreshAll() {
    ref.invalidate(peakHoursProvider);
    ref.invalidate(dayOfWeekProvider);
    ref.invalidate(topCustomersProvider);
    ref.invalidate(productPerformanceProvider(_dateRange));
    ref.invalidate(orderSourceProvider(_dateRange));
    ref.invalidate(aovTrendProvider);
    ref.invalidate(customerRetentionProvider);
    ref.invalidate(staffPerformanceProvider(_dateRange));
  }

  Future<void> _pickDateRange() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Analitik Lanjutan',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Pilih Tanggal',
            onPressed: _pickDateRange,
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
            // Date range indicator
            _buildDateRangeIndicator(),
            const SizedBox(height: 20),
            // 1. Peak Hours
            _buildPeakHoursSection(),
            const SizedBox(height: 24),
            // 2. Day of Week
            _buildDayOfWeekSection(),
            const SizedBox(height: 24),
            // 3. Product ABC Analysis
            _buildProductAbcSection(),
            const SizedBox(height: 24),
            // 4. Order Source Breakdown
            _buildOrderSourceSection(),
            const SizedBox(height: 24),
            // 5. AOV Trend
            _buildAovTrendSection(),
            const SizedBox(height: 24),
            // 6. Customer Insights
            _buildCustomerInsightsSection(),
            const SizedBox(height: 24),
            // 7. Staff Performance
            _buildStaffPerformanceSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Date Range Indicator ────────────────────────────────────────

  Widget _buildDateRangeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today,
              size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            '${FormatUtils.date(_dateFrom)} - ${FormatUtils.date(_dateTo)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(Analitik jam sibuk & AOV: 30 hari terakhir)',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. PEAK HOURS HEATMAP
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPeakHoursSection() {
    final peakAsync = ref.watch(peakHoursProvider);

    return _sectionCard(
      title: 'Jam Sibuk',
      subtitle: '30 hari terakhir - distribusi order per jam',
      icon: Icons.schedule,
      child: peakAsync.when(
        data: (data) => _buildPeakHoursChart(data),
        loading: () => _buildLoadingCard(height: 260),
        error: (e, _) => _buildErrorCard('Gagal memuat data jam sibuk: $e'),
      ),
    );
  }

  Widget _buildPeakHoursChart(List<PeakHourData> data) {
    // Filter business hours 6-23
    final filtered = data.where((h) => h.hour >= 6 && h.hour <= 23).toList();
    final maxOrders = filtered.fold<int>(
        0, (prev, h) => h.orderCount > prev ? h.orderCount : prev);

    if (maxOrders == 0) {
      return _buildEmptyState(
          icon: Icons.schedule, message: 'Belum ada data jam sibuk');
    }

    // Find peak hour
    final peakHour =
        filtered.reduce((a, b) => a.orderCount > b.orderCount ? a : b);

    final roundedMaxY = _ceilToNice(maxOrders.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Peak hour summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Jam tersibuk: ${peakHour.hour.toString().padLeft(2, '0')}:00 - ${(peakHour.hour + 1).toString().padLeft(2, '0')}:00',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${peakHour.orderCount} order',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Bar chart
        SizedBox(
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
                    final h = filtered[group.x.toInt()];
                    return BarTooltipItem(
                      '${h.hour.toString().padLeft(2, '0')}:00\n',
                      GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${h.orderCount} order\n${FormatUtils.currencyCompact(h.revenue)}',
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
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= filtered.length) {
                        return const SizedBox.shrink();
                      }
                      final hour = filtered[index].hour;
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
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toInt().toString(),
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
                horizontalInterval:
                    roundedMaxY > 0 ? roundedMaxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.dividerColor,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: filtered.asMap().entries.map((entry) {
                final index = entry.key;
                final h = entry.value;
                // Highlight peak hours in accent color
                final isPeak =
                    h.orderCount >= (maxOrders * 0.8).ceil();
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: h.orderCount.toDouble(),
                      color: isPeak
                          ? AppTheme.accentColor
                          : h.orderCount > 0
                              ? AppTheme.primaryColor
                              : AppTheme.dividerColor,
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

  // ═══════════════════════════════════════════════════════════════════
  // 2. DAY OF WEEK ANALYSIS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDayOfWeekSection() {
    final dowAsync = ref.watch(dayOfWeekProvider);

    return _sectionCard(
      title: 'Analisis Hari',
      subtitle: '30 hari terakhir - performa per hari',
      icon: Icons.calendar_view_week,
      child: dowAsync.when(
        data: (data) => _buildDayOfWeekChart(data),
        loading: () => _buildLoadingCard(height: 280),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat data hari: $e'),
      ),
    );
  }

  Widget _buildDayOfWeekChart(List<DayOfWeekData> data) {
    final maxRevenue = data.fold<double>(
        0, (prev, d) => d.revenue > prev ? d.revenue : prev);

    if (maxRevenue == 0) {
      return _buildEmptyState(
          icon: Icons.calendar_view_week,
          message: 'Belum ada data analisis hari');
    }

    // Find busiest day
    final busiestDay =
        data.reduce((a, b) => a.orderCount > b.orderCount ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Busiest day summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Icon(Icons.star, color: AppTheme.successColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Hari tersibuk: ${busiestDay.dayName}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${busiestDay.orderCount} order  |  ${FormatUtils.currencyCompact(busiestDay.revenue)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Horizontal bars for each day
        ...data.map((d) {
          final fraction = maxRevenue > 0 ? d.revenue / maxRevenue : 0.0;
          final isBusiest = d.day == busiestDay.day;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    d.dayName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isBusiest ? FontWeight.w700 : FontWeight.w500,
                      color: isBusiest
                          ? AppTheme.successColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: isBusiest
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 8),
                          child: fraction > 0.15
                              ? Text(
                                  '${d.orderCount}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    FormatUtils.currencyCompact(d.revenue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
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

  // ═══════════════════════════════════════════════════════════════════
  // 3. PRODUCT ABC ANALYSIS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProductAbcSection() {
    final productAsync =
        ref.watch(productPerformanceProvider(_dateRange));

    return _sectionCard(
      title: 'Analisis ABC Produk',
      subtitle:
          'A = 80% revenue, B = 15%, C = 5%',
      icon: Icons.inventory_2_outlined,
      child: productAsync.when(
        data: (data) => _buildProductAbcContent(data),
        loading: () => _buildLoadingCard(height: 340),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat analisis produk: $e'),
      ),
    );
  }

  Widget _buildProductAbcContent(List<ProductPerformanceData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
          icon: Icons.inventory_2_outlined,
          message: 'Belum ada data produk');
    }

    // Take top 10 for chart
    final top10 = data.take(10).toList();
    final maxRevenue = top10.fold<double>(
        0, (prev, p) => p.revenue > prev ? p.revenue : prev);
    final roundedMaxY = _ceilToNice(maxRevenue);

    // Category counts
    final countA = data.where((p) => p.abcCategory == 'A').length;
    final countB = data.where((p) => p.abcCategory == 'B').length;
    final countC = data.where((p) => p.abcCategory == 'C').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ABC summary badges
        Row(
          children: [
            _abcBadge('A', countA, const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _abcBadge('B', countB, const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _abcBadge('C', countC, const Color(0xFFEF4444)),
            const Spacer(),
            Text(
              'Total: ${data.length} produk',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Bar chart (top 10)
        SizedBox(
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
                    final p = top10[group.x.toInt()];
                    return BarTooltipItem(
                      '${p.productName}\n',
                      GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${FormatUtils.currency(p.revenue)}\n${p.qtySold} pcs  |  Kategori ${p.abcCategory}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= top10.length) {
                        return const SizedBox.shrink();
                      }
                      final name = top10[index].productName;
                      final truncated =
                          name.length > 8 ? '${name.substring(0, 8)}..' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: RotatedBox(
                          quarterTurns: 0,
                          child: Text(
                            truncated,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppTheme.textTertiary,
                            ),
                            textAlign: TextAlign.center,
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
                horizontalInterval:
                    roundedMaxY > 0 ? roundedMaxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.dividerColor,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: top10.asMap().entries.map((entry) {
                final index = entry.key;
                final p = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: p.revenue,
                      color: _abcColor(p.abcCategory),
                      width: 18,
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
        ),
        const SizedBox(height: 16),
        // Product detail table
        _buildAbcTable(data.take(15).toList()),
      ],
    );
  }

  Widget _abcBadge(String category, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count produk',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbcTable(List<ProductPerformanceData> data) {
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
                width: 28,
                child: Text('#',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                flex: 3,
                child: Text('Produk',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                child: Text('Qty',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text('Revenue',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              SizedBox(
                width: 36,
                child: Text('ABC',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...data.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final p = entry.value;
          final isEven = rank % 2 == 0;

          return Container(
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isEven
                  ? AppTheme.backgroundColor.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    p.productName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${p.qtySold}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    FormatUtils.currency(p.revenue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _abcColor(p.abcCategory)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.abcCategory,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _abcColor(p.abcCategory),
                        ),
                      ),
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

  Color _abcColor(String category) {
    switch (category) {
      case 'A':
        return const Color(0xFF10B981); // green
      case 'B':
        return const Color(0xFFF59E0B); // yellow/amber
      case 'C':
        return const Color(0xFFEF4444); // red
      default:
        return AppTheme.textSecondary;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. ORDER SOURCE BREAKDOWN
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildOrderSourceSection() {
    final sourceAsync = ref.watch(orderSourceProvider(_dateRange));

    return _sectionCard(
      title: 'Sumber Order',
      subtitle: 'Distribusi berdasarkan sumber pesanan',
      icon: Icons.account_tree_outlined,
      child: sourceAsync.when(
        data: (data) => _buildOrderSourceContent(data),
        loading: () => _buildLoadingCard(height: 200),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat sumber order: $e'),
      ),
    );
  }

  Widget _buildOrderSourceContent(List<OrderSourceData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
          icon: Icons.account_tree_outlined,
          message: 'Belum ada data sumber order');
    }

    final totalOrders =
        data.fold<int>(0, (sum, d) => sum + d.orderCount);

    // Colors for sources
    final sourceColors = <String, Color>{
      'pos': AppTheme.primaryColor,
      'self_order': AppTheme.successColor,
      'gofood': const Color(0xFFEF4444),
      'grabfood': const Color(0xFF10B981),
      'shopeefood': const Color(0xFFF97316),
    };

    return Column(
      children: [
        // Pie chart
        SizedBox(
          height: 180,
          child: Row(
            children: [
              // Pie
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: data.map((d) {
                      final color = sourceColors[d.source] ??
                          AppTheme.textSecondary;
                      return PieChartSectionData(
                        color: color,
                        value: d.orderCount.toDouble(),
                        title:
                            '${d.percentage.toStringAsFixed(1)}%',
                        titleStyle: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        radius: 50,
                        titlePositionPercentageOffset: 0.6,
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Legend
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: data.map((d) {
                  final color = sourceColors[d.source] ??
                      AppTheme.textSecondary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          d.sourceLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Detail bars
        ...data.map((d) {
          final color =
              sourceColors[d.source] ?? AppTheme.textSecondary;
          final fraction =
              totalOrders > 0 ? d.orderCount / totalOrders : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    d.sourceLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${d.orderCount}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 68,
                  child: Text(
                    FormatUtils.currencyCompact(d.revenue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
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

  // ═══════════════════════════════════════════════════════════════════
  // 5. AOV TREND
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAovTrendSection() {
    final aovAsync = ref.watch(aovTrendProvider);

    return _sectionCard(
      title: 'Tren Rata-rata Order',
      subtitle: 'Average Order Value - 30 hari terakhir',
      icon: Icons.show_chart,
      child: aovAsync.when(
        data: (data) => _buildAovTrendChart(data),
        loading: () => _buildLoadingCard(height: 260),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat tren AOV: $e'),
      ),
    );
  }

  Widget _buildAovTrendChart(List<AovTrendData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
          icon: Icons.show_chart,
          message: 'Belum ada data AOV');
    }

    // Current AOV (last data point)
    final currentAov = data.last.avgOrderValue;
    final avgAov = data.isNotEmpty
        ? data.fold<double>(0, (sum, d) => sum + d.avgOrderValue) /
            data.length
        : 0.0;

    final maxY = data.fold<double>(
        0, (prev, d) => d.avgOrderValue > prev ? d.avgOrderValue : prev);
    final roundedMaxY = _ceilToNice(maxY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current AOV highlight
        Row(
          children: [
            _aovInfoCard(
              title: 'AOV Saat Ini',
              value: FormatUtils.currency(currentAov),
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            _aovInfoCard(
              title: 'Rata-rata AOV',
              value: FormatUtils.currency(avgAov),
              color: AppTheme.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Line chart
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: roundedMaxY,
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < 0 || index >= data.length) return null;
                      final d = data[index];
                      return LineTooltipItem(
                        '${FormatUtils.date(d.date)}\n',
                        GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'AOV: ${FormatUtils.currency(d.avgOrderValue)}\n${d.orderCount} order',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (data.length / 5).ceilToDouble().clamp(1, 30),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final d = data[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${d.date.day}/${d.date.month}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
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
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    roundedMaxY > 0 ? roundedMaxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.dividerColor,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: data.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(),
                        entry.value.avgOrderValue);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppTheme.primaryColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: AppTheme.surfaceColor,
                        strokeWidth: 2,
                        strokeColor: AppTheme.primaryColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                        AppTheme.primaryColor.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aovInfoCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. CUSTOMER INSIGHTS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCustomerInsightsSection() {
    final customersAsync = ref.watch(topCustomersProvider);
    final retentionAsync = ref.watch(customerRetentionProvider);

    return _sectionCard(
      title: 'Insight Pelanggan',
      subtitle: 'Top pelanggan & retensi',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Retention metrics
          retentionAsync.when(
            data: (retention) => _buildRetentionMetrics(retention),
            loading: () => _buildLoadingCard(height: 80),
            error: (e, _) =>
                _buildErrorCard('Gagal memuat retensi: $e'),
          ),
          const SizedBox(height: 16),
          // Top customers
          Text(
            'Top 5 Pelanggan',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          customersAsync.when(
            data: (customers) =>
                _buildTopCustomerCards(customers.take(5).toList()),
            loading: () => _buildLoadingCard(height: 200),
            error: (e, _) =>
                _buildErrorCard('Gagal memuat pelanggan: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionMetrics(CustomerRetentionData retention) {
    return Row(
      children: [
        Expanded(
          child: _metricTile(
            icon: Icons.person_add_outlined,
            iconColor: AppTheme.infoColor,
            label: 'Pelanggan Baru',
            value: '${retention.newCustomers}',
            subtitle: '30 hari terakhir',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricTile(
            icon: Icons.replay,
            iconColor: AppTheme.successColor,
            label: 'Pelanggan Kembali',
            value: '${retention.returningCustomers}',
            subtitle: '>1 kunjungan',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricTile(
            icon: Icons.auto_graph,
            iconColor: AppTheme.accentColor,
            label: 'Retensi',
            value: '${retention.retentionRate.toStringAsFixed(1)}%',
            subtitle: '${retention.totalCustomers} total',
          ),
        ),
      ],
    );
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomerCards(List<TopCustomerData> customers) {
    if (customers.isEmpty) {
      return _buildEmptyState(
          icon: Icons.people_outline,
          message: 'Belum ada data pelanggan');
    }

    return Column(
      children: customers.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final c = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: rank == 1
                ? const Color(0xFFFEF3C7) // Gold bg for #1
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: rank == 1
                  ? const Color(0xFFFCD34D)
                  : AppTheme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? _rankColor(rank).withValues(alpha: 0.15)
                      : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        rank <= 3 ? _rankColor(rank) : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Customer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.phone != null)
                      Text(
                        c.phone!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.currency(c.totalSpent),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${c.totalVisits} kunjungan  |  ${c.loyaltyPoints} poin',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. STAFF PERFORMANCE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStaffPerformanceSection() {
    final staffAsync =
        ref.watch(staffPerformanceProvider(_dateRange));

    return _sectionCard(
      title: 'Performa Staff',
      subtitle: 'Order dan revenue per kasir/staff',
      icon: Icons.badge_outlined,
      child: staffAsync.when(
        data: (data) => _buildStaffPerformanceContent(data),
        loading: () => _buildLoadingCard(height: 300),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat performa staff: $e'),
      ),
    );
  }

  Widget _buildStaffPerformanceContent(List<StaffPerformanceData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
          icon: Icons.badge_outlined,
          message: 'Belum ada data performa staff');
    }

    final maxRevenue = data.fold<double>(
        0, (prev, s) => s.totalRevenue > prev ? s.totalRevenue : prev);
    final roundedMaxY = _ceilToNice(maxRevenue);

    // Staff colors
    final staffColors = [
      AppTheme.primaryColor,
      AppTheme.successColor,
      AppTheme.accentColor,
      AppTheme.infoColor,
      AppTheme.aiPrimary,
      const Color(0xFFF97316),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar chart
        SizedBox(
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
                    final s = data[group.x.toInt()];
                    return BarTooltipItem(
                      '${s.staffName}\n',
                      GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${FormatUtils.currency(s.totalRevenue)}\n${s.totalOrders} order',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final name = data[index].staffName;
                      final truncated = name.length > 10
                          ? '${name.substring(0, 10)}..'
                          : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          truncated,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppTheme.textTertiary,
                          ),
                          textAlign: TextAlign.center,
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
                horizontalInterval:
                    roundedMaxY > 0 ? roundedMaxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.dividerColor,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((entry) {
                final index = entry.key;
                final s = entry.value;
                final color =
                    staffColors[index % staffColors.length];
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: s.totalRevenue,
                      color: color,
                      width: 24,
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
        ),
        const SizedBox(height: 16),
        // Staff table
        _buildStaffTable(data),
      ],
    );
  }

  Widget _buildStaffTable(List<StaffPerformanceData> data) {
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
              Expanded(
                flex: 3,
                child: Text('Staff',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                child: Text('Order',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text('Revenue',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text('Avg/Order',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final s = entry.value;
          final isEven = index % 2 == 0;

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
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.staffName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _roleLabel(s.role),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    '${s.totalOrders}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    FormatUtils.currency(s.totalRevenue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    FormatUtils.currency(s.avgOrderValue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
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

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'cashier':
        return 'Kasir';
      case 'kitchen':
        return 'Kitchen';
      case 'waiter':
        return 'Waiter';
      default:
        return role;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // COMMON HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Wraps a section in a consistent card style.
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
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
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard({double height = 120}) {
    return SizedBox(
      height: height,
      child: Center(
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
          Icon(Icons.error_outline, size: 36, color: AppTheme.errorColor),
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
