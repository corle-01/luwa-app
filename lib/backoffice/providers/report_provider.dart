import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/report_repository.dart';

final reportRepositoryProvider = Provider((ref) => ReportRepository());

/// Date range parameter for report queries
class DateRange {
  final DateTime from;
  final DateTime to;

  const DateRange({required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          from.isAtSameMomentAs(other.from) &&
          to.isAtSameMomentAs(other.to);

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

/// Sales report provider (keyed by date range)
final salesReportProvider =
    FutureProvider.family<SalesReport, DateRange>((ref, range) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getSalesReport(outletId, range.from, range.to);
});

/// Top products provider (keyed by date range)
final topProductsProvider =
    FutureProvider.family<List<TopProduct>, DateRange>((ref, range) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTopProducts(outletId, range.from, range.to);
});

/// Hourly sales provider (keyed by a single date)
final hourlySalesProvider =
    FutureProvider.family<List<HourlySales>, DateTime>((ref, date) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getHourlySales(outletId, date);
});

/// HPP (COGS) report provider (keyed by date range)
final hppReportProvider =
    FutureProvider.family<HppSummary, DateRange>((ref, range) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getHppReport(outletId, range.from, range.to);
});

/// P&L (Profit & Loss) report provider (keyed by date range)
final pnlReportProvider =
    FutureProvider.family<PnlReport, DateRange>((ref, range) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getPnlReport(outletId, range.from, range.to);
});

/// Monthly sales data provider (last 6 months)
final monthlySalesProvider = FutureProvider<List<MonthlySalesData>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getMonthlySales(outletId, months: 6);
});

/// Growth metrics provider (current vs previous month)
final growthMetricsProvider = FutureProvider<GrowthMetrics>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getGrowthMetrics(outletId);
});
