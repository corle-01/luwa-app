import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/report_provider.dart';
import '../repositories/report_repository.dart';

class MonthlyAnalyticsPage extends ConsumerStatefulWidget {
  const MonthlyAnalyticsPage({super.key});

  @override
  ConsumerState<MonthlyAnalyticsPage> createState() =>
      _MonthlyAnalyticsPageState();
}

class _MonthlyAnalyticsPageState extends ConsumerState<MonthlyAnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Analitik Bulanan',
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
            // Growth Metrics Section
            _buildGrowthMetricsSection(),
            const SizedBox(height: 24),
            // Monthly Sales Trend Chart
            _buildMonthlySalesTrendSection(),
            const SizedBox(height: 24),
            // Monthly Order Count Bar Chart
            _buildMonthlyOrderCountSection(),
            const SizedBox(height: 24),
            // Monthly Comparison Table
            _buildMonthlyComparisonTableSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(growthMetricsProvider);
    ref.invalidate(monthlySalesProvider);
  }

  // ─── Growth Metrics Section ───────────────────────────────────

  Widget _buildGrowthMetricsSection() {
    final growthAsync = ref.watch(growthMetricsProvider);

    return growthAsync.when(
      data: (metrics) => _buildGrowthCards(metrics),
      loading: () => _buildLoadingCard(height: 140),
      error: (e, _) => _buildErrorCard('Gagal memuat metrik pertumbuhan: $e'),
    );
  }

  Widget _buildGrowthCards(GrowthMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: _growthCard(
            icon: Icons.account_balance_wallet,
            iconColor: AppTheme.successColor,
            title: 'Penjualan Bulan Ini',
            currentValue: FormatUtils.currency(metrics.currentMonthSales),
            growthPercent: metrics.salesGrowthPercent,
            previousLabel:
                'Bulan lalu: ${FormatUtils.currencyCompact(metrics.previousMonthSales)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _growthCard(
            icon: Icons.receipt_long,
            iconColor: AppTheme.primaryColor,
            title: 'Order Bulan Ini',
            currentValue: FormatUtils.number(metrics.currentMonthOrders),
            growthPercent: metrics.orderGrowthPercent,
            previousLabel:
                'Bulan lalu: ${FormatUtils.number(metrics.previousMonthOrders)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _growthCard(
            icon: Icons.trending_up,
            iconColor: AppTheme.accentColor,
            title: 'Rata-rata Order',
            currentValue: FormatUtils.currency(metrics.currentAvgOrder),
            growthPercent: metrics.avgOrderGrowthPercent,
            previousLabel:
                'Bulan lalu: ${FormatUtils.currencyCompact(metrics.previousAvgOrder)}',
          ),
        ),
      ],
    );
  }

  Widget _growthCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String currentValue,
    required double growthPercent,
    required String previousLabel,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              _growthBadge(growthPercent),
            ],
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
            currentValue,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            previousLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _growthBadge(double percent) {
    Color badgeColor;
    IconData badgeIcon;

    if (percent > 0) {
      badgeColor = AppTheme.successColor;
      badgeIcon = Icons.trending_up;
    } else if (percent < 0) {
      badgeColor = AppTheme.errorColor;
      badgeIcon = Icons.trending_down;
    } else {
      badgeColor = AppTheme.textTertiary;
      badgeIcon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Monthly Sales Trend Chart ────────────────────────────────

  Widget _buildMonthlySalesTrendSection() {
    final monthlyAsync = ref.watch(monthlySalesProvider);

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
            'Tren Penjualan Bulanan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '6 bulan terakhir',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          monthlyAsync.when(
            data: (data) => _buildSalesTrendChart(data),
            loading: () => _buildLoadingCard(height: 240),
            error: (e, _) =>
                _buildErrorCard('Gagal memuat tren penjualan: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendChart(List<MonthlySalesData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.show_chart,
        message: 'Belum ada data penjualan bulanan',
      );
    }

    final maxY = data.fold<double>(
        0, (prev, d) => d.totalSales > prev ? d.totalSales : prev);

    if (maxY == 0) {
      return _buildEmptyState(
        icon: Icons.show_chart,
        message: 'Belum ada data penjualan bulanan',
      );
    }

    final roundedMaxY = _ceilToNice(maxY);

    return SizedBox(
      height: 240,
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
                    '${d.monthLabel}\n',
                    GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: FormatUtils.currency(d.totalSales),
                        style: GoogleFonts.inter(
                          fontSize: 13,
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
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].monthLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
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
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((entry) {
                return FlSpot(
                    entry.key.toDouble(), entry.value.totalSales);
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.surfaceColor,
                    strokeWidth: 2.5,
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
                    AppTheme.primaryColor.withValues(alpha: 0.2),
                    AppTheme.primaryColor.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Monthly Order Count Bar Chart ────────────────────────────

  Widget _buildMonthlyOrderCountSection() {
    final monthlyAsync = ref.watch(monthlySalesProvider);

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
            'Jumlah Order Bulanan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '6 bulan terakhir',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          monthlyAsync.when(
            data: (data) => _buildOrderCountChart(data),
            loading: () => _buildLoadingCard(height: 220),
            error: (e, _) =>
                _buildErrorCard('Gagal memuat jumlah order: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCountChart(List<MonthlySalesData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart,
        message: 'Belum ada data order bulanan',
      );
    }

    final maxY = data.fold<double>(
        0, (prev, d) => d.orderCount > prev ? d.orderCount.toDouble() : prev);

    if (maxY == 0) {
      return _buildEmptyState(
        icon: Icons.bar_chart,
        message: 'Belum ada data order bulanan',
      );
    }

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
                final index = group.x.toInt();
                if (index < 0 || index >= data.length) return null;
                final d = data[index];
                return BarTooltipItem(
                  '${d.monthLabel}\n',
                  GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '${d.orderCount} order',
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
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].monthLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
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
          barGroups: data.asMap().entries.map((entry) {
            final index = entry.key;
            final d = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: d.orderCount.toDouble(),
                  color: d.orderCount > 0
                      ? AppTheme.primaryColor
                      : AppTheme.dividerColor,
                  width: 28,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Monthly Comparison Table ─────────────────────────────────

  Widget _buildMonthlyComparisonTableSection() {
    final monthlyAsync = ref.watch(monthlySalesProvider);

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
            'Perbandingan Bulanan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Detail performa per bulan',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          monthlyAsync.when(
            data: (data) => _buildComparisonTable(data),
            loading: () => _buildLoadingCard(height: 200),
            error: (e, _) =>
                _buildErrorCard('Gagal memuat perbandingan: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<MonthlySalesData> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.table_chart_outlined,
        message: 'Belum ada data perbandingan',
      );
    }

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Bulan',
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
                  'Penjualan',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Order',
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
                  'Rata-rata',
                  textAlign: TextAlign.right,
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
                  'Growth',
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
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final d = entry.value;
          final isCurrentMonth =
              d.month == currentMonth && d.year == currentYear;
          final isEven = index % 2 == 0;

          // Calculate growth vs previous month in the list
          double growthPercent = 0;
          if (index > 0) {
            final prev = data[index - 1];
            if (prev.totalSales > 0) {
              growthPercent = ((d.totalSales - prev.totalSales) /
                      prev.totalSales) *
                  100;
            } else if (d.totalSales > 0) {
              growthPercent = 100;
            }
          }

          return Container(
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? AppTheme.primaryColor.withValues(alpha: 0.06)
                  : isEven
                      ? AppTheme.backgroundColor.withValues(alpha: 0.5)
                      : Colors.transparent,
              border: isCurrentMonth
                  ? Border(
                      left: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Text(
                        d.monthLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isCurrentMonth
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isCurrentMonth
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (isCurrentMonth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            'Now',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    FormatUtils.currency(d.totalSales),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${d.orderCount}',
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
                    FormatUtils.currency(d.avgOrderValue),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: index == 0
                      ? Text(
                          '-',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerRight,
                          child: _growthBadgeSmall(growthPercent),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _growthBadgeSmall(double percent) {
    Color badgeColor;
    IconData badgeIcon;

    if (percent > 0) {
      badgeColor = AppTheme.successColor;
      badgeIcon = Icons.trending_up;
    } else if (percent < 0) {
      badgeColor = AppTheme.errorColor;
      badgeIcon = Icons.trending_down;
    } else {
      badgeColor = AppTheme.textTertiary;
      badgeIcon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 2),
          Text(
            '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper Methods ───────────────────────────────────────────

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
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text(
              message,
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

  // ─── Common Widgets ───────────────────────────────────────────

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
