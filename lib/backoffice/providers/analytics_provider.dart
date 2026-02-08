import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/analytics_repository.dart';
import 'report_provider.dart'; // for DateRange

const _outletId = 'a0000000-0000-0000-0000-000000000001';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

/// Peak hours analysis (last 30 days)
final peakHoursProvider = FutureProvider<List<PeakHourData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getPeakHours(_outletId);
});

/// Day of week analysis (last 30 days)
final dayOfWeekProvider = FutureProvider<List<DayOfWeekData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getDayOfWeekAnalysis(_outletId);
});

/// Top customers (by total_spent)
final topCustomersProvider =
    FutureProvider<List<TopCustomerData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTopCustomers(_outletId, limit: 10);
});

/// Product performance / ABC analysis (keyed by date range)
final productPerformanceProvider = FutureProvider.family<
    List<ProductPerformanceData>, DateRange>((ref, range) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getProductPerformance(_outletId, range.from, range.to);
});

/// Order source breakdown (keyed by date range)
final orderSourceProvider =
    FutureProvider.family<List<OrderSourceData>, DateRange>(
        (ref, range) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getOrderSourceBreakdown(_outletId, range.from, range.to);
});

/// Average order value trend (last 30 days)
final aovTrendProvider = FutureProvider<List<AovTrendData>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getAovTrend(_outletId);
});

/// Customer retention analysis
final customerRetentionProvider =
    FutureProvider<CustomerRetentionData>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getCustomerRetention(_outletId);
});

/// Staff performance (keyed by date range)
final staffPerformanceProvider =
    FutureProvider.family<List<StaffPerformanceData>, DateRange>(
        (ref, range) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getStaffPerformance(_outletId, range.from, range.to);
});
