import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/prediction_provider.dart';
import '../repositories/prediction_repository.dart';

class PredictionPage extends ConsumerStatefulWidget {
  const PredictionPage({super.key});

  @override
  ConsumerState<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends ConsumerState<PredictionPage> {
  void _refreshAll() {
    ref.invalidate(dailySalesTrendProvider);
    ref.invalidate(salesForecastProvider);
    ref.invalidate(productDemandTrendsProvider);
    ref.invalidate(productDemandForecastsProvider);
    ref.invalidate(restockSuggestionsProvider);
    ref.invalidate(dayOfWeekPredictionsProvider);
    ref.invalidate(predictionSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Prediksi & Forecasting',
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
            // Summary cards
            _buildSummarySection(),
            const SizedBox(height: 24),
            // 1. Sales Forecast Chart
            _buildSalesForecastSection(),
            const SizedBox(height: 24),
            // 2. Day of Week Predictions
            _buildDayOfWeekSection(),
            const SizedBox(height: 24),
            // 3. Product Demand Forecast
            _buildProductDemandSection(),
            const SizedBox(height: 24),
            // 4. Restock Suggestions
            _buildRestockSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSummarySection() {
    final summaryAsync = ref.watch(predictionSummaryProvider);

    return summaryAsync.when(
      data: (summary) => _buildSummaryCards(summary),
      loading: () => _buildLoadingCard(height: 120),
      error: (e, _) => _buildErrorCard('Gagal memuat ringkasan: $e'),
    );
  }

  Widget _buildSummaryCards(PredictionSummary summary) {
    final isGrowth = summary.revenueGrowthPercent >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.aiPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: AppTheme.aiPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppTheme.aiPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prediksi berdasarkan data 30 hari terakhir menggunakan Moving Average + Linear Regression',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.aiPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.aiPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'Confidence: ${summary.confidenceScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.aiPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Cards row 1
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.trending_up,
                iconColor: AppTheme.primaryColor,
                label: 'Prediksi Minggu Depan',
                value: FormatUtils.currencyCompact(
                    summary.predictedRevenueNextWeek),
                badge: '${isGrowth ? '+' : ''}${summary.revenueGrowthPercent.toStringAsFixed(1)}%',
                badgeColor:
                    isGrowth ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.inventory_2_outlined,
                iconColor: summary.productsNeedingRestock > 0
                    ? AppTheme.warningColor
                    : AppTheme.successColor,
                label: 'Perlu Restock',
                value: '${summary.productsNeedingRestock} produk',
                badge: summary.productsNeedingRestock > 0
                    ? 'Perhatian'
                    : 'Aman',
                badgeColor: summary.productsNeedingRestock > 0
                    ? AppTheme.warningColor
                    : AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Cards row 2
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.star,
                iconColor: AppTheme.successColor,
                label: 'Hari Terbaik',
                value: summary.bestDayName,
                badge: 'Prediksi',
                badgeColor: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.speed,
                iconColor: AppTheme.infoColor,
                label: 'Rata-rata Harian',
                value:
                    FormatUtils.currencyCompact(summary.avgDailyRevenue),
                badge: 'Aktual',
                badgeColor: AppTheme.infoColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 18, color: iconColor),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. SALES FORECAST CHART
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSalesForecastSection() {
    final historicalAsync = ref.watch(dailySalesTrendProvider);
    final forecastAsync = ref.watch(salesForecastProvider);

    return _sectionCard(
      title: 'Forecast Penjualan',
      subtitle: 'Aktual (30 hari) + Prediksi (7 hari ke depan)',
      icon: Icons.show_chart,
      child: historicalAsync.when(
        data: (historical) => forecastAsync.when(
          data: (forecast) =>
              _buildSalesForecastChart(historical, forecast),
          loading: () => _buildLoadingCard(height: 280),
          error: (e, _) => _buildErrorCard('Gagal memuat forecast: $e'),
        ),
        loading: () => _buildLoadingCard(height: 280),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat data historis: $e'),
      ),
    );
  }

  Widget _buildSalesForecastChart(
    List<DailySalesPoint> historical,
    List<PredictionPoint> forecast,
  ) {
    if (historical.isEmpty) {
      return _buildEmptyState(
        icon: Icons.show_chart,
        message: 'Belum ada data penjualan untuk prediksi',
      );
    }

    // Take last 14 days of historical for cleaner chart
    final recentHistorical = historical.length > 14
        ? historical.sublist(historical.length - 14)
        : historical;

    // Build combined spots
    final historicalSpots = <FlSpot>[];
    for (var i = 0; i < recentHistorical.length; i++) {
      historicalSpots.add(FlSpot(i.toDouble(), recentHistorical[i].totalSales));
    }

    final forecastSpots = <FlSpot>[];
    final confidenceLow = <FlSpot>[];
    final confidenceHigh = <FlSpot>[];

    // Add the last historical point as the start of forecast line
    if (recentHistorical.isNotEmpty) {
      final bridgeX = (recentHistorical.length - 1).toDouble();
      forecastSpots.add(FlSpot(bridgeX, recentHistorical.last.totalSales));
    }

    for (var i = 0; i < forecast.length; i++) {
      final x = (recentHistorical.length + i).toDouble();
      forecastSpots.add(FlSpot(x, forecast[i].value));
      confidenceLow
          .add(FlSpot(x, forecast[i].confidenceLow ?? forecast[i].value));
      confidenceHigh
          .add(FlSpot(x, forecast[i].confidenceHigh ?? forecast[i].value));
    }

    // Calculate maxY
    double maxVal = 0;
    for (final s in historicalSpots) {
      if (s.y > maxVal) maxVal = s.y;
    }
    for (final s in forecastSpots) {
      if (s.y > maxVal) maxVal = s.y;
    }
    for (final s in confidenceHigh) {
      if (s.y > maxVal) maxVal = s.y;
    }
    final roundedMaxY = _ceilToNice(maxVal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _legendItem('Aktual', AppTheme.primaryColor, isDashed: false),
            const SizedBox(width: 16),
            _legendItem('Prediksi', AppTheme.accentColor, isDashed: true),
            const SizedBox(width: 16),
            _legendItem(
                'Confidence', AppTheme.accentColor.withValues(alpha: 0.2),
                isDashed: false, isArea: true),
          ],
        ),
        const SizedBox(height: 16),
        // Chart
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: roundedMaxY,
              clipData: const FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final isPred = index >= recentHistorical.length;
                      final date = isPred
                          ? forecast[index - recentHistorical.length].date
                          : recentHistorical[index].date;
                      final label = isPred ? 'Prediksi' : 'Aktual';

                      return LineTooltipItem(
                        '${FormatUtils.date(date)}\n',
                        GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '$label: ${FormatUtils.currency(spot.y)}',
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
                    interval: 3,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      DateTime? date;
                      if (index >= 0 &&
                          index < recentHistorical.length) {
                        date = recentHistorical[index].date;
                      } else if (index >= recentHistorical.length &&
                          index <
                              recentHistorical.length +
                                  forecast.length) {
                        date = forecast[index - recentHistorical.length]
                            .date;
                      }
                      if (date == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: index >= recentHistorical.length
                                ? AppTheme.accentColor
                                : AppTheme.textTertiary,
                            fontWeight:
                                index >= recentHistorical.length
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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
              // Vertical line separating actual from prediction
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: (recentHistorical.length - 1).toDouble(),
                    color: AppTheme.textTertiary.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                      labelResolver: (_) => 'Hari ini',
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                // Confidence band (high)
                if (confidenceHigh.isNotEmpty)
                  LineChartBarData(
                    spots: confidenceHigh,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.accentColor.withValues(alpha: 0.08),
                    ),
                  ),
                // Confidence band (low) - to "cut out" the bottom
                if (confidenceLow.isNotEmpty)
                  LineChartBarData(
                    spots: confidenceLow,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.backgroundColor,
                    ),
                  ),
                // Historical line (solid)
                LineChartBarData(
                  spots: historicalSpots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppTheme.primaryColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 2.5,
                        color: AppTheme.surfaceColor,
                        strokeWidth: 1.5,
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
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                        AppTheme.primaryColor.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
                // Forecast line (dashed)
                if (forecastSpots.isNotEmpty)
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.accentColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dashArray: [6, 4],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: AppTheme.surfaceColor,
                          strokeWidth: 2,
                          strokeColor: AppTheme.accentColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color,
      {bool isDashed = false, bool isArea = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isArea)
          Container(
            width: 16,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          SizedBox(
            width: 20,
            child: isDashed
                ? Row(
                    children: [
                      Container(width: 6, height: 2, color: color),
                      const SizedBox(width: 2),
                      Container(width: 6, height: 2, color: color),
                      const SizedBox(width: 2),
                      Container(width: 4, height: 2, color: color),
                    ],
                  )
                : Container(height: 2, color: color),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. DAY OF WEEK PREDICTIONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDayOfWeekSection() {
    final dowAsync = ref.watch(dayOfWeekPredictionsProvider);

    return _sectionCard(
      title: 'Prediksi Hari Terbaik/Terburuk',
      subtitle: 'Perkiraan performa per hari minggu depan',
      icon: Icons.calendar_view_week,
      child: dowAsync.when(
        data: (data) => _buildDayOfWeekContent(data),
        loading: () => _buildLoadingCard(height: 280),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat prediksi hari: $e'),
      ),
    );
  }

  Widget _buildDayOfWeekContent(List<DayOfWeekPrediction> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_view_week,
        message: 'Belum cukup data untuk prediksi hari',
      );
    }

    final maxRevenue = data.fold<double>(
        0, (prev, d) => d.predictedRevenue > prev ? d.predictedRevenue : prev);

    if (maxRevenue == 0) {
      return _buildEmptyState(
        icon: Icons.calendar_view_week,
        message: 'Belum ada data penjualan',
      );
    }

    // Find best and worst
    final bestDay = data.firstWhere((d) => d.isBestDay,
        orElse: () => data.first);
    final worstDay = data.firstWhere((d) => d.isWorstDay,
        orElse: () => data.last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Best/Worst summary
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_upward,
                            size: 16, color: AppTheme.successColor),
                        const SizedBox(width: 4),
                        Text(
                          'Hari Terbaik',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bestDay.dayName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${FormatUtils.currencyCompact(bestDay.predictedRevenue)} | ${bestDay.predictedOrders} order',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_downward,
                            size: 16, color: AppTheme.errorColor),
                        const SizedBox(width: 4),
                        Text(
                          'Hari Terburuk',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worstDay.dayName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${FormatUtils.currencyCompact(worstDay.predictedRevenue)} | ${worstDay.predictedOrders} order',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Bar chart for each day
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _ceilToNice(maxRevenue),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = data[group.x.toInt()];
                    return BarTooltipItem(
                      '${d.dayName}\n',
                      GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${FormatUtils.currency(d.predictedRevenue)}\n${d.predictedOrders} order (prediksi)',
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
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final d = data[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          d.dayName.substring(0, 3),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: d.isBestDay
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: d.isBestDay
                                ? AppTheme.successColor
                                : d.isWorstDay
                                    ? AppTheme.errorColor
                                    : AppTheme.textTertiary,
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
                    _ceilToNice(maxRevenue) > 0
                        ? _ceilToNice(maxRevenue) / 4
                        : 1,
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
                      toY: d.predictedRevenue,
                      color: d.isBestDay
                          ? AppTheme.successColor
                          : d.isWorstDay
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
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
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. PRODUCT DEMAND FORECAST
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProductDemandSection() {
    final demandAsync = ref.watch(productDemandForecastsProvider);

    return _sectionCard(
      title: 'Prediksi Demand Produk',
      subtitle: 'Top 10 produk - prediksi permintaan 7 hari ke depan',
      icon: Icons.shopping_bag_outlined,
      child: demandAsync.when(
        data: (data) => _buildProductDemandContent(data),
        loading: () => _buildLoadingCard(height: 340),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat prediksi produk: $e'),
      ),
    );
  }

  Widget _buildProductDemandContent(List<ProductDemandForecast> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        message: 'Belum ada data produk untuk prediksi',
      );
    }

    final maxDemand = data.fold<double>(
        0, (prev, d) => d.predictedNextWeek > prev ? d.predictedNextWeek : prev);

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
                child: Text('Avg/Hari',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text('Prediksi 7 Hari',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              SizedBox(
                width: 56,
                child: Text('Tren',
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
          final trendColor = p.trend > 0.1
              ? AppTheme.successColor
              : p.trend < -0.1
                  ? AppTheme.errorColor
                  : AppTheme.textTertiary;
          final trendIcon = p.trend > 0.1
              ? Icons.trending_up
              : p.trend < -0.1
                  ? Icons.trending_down
                  : Icons.trending_flat;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.productName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Mini progress bar
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: maxDemand > 0
                              ? (p.predictedNextWeek / maxDemand)
                                  .clamp(0.0, 1.0)
                              : 0,
                          minHeight: 3,
                          backgroundColor:
                              AppTheme.dividerColor.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              trendColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    p.avgDailySales.toStringAsFixed(1),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    p.predictedNextWeek.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(trendIcon, size: 14, color: trendColor),
                      const SizedBox(width: 2),
                      Text(
                        p.trendLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: trendColor,
                        ),
                      ),
                    ],
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
  // 4. RESTOCK SUGGESTIONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRestockSection() {
    final restockAsync = ref.watch(restockSuggestionsProvider);

    return _sectionCard(
      title: 'Saran Restock',
      subtitle:
          'Berdasarkan kecepatan penjualan vs stok saat ini',
      icon: Icons.inventory_outlined,
      child: restockAsync.when(
        data: (data) => _buildRestockContent(data),
        loading: () => _buildLoadingCard(height: 200),
        error: (e, _) =>
            _buildErrorCard('Gagal memuat saran restock: $e'),
      ),
    );
  }

  Widget _buildRestockContent(List<RestockSuggestion> data) {
    if (data.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        message:
            'Semua stok aman! Tidak ada produk yang perlu di-restock.',
      );
    }

    // Count by urgency
    final criticalCount =
        data.where((s) => s.urgency == 'critical').length;
    final warningCount =
        data.where((s) => s.urgency == 'warning').length;
    final infoCount = data.where((s) => s.urgency == 'info').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Urgency badges
        Row(
          children: [
            if (criticalCount > 0)
              _urgencyBadge(
                  'Kritis', criticalCount, AppTheme.errorColor),
            if (criticalCount > 0) const SizedBox(width: 8),
            if (warningCount > 0)
              _urgencyBadge(
                  'Perhatian', warningCount, AppTheme.warningColor),
            if (warningCount > 0) const SizedBox(width: 8),
            if (infoCount > 0)
              _urgencyBadge('Info', infoCount, AppTheme.infoColor),
          ],
        ),
        const SizedBox(height: 16),
        // Restock cards
        ...data.map((s) => _restockCard(s)),
      ],
    );
  }

  Widget _urgencyBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _restockCard(RestockSuggestion s) {
    final urgencyColor = s.urgency == 'critical'
        ? AppTheme.errorColor
        : s.urgency == 'warning'
            ? AppTheme.warningColor
            : AppTheme.infoColor;

    final urgencyIcon = s.urgency == 'critical'
        ? Icons.error
        : s.urgency == 'warning'
            ? Icons.warning_amber
            : Icons.info_outline;

    final daysText = s.daysUntilStockout >= 999
        ? 'Tidak ada penjualan'
        : s.daysUntilStockout <= 0
            ? 'Stok habis!'
            : '${s.daysUntilStockout} hari lagi';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: urgencyColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Urgency icon
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(urgencyIcon, size: 20, color: urgencyColor),
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.productName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stok: ${s.currentStock} | Kecepatan: ${s.dailyVelocity.toStringAsFixed(1)}/hari | $daysText',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Suggested restock
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${s.suggestedRestock}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: urgencyColor,
                ),
              ),
              Text(
                'restock',
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
  }

  // ═══════════════════════════════════════════════════════════════════
  // COMMON HELPERS
  // ═══════════════════════════════════════════════════════════════════

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
              textAlign: TextAlign.center,
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
          Icon(Icons.error_outline,
              size: 36, color: AppTheme.errorColor),
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
