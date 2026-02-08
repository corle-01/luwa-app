import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/prediction_repository.dart';

final predictionRepositoryProvider =
    Provider((ref) => PredictionRepository());

/// Historical daily sales data (last 30 days)
final dailySalesTrendProvider =
    FutureProvider<List<DailySalesPoint>>((ref) async {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(predictionRepositoryProvider);
  return repo.getDailySalesTrend(outletId, days: 30);
});

/// Sales forecast: historical + predicted next 7 days
final salesForecastProvider =
    FutureProvider<List<PredictionPoint>>((ref) async {
  final repo = ref.watch(predictionRepositoryProvider);
  final historical = await ref.watch(dailySalesTrendProvider.future);
  return repo.predictNextDays(historical, daysToPredict: 7);
});

/// Product demand trends (last 30 days per product)
final productDemandTrendsProvider =
    FutureProvider<Map<String, List<ProductDemandPoint>>>((ref) async {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(predictionRepositoryProvider);
  return repo.getProductDemandTrends(outletId, days: 30);
});

/// Top 10 product demand forecasts
final productDemandForecastsProvider =
    FutureProvider<List<ProductDemandForecast>>((ref) async {
  final repo = ref.watch(predictionRepositoryProvider);
  final trends = await ref.watch(productDemandTrendsProvider.future);
  return repo.getProductDemandForecasts(trends, topN: 10);
});

/// Restock suggestions based on sales velocity
final restockSuggestionsProvider =
    FutureProvider<List<RestockSuggestion>>((ref) async {
  final outletId = ref.watch(currentOutletIdProvider);
  final repo = ref.watch(predictionRepositoryProvider);
  return repo.getRestockSuggestions(outletId, lookbackDays: 14);
});

/// Day of week predictions
final dayOfWeekPredictionsProvider =
    FutureProvider<List<DayOfWeekPrediction>>((ref) async {
  final repo = ref.watch(predictionRepositoryProvider);
  final historical = await ref.watch(dailySalesTrendProvider.future);
  return repo.getDayOfWeekPredictions(historical);
});

/// Overall prediction summary
final predictionSummaryProvider =
    FutureProvider<PredictionSummary>((ref) async {
  final repo = ref.watch(predictionRepositoryProvider);
  final historical = await ref.watch(dailySalesTrendProvider.future);
  final predictions = await ref.watch(salesForecastProvider.future);
  final restock = await ref.watch(restockSuggestionsProvider.future);
  final dowPredictions =
      await ref.watch(dayOfWeekPredictionsProvider.future);

  return repo.buildSummary(
    historical: historical,
    predictions: predictions,
    restockSuggestions: restock,
    dowPredictions: dowPredictions,
  );
});
