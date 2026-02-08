import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_memory_service.dart';

/// PERASAAN - AI Prediction & Emotional Intelligence Service
///
/// Provides business predictions, mood assessment, and proactive warnings.
/// This is the "emotional" layer of the AI persona system - it reads the
/// pulse of the business and provides forward-looking intelligence.
class AiPredictionService {
  final SupabaseClient _client;
  final String _outletId;

  AiPredictionService({
    SupabaseClient? client,
    String outletId = 'a0000000-0000-0000-0000-000000000001',
  })  : _client = client ?? Supabase.instance.client,
        _outletId = outletId;

  /// Assess the current business mood based on today's performance
  /// compared to historical averages.
  Future<BusinessMoodData> assessBusinessMood() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get today's orders
      final todayOrders = await _client
          .from('orders')
          .select('total, status, created_at')
          .eq('outlet_id', _outletId)
          .gte('created_at', startOfDay.toIso8601String())
          .eq('status', 'completed');

      final todayList = List<Map<String, dynamic>>.from(todayOrders);
      double todayRevenue = 0;
      for (final o in todayList) {
        todayRevenue += (o['total'] as num?)?.toDouble() ?? 0;
      }
      final todayOrderCount = todayList.length;

      // Get last 7 days average (excluding today)
      final weekAgo = now.subtract(const Duration(days: 7));
      final yesterday = DateTime(now.year, now.month, now.day);

      final historicalOrders = await _client
          .from('orders')
          .select('total, status, created_at')
          .eq('outlet_id', _outletId)
          .gte('created_at', weekAgo.toIso8601String())
          .lt('created_at', yesterday.toIso8601String())
          .eq('status', 'completed');

      final histList = List<Map<String, dynamic>>.from(historicalOrders);
      double histRevenue = 0;
      for (final o in histList) {
        histRevenue += (o['total'] as num?)?.toDouble() ?? 0;
      }

      // Average daily revenue over last 7 days
      final avgDailyRevenue = histList.isNotEmpty ? histRevenue / 7 : 0.0;
      final avgDailyOrders = histList.isNotEmpty ? histList.length / 7 : 0.0;

      // Calculate how far through the day we are to project full-day performance
      final hoursPassed = now.hour + (now.minute / 60);
      final businessHoursTotal = 14.0; // Assume 8am - 10pm
      final businessHoursElapsed = (hoursPassed - 8).clamp(0, businessHoursTotal);
      final dayProgress = businessHoursElapsed / businessHoursTotal;

      // Project today's full revenue (if dayProgress > 0)
      final projectedRevenue = dayProgress > 0.1
          ? todayRevenue / dayProgress
          : todayRevenue;

      // Determine mood
      BusinessMood mood;
      String moodText;
      String moodEmoji;

      if (avgDailyRevenue == 0) {
        mood = BusinessMood.steady;
        moodText = 'Belum cukup data historis untuk perbandingan';
        moodEmoji = '--';
      } else {
        final ratio = projectedRevenue / avgDailyRevenue;

        if (ratio >= 1.3) {
          mood = BusinessMood.thriving;
          moodText = 'Hari luar biasa! Proyeksi ${(ratio * 100).toStringAsFixed(0)}% dari rata-rata';
          moodEmoji = 'thriving';
        } else if (ratio >= 1.05) {
          mood = BusinessMood.good;
          moodText = 'Hari yang bagus, di atas rata-rata ${(ratio * 100).toStringAsFixed(0)}%';
          moodEmoji = 'good';
        } else if (ratio >= 0.85) {
          mood = BusinessMood.steady;
          moodText = 'Hari normal, sesuai rata-rata';
          moodEmoji = 'steady';
        } else if (ratio >= 0.6) {
          mood = BusinessMood.slow;
          moodText = 'Hari agak lambat, ${(ratio * 100).toStringAsFixed(0)}% dari rata-rata';
          moodEmoji = 'slow';
        } else {
          mood = BusinessMood.concerned;
          moodText = 'Hari sepi. Pertimbangkan promo atau review operasional';
          moodEmoji = 'concerned';
        }
      }

      // Check for warnings
      final warnings = <String>[];

      // Low stock warning
      final lowStockItems = await _getLowStockItems();
      if (lowStockItems.isNotEmpty) {
        warnings.add('${lowStockItems.length} bahan baku stok menipis: ${lowStockItems.take(3).join(", ")}');
      }

      // No orders warning (if past lunch hour and no orders)
      if (now.hour >= 11 && todayOrderCount == 0) {
        warnings.add('Belum ada order hari ini setelah jam ${now.hour}:00');
      }

