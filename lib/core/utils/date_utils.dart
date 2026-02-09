/// Timezone-aware date utilities for Supabase queries.
///
/// Supabase stores timestamps as UTC. When we send a DateTime without timezone
/// info via `.toIso8601String()`, Supabase treats it as UTC — causing a 7-hour
/// offset for Jakarta (UTC+7). This utility ensures all query dates are
/// properly converted to UTC before being sent to Supabase.
class DateTimeUtils {
  DateTimeUtils._();

  /// Convert a local DateTime to UTC ISO 8601 string for Supabase queries.
  /// This is the single most important function — use instead of `.toIso8601String()`.
  static String toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

  /// Get the start of today in the device's local timezone, returned as UTC ISO string.
  static String startOfTodayUtc() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  }

  /// Get the end of today (23:59:59) in the device's local timezone, returned as UTC ISO string.
  static String endOfTodayUtc() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
  }

  /// Get start of a specific date as UTC ISO string.
  static String startOfDayUtc(DateTime date) {
    return DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
  }

  /// Get end of a specific date (23:59:59) as UTC ISO string.
  static String endOfDayUtc(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();
  }

  /// Get start of a specific month as UTC ISO string.
  static String startOfMonthUtc(int year, int month) {
    return DateTime(year, month, 1).toUtc().toIso8601String();
  }

  /// Get current time as UTC ISO string (for write operations).
  static String nowUtc() => DateTime.now().toUtc().toIso8601String();

  /// Convert DateTime for date-only queries (YYYY-MM-DD format, no timezone issue).
  static String toDateOnly(DateTime dt) => dt.toIso8601String().substring(0, 10);
}
