import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/report_provider.dart';
import '../repositories/report_repository.dart';

class PnlReportPage extends ConsumerStatefulWidget {
  const PnlReportPage({super.key});

  @override
  ConsumerState<PnlReportPage> createState() => _PnlReportPageState();
}

class _PnlReportPageState extends ConsumerState<PnlReportPage> {
  // Filter state
  String _selectedFilter = 'month';
  late DateTime _dateFrom;
  late DateTime _dateTo;

  // Manual operating expenses (persisted in-memory for the session)
  final List<ExpenseEntry> _manualExpenses = [
    ExpenseEntry(id: 'rent', category: 'Sewa Tempat', amount: 0),
    ExpenseEntry(id: 'utilities', category: 'Listrik & Air', amount: 0),
    ExpenseEntry(id: 'salary', category: 'Gaji Karyawan', amount: 0),
    ExpenseEntry(id: 'marketing', category: 'Marketing', amount: 0),
    ExpenseEntry(id: 'packaging', category: 'Packaging', amount: 0),
    ExpenseEntry(id: 'other', category: 'Lain-lain', amount: 0),
  ];

  @override
  void initState() {
    super.initState();
    _applyFilter('month');
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
    ref.invalidate(pnlReportProvider(_dateRange));
  }

  double get _totalManualExpenses =>
      _manualExpenses.fold(0.0, (s, e) => s + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Laba Rugi (P&L)',
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
            _buildDateFilterRow(),
            const SizedBox(height: 8),
            _buildDateRangeLabel(),
            const SizedBox(height: 20),
            _buildPnlContent(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPnlContent() {
    final pnlAsync = ref.watch(pnlReportProvider(_dateRange));

    return pnlAsync.when(
      data: (report) => _buildPnlBody(report),
      loading: () => _buildLoadingCard(height: 400),
      error: (e, _) => _buildErrorCard('Gagal memuat laporan P&L: $e'),
    );
  }

  Widget _buildPnlBody(PnlReport report) {
    final grossProfit = report.totalRevenue - report.totalCogs;
    final grossMargin =
        report.totalRevenue > 0 ? (grossProfit / report.totalRevenue) * 100 : 0.0;
    final netProfit = grossProfit - _totalManualExpenses;
    final netMargin =
        report.totalRevenue > 0 ? (netProfit / report.totalRevenue) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top summary cards
        _buildTopSummaryCards(report, grossProfit, grossMargin, netProfit, netMargin),
        const SizedBox(height: 24),
        // Profit indicator bar
        _buildProfitIndicator(netProfit, netMargin),
        const SizedBox(height: 24),
        // Revenue section
        _buildRevenueSection(report),
        const SizedBox(height: 24),
        // COGS section
        _buildCogsSection(report, grossProfit, grossMargin),
        const SizedBox(height: 24),
        // Operating expenses section
        _buildExpensesSection(),
        const SizedBox(height: 24),
        // Net profit section
        _buildNetProfitSection(grossProfit, netProfit, netMargin),
        const SizedBox(height: 24),
        // Visual breakdown chart
        _buildBreakdownChart(report, grossProfit, netProfit),
      ],
    );
  }

  // ── Top Summary Cards ─────────────────────────────────────────

