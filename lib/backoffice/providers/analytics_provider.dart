import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/analytics_repository.dart';
import 'report_provider.dart'; // for DateRange

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

/// Peak hours analysis (last 30 days)
final peakHoursProvider = FutureProvider<List<PeakHourData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getPeakHours(outletId);
});

/// Day of week analysis (last 30 days)
final dayOfWeekProvider = FutureProvider<List<DayOfWeekData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getDayOfWeekAnalysis(outletId);
});

/// Top customers (by total_spent)
final topCustomersProvider =
    FutureProvider<List<TopCustomerData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getTopCustomers(outletId, limit: 10);
});

/// Product performance / ABC analysis (keyed by date range)
final productPerformanceProvider = FutureProvider.family<
    List<ProductPerformanceData>, DateRange>((ref, range) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getProductPerformance(outletId, range.from, range.to);
});

/// Order source breakdown (keyed by date range)
final orderSourceProvider =
    FutureProvider.family<List<OrderSourceData>, DateRange>(
        (ref, range) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getOrderSourceBreakdown(outletId, range.from, range.to);
});

/// Average order value trend (last 30 days)
final aovTrendProvider = FutureProvider<List<AovTrendData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getAovTrend(outletId);
});

/// Customer retention analysis
final customerRetentionProvider =
    FutureProvider<CustomerRetentionData>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getCustomerRetention(outletId);
});

/// Staff performance (keyed by date range)
final staffPerformanceProvider =
    FutureProvider.family<List<StaffPerformanceData>, DateRange>(
        (ref, range) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final outletId = ref.watch(currentOutletIdProvider);
  return repo.getStaffPerformance(outletId, range.from, range.to);
});
