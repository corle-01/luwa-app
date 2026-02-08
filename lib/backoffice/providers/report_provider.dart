import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/report_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

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
  return repo.getSalesReport(_outletId, range.from, range.to);
});

/// Top products provider (keyed by date range)
final topProductsProvider =
    FutureProvider.family<List<TopProduct>, DateRange>((ref, range) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTopProducts(_outletId, range.from, range.to);
});

/// Hourly sales provider (keyed by a single date)
final hourlySalesProvider =
    FutureProvider.family<List<HourlySales>, DateTime>((ref, date) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getHourlySales(_outletId, date);
});