  Widget _buildTopSummaryCards(
    PnlReport report,
    double grossProfit,
    double grossMargin,
    double netProfit,
    double netMargin,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          icon: Icons.trending_up,
          iconColor: AppTheme.successColor,
          title: 'Total Pendapatan',
          value: FormatUtils.currency(report.totalRevenue),
          subtitle: '${report.orderCount} order',
        ),
        _summaryCard(
          icon: Icons.shopping_cart_outlined,
          iconColor: AppTheme.errorColor,
          title: 'HPP (COGS)',
          value: FormatUtils.currency(report.totalCogs),
          subtitle:
              '${report.totalRevenue > 0 ? (report.totalCogs / report.totalRevenue * 100).toStringAsFixed(1) : '0.0'}% dari pendapatan',
        ),
        _summaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: grossProfit >= 0 ? AppTheme.infoColor : AppTheme.errorColor,
          title: 'Laba Kotor',
          value: FormatUtils.currency(grossProfit),
          subtitle: 'Margin ${grossMargin.toStringAsFixed(1)}%',
          valueColor: grossProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
        ),
        _summaryCard(
          icon: Icons.assessment,
          iconColor: netProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
          title: 'Laba Bersih',
          value: FormatUtils.currency(netProfit),
          subtitle: 'Margin ${netMargin.toStringAsFixed(1)}%',
          valueColor: netProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
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
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Profit Indicator ──────────────────────────────────────────

  Widget _buildProfitIndicator(double netProfit, double netMargin) {
    final isProfit = netProfit >= 0;
    final color = isProfit ? AppTheme.successColor : AppTheme.errorColor;
    final label = isProfit ? 'LABA' : 'RUGI';
    final icon = isProfit ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $label',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${FormatUtils.currency(netProfit.abs())} (${netMargin.abs().toStringAsFixed(1)}% margin)',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue Section ───────────────────────────────────────────

  Widget _buildRevenueSection(PnlReport report) {
    return _sectionCard(
      title: 'Pendapatan (Revenue)',
      titleColor: AppTheme.successColor,
      icon: Icons.arrow_circle_up,
      children: [
        _lineItem('Total Penjualan', report.totalRevenue,
            isBold: true, color: AppTheme.successColor),
        if (report.totalDiscount > 0)
          _lineItem('Diskon', -report.totalDiscount, color: AppTheme.errorColor),
        if (report.totalTax > 0)
          _lineItem('Pajak Terkumpul', report.totalTax, color: AppTheme.textSecondary),
        if (report.totalServiceCharge > 0)
          _lineItem('Service Charge', report.totalServiceCharge,
              color: AppTheme.textSecondary),
        const Divider(height: 24),
        // Payment method breakdown
        if (report.revenueByPayment.isNotEmpty) ...[
          _subSectionTitle('Per Metode Pembayaran'),
          const SizedBox(height: 8),
          ...report.revenueByPayment.map((item) => _lineItem(
                _paymentLabel(item.label),
                item.amount,
                color: AppTheme.textPrimary,
                showBar: true,
                fraction:
                    report.totalRevenue > 0 ? item.amount / report.totalRevenue : 0,
              )),
        ],
        if (report.revenueBySource.isNotEmpty &&
            report.revenueBySource.length > 1) ...[
          const SizedBox(height: 16),
          _subSectionTitle('Per Sumber Order'),
          const SizedBox(height: 8),
          ...report.revenueBySource.map((item) => _lineItem(
                _sourceLabel(item.label),
                item.amount,
                color: AppTheme.textPrimary,
                showBar: true,
                fraction:
                    report.totalRevenue > 0 ? item.amount / report.totalRevenue : 0,
                barColor: _sourceColor(item.label),
              )),
        ],
      ],
    );
  }

  // ── COGS Section ──────────────────────────────────────────────

  Widget _buildCogsSection(
      PnlReport report, double grossProfit, double grossMargin) {
    return _sectionCard(
      title: 'Harga Pokok Penjualan (HPP / COGS)',
      titleColor: AppTheme.errorColor,
      icon: Icons.arrow_circle_down,
      children: [
        _lineItem('Total HPP', report.totalCogs,
            isBold: true, color: AppTheme.errorColor),
        const Divider(height: 24),
        _lineItem(
          'Laba Kotor (Gross Profit)',
          grossProfit,
          isBold: true,
          color: grossProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
          fontSize: 16,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (grossProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Margin: ${grossMargin.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: grossProfit >= 0
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Operating Expenses Section ────────────────────────────────

  Widget _buildExpensesSection() {
    return _sectionCard(
      title: 'Biaya Operasional',
      titleColor: AppTheme.warningColor,
      icon: Icons.receipt_long,
      trailing: TextButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: Text(
          'Tambah',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: _addExpenseDialog,
      ),
      children: [
        if (_manualExpenses.every((e) => e.amount == 0))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ketuk nilai untuk mengisi biaya operasional bulanan. '
                    'Data ini hanya tersimpan di sesi ini.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._manualExpenses.asMap().entries.map((entry) {
          final index = entry.key;
          final expense = entry.value;
          return _expenseLineItem(index, expense);
        }),
        if (_totalManualExpenses > 0) ...[
          const Divider(height: 24),
          _lineItem('Total Biaya Operasional', _totalManualExpenses,
              isBold: true, color: AppTheme.warningColor),
        ],
      ],
    );
  }

  Widget _expenseLineItem(int index, ExpenseEntry expense) {
    return InkWell(
      onTap: () => _editExpenseDialog(index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              _expenseIcon(expense.id),
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                expense.category,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              expense.amount > 0
                  ? FormatUtils.currency(expense.amount)
                  : 'Ketuk untuk isi',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: expense.amount > 0 ? FontWeight.w600 : FontWeight.w400,
                color: expense.amount > 0
                    ? AppTheme.textPrimary
                    : AppTheme.textTertiary,
                fontStyle:
                    expense.amount > 0 ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                size: 14, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  IconData _expenseIcon(String id) {
    switch (id) {
      case 'rent':
        return Icons.home_outlined;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'salary':
        return Icons.people_outlined;
      case 'marketing':
        return Icons.campaign_outlined;
      case 'packaging':
        return Icons.inventory_2_outlined;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.receipt_outlined;
    }
  }

  void _editExpenseDialog(int index) {
    final expense = _manualExpenses[index];
    final controller =
        TextEditingController(text: expense.amount > 0 ? expense.amount.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          expense.category,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Jumlah (Rp)',
            labelStyle: GoogleFonts.inter(fontSize: 13),
            prefixText: 'Rp ',
          ),
          onSubmitted: (val) {
            final amount = double.tryParse(val) ?? 0;
            setState(() {
              _manualExpenses[index] = ExpenseEntry(
                id: expense.id,
                category: expense.category,
                amount: amount,
              );
            });
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              setState(() {
                _manualExpenses[index] = ExpenseEntry(
                  id: expense.id,
                  category: expense.category,
                  amount: amount,
                );
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _addExpenseDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Tambah Biaya',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nama Biaya',
                labelStyle: GoogleFonts.inter(fontSize: 13),
                hintText: 'contoh: Internet, Asuransi',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah (Rp)',
                labelStyle: GoogleFonts.inter(fontSize: 13),
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text) ?? 0;
              if (name.isNotEmpty) {
                setState(() {
                  _manualExpenses.add(ExpenseEntry(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    category: name,
                    amount: amount,
                  ));
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  // ── Net Profit Section ────────────────────────────────────────

  Widget _buildNetProfitSection(
      double grossProfit, double netProfit, double netMargin) {
    final isProfit = netProfit >= 0;
    final color = isProfit ? AppTheme.successColor : AppTheme.errorColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Ringkasan Laba Rugi',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _summaryRow('Laba Kotor', grossProfit,
              color: grossProfit >= 0
                  ? AppTheme.successColor
                  : AppTheme.errorColor),
          const SizedBox(height: 8),
          _summaryRow('Total Biaya Operasional', -_totalManualExpenses,
              color: AppTheme.warningColor),
          const Divider(height: 24),
          _summaryRow(
            isProfit ? 'LABA BERSIH' : 'RUGI BERSIH',
            netProfit,
            color: color,
            isBold: true,
            fontSize: 18,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Net Margin: ${netMargin.toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount,
      {Color? color, bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? (color ?? AppTheme.textPrimary) : AppTheme.textPrimary,
          ),
        ),
        Text(
          FormatUtils.currency(amount),
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Breakdown Chart ───────────────────────────────────────────

  Widget _buildBreakdownChart(
      PnlReport report, double grossProfit, double netProfit) {
    if (report.totalRevenue == 0) return const SizedBox.shrink();

    final cogs = report.totalCogs;
    final expenses = _totalManualExpenses;
    final profit = netProfit > 0 ? netProfit : 0.0;
    final loss = netProfit < 0 ? netProfit.abs() : 0.0;

    // Build pie sections
    final sections = <PieChartSectionData>[];
    final legendItems = <_LegendItem>[];

    if (cogs > 0) {
      final pct = (cogs / report.totalRevenue * 100);
      sections.add(PieChartSectionData(
        value: cogs,
        color: AppTheme.errorColor,
        title: '${pct.toStringAsFixed(1)}%',
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 60,
      ));
      legendItems.add(_LegendItem('HPP', cogs, AppTheme.errorColor));
    }

    if (expenses > 0) {
      final pct = (expenses / report.totalRevenue * 100);
      sections.add(PieChartSectionData(
        value: expenses,
        color: AppTheme.warningColor,
        title: '${pct.toStringAsFixed(1)}%',
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 60,
      ));
      legendItems
          .add(_LegendItem('Biaya Operasional', expenses, AppTheme.warningColor));
    }

    if (profit > 0) {
      final pct = (profit / report.totalRevenue * 100);
      sections.add(PieChartSectionData(
        value: profit,
        color: AppTheme.successColor,
        title: '${pct.toStringAsFixed(1)}%',
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 60,
      ));
      legendItems
          .add(_LegendItem('Laba Bersih', profit, AppTheme.successColor));
    }

    if (loss > 0) {
      // Show loss as a portion exceeding 100% in chart context
      final pct = (loss / report.totalRevenue * 100);
      sections.add(PieChartSectionData(
        value: loss,
        color: const Color(0xFFDC2626),
        title: '-${pct.toStringAsFixed(1)}%',
        titleStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 60,
      ));
      legendItems.add(
          _LegendItem('Rugi Bersih', loss, const Color(0xFFDC2626)));
    }

    if (sections.isEmpty) return const SizedBox.shrink();

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
            'Komposisi Pendapatan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: legendItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                FormatUtils.currency(item.amount),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required Color titleColor,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: titleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: titleColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _lineItem(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
    double fontSize = 14,
    bool showBar = false,
    double fraction = 0,
    Color? barColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: fontSize,
                    fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
                    color: isBold ? (color ?? AppTheme.textPrimary) : AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                FormatUtils.currency(amount),
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (showBar && fraction > 0) ...[
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: barColor ?? AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(fraction * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _subSectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  // ── Date Filters ──────────────────────────────────────────────

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

  // ── Label Helpers ─────────────────────────────────────────────

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
      case 'e_wallet':
        return 'E-Wallet';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'card':
        return 'Kartu Debit/Kredit';
      case 'split':
        return 'Split Payment';
      default:
        return FormatUtils.titleCase(method.replaceAll('_', ' '));
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'pos':
        return 'POS (Kasir)';
      case 'self_order':
        return 'Self-Order';
      case 'gofood':
        return 'GoFood';
      case 'grabfood':
        return 'GrabFood';
      case 'shopeefood':
        return 'ShopeeFood';
      default:
        return FormatUtils.titleCase(source.replaceAll('_', ' '));
    }
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'pos':
        return AppTheme.primaryColor;
      case 'self_order':
        return AppTheme.infoColor;
      case 'gofood':
        return AppTheme.successColor;
      case 'grabfood':
        return AppTheme.successColor;
      case 'shopeefood':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  // ── Common Widgets ────────────────────────────────────────────

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

// Private helper for chart legend
class _LegendItem {
  final String label;
  final double amount;
  final Color color;

  _LegendItem(this.label, this.amount, this.color);
}