      return BusinessMoodData(
        mood: mood,
        moodText: moodText,
        moodEmoji: moodEmoji,
        todayRevenue: todayRevenue,
        todayOrders: todayOrderCount,
        projectedRevenue: projectedRevenue,
        avgDailyRevenue: avgDailyRevenue,
        avgDailyOrders: avgDailyOrders.round(),
        dayProgress: dayProgress,
        warnings: warnings,
      );
    } catch (e) {
      return BusinessMoodData(
        mood: BusinessMood.steady,
        moodText: 'Tidak bisa menilai mood bisnis: $e',
        moodEmoji: 'steady',
      );
    }
  }

  /// Generate predictions for today based on historical patterns.
  Future<BusinessPrediction> generatePredictions() async {
    try {
      final now = DateTime.now();
      final isWeekend = now.weekday >= 6;
      final dayType = isWeekend ? 'weekend' : 'weekday';

      // Get historical order times (same day type, last 4 weeks)
      final fourWeeksAgo = now.subtract(const Duration(days: 28));

      final historicalOrders = await _client
          .from('orders')
          .select('total, created_at, order_items(product_name, quantity)')
          .eq('outlet_id', _outletId)
          .gte('created_at', fourWeeksAgo.toIso8601String())
          .eq('status', 'completed');

      final orderList = List<Map<String, dynamic>>.from(historicalOrders);

      // Filter to same day type
      final sameDayTypeOrders = orderList.where((o) {
        final orderDate = DateTime.parse(o['created_at'] as String);
        final orderIsWeekend = orderDate.weekday >= 6;
        return orderIsWeekend == isWeekend;
      }).toList();

      // Calculate hourly distribution
      final hourlyCounts = <int, int>{};
      double totalRevenue = 0;
      int totalDays = 0;

      // Count unique days
      final uniqueDays = <String>{};
      for (final o in sameDayTypeOrders) {
        final orderDate = DateTime.parse(o['created_at'] as String);
        final dateStr = '${orderDate.year}-${orderDate.month}-${orderDate.day}';
        uniqueDays.add(dateStr);

        final hour = orderDate.hour;
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
        totalRevenue += (o['total'] as num?)?.toDouble() ?? 0;
      }
      totalDays = uniqueDays.length;

      // Predict busy hours (top 4 hours by order count)
      final sortedHours = hourlyCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final predictedBusyHours = sortedHours
          .take(4)
          .map((e) => e.key)
          .toList()
        ..sort();

      // Estimated revenue
      final estimatedRevenue = totalDays > 0 ? totalRevenue / totalDays : 0.0;

      // Stock warnings
      final stockWarnings = await _getLowStockItems();

      // Build forecast text
      final buffer = StringBuffer();
      if (totalDays == 0) {
        buffer.write('Belum cukup data historis untuk prediksi akurat. ');
      } else {
        buffer.write('Berdasarkan data ${totalDays} $dayType terakhir: ');
        if (predictedBusyHours.isNotEmpty) {
          final busyStr = predictedBusyHours.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', ');
          buffer.write('Jam sibuk diperkirakan $busyStr. ');
        }
        buffer.write('Estimasi pendapatan ~Rp ${_formatCurrency(estimatedRevenue)}. ');
        if (isWeekend) {
          buffer.write('Weekend biasanya lebih ramai. ');
        }
      }
      if (stockWarnings.isNotEmpty) {
        buffer.write('Perhatian: ${stockWarnings.length} bahan perlu restock.');
      }

      return BusinessPrediction(
        predictedBusyHours: predictedBusyHours,
        estimatedRevenue: estimatedRevenue,
        stockWarnings: stockWarnings,
        forecastText: buffer.toString(),
        dayType: dayType,
      );
    } catch (e) {
      return BusinessPrediction(
        forecastText: 'Tidak bisa membuat prediksi: $e',
        dayType: 'weekday',
      );
    }
  }

  /// Build prediction context string for the AI system prompt.
  Future<String> buildPredictionContext() async {
    try {
      final mood = await assessBusinessMood();
      final prediction = await generatePredictions();

      final buffer = StringBuffer();
      buffer.writeln('');
      buffer.writeln('PERASAAN (Mood & Prediksi Bisnis):');
      buffer.writeln('- Mood hari ini: ${mood.moodText}');
      buffer.writeln('- Revenue hari ini: Rp ${_formatCurrency(mood.todayRevenue)} (${mood.todayOrders} order)');
      if (mood.projectedRevenue > 0 && mood.dayProgress > 0.1) {
        buffer.writeln('- Proyeksi full day: Rp ${_formatCurrency(mood.projectedRevenue)}');
      }
      buffer.writeln('- Rata-rata harian: Rp ${_formatCurrency(mood.avgDailyRevenue)} (${mood.avgDailyOrders} order)');

      if (prediction.predictedBusyHours.isNotEmpty) {
        final busyStr = prediction.predictedBusyHours
            .map((h) => '${h.toString().padLeft(2, '0')}:00')
            .join(', ');
        buffer.writeln('- Prediksi jam sibuk: $busyStr');
      }

      if (mood.warnings.isNotEmpty) {
        buffer.writeln('- PERINGATAN:');
        for (final w in mood.warnings) {
          buffer.writeln('  * $w');
        }
      }

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Get low stock item names.
  Future<List<String>> _getLowStockItems() async {
    try {
      final response = await _client
          .from('ingredients')
          .select('name, current_stock, min_stock')
          .eq('outlet_id', _outletId);

      final items = List<Map<String, dynamic>>.from(response);
      return items
          .where((i) {
            final current = (i['current_stock'] as num?)?.toDouble() ?? 0;
            final min = (i['min_stock'] as num?)?.toDouble() ?? 0;
            return current <= min;
          })
          .map((i) => i['name'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toStringAsFixed(0);
  }
}

/// Data class for business mood assessment results.
class BusinessMoodData {
  final BusinessMood mood;
  final String moodText;
  final String moodEmoji;
  final double todayRevenue;
  final int todayOrders;
  final double projectedRevenue;
  final double avgDailyRevenue;
  final int avgDailyOrders;
  final double dayProgress;
  final List<String> warnings;

  const BusinessMoodData({
    required this.mood,
    required this.moodText,
    required this.moodEmoji,
    this.todayRevenue = 0,
    this.todayOrders = 0,
    this.projectedRevenue = 0,
    this.avgDailyRevenue = 0,
    this.avgDailyOrders = 0,
    this.dayProgress = 0,
    this.warnings = const [],
  });
}
