import 'package:intl/intl.dart';
import '../../core/config/app_constants.dart';

/// Utility class for formatting data
class FormatUtils {
  /// Format currency to IDR format
  /// Example: 25000 -> "Rp 25.000"
  static String currency(num amount, {bool withSymbol = true}) {
    final formatter = NumberFormat('#,##0', AppConstants.locale);
    final formatted = formatter.format(amount).replaceAll(',', '.');

    return withSymbol ? '${AppConstants.currencySymbol} $formatted' : formatted;
  }

  /// Format compact currency
  /// Example: 1500000 -> "Rp 1,5jt"
  static String currencyCompact(num amount) {
    if (amount >= 1000000) {
      return '${AppConstants.currencySymbol} ${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${AppConstants.currencySymbol} ${(amount / 1000).toStringAsFixed(1)}rb';
    } else {
      return currency(amount);
    }
  }

  /// Format date to display format
  /// Example: 2026-02-06 -> "06 Feb 2026"
  static String date(DateTime date, {String? format}) {
    final formatter =
        DateFormat(format ?? AppConstants.dateFormatDisplay, 'id_ID');
    return formatter.format(date);
  }

  /// Format datetime to display format
  /// Example: 2026-02-06 14:30 -> "06 Feb 2026 14:30"
  static String dateTime(DateTime dateTime, {String? format}) {
    final formatter =
        DateFormat(format ?? AppConstants.dateTimeFormatDisplay, 'id_ID');
    return formatter.format(dateTime);
  }

  /// Format time to display format
  /// Example: 14:30:00 -> "14:30"
  static String time(DateTime time, {String? format}) {
    final formatter =
        DateFormat(format ?? AppConstants.timeFormatDisplay, 'id_ID');
    return formatter.format(time);
  }

  /// Format date to API format
  /// Example: 2026-02-06 -> "2026-02-06"
  static String dateForApi(DateTime date) {
    return DateFormat(AppConstants.dateFormatApi).format(date);
  }

  /// Parse date from API format
  /// Example: "2026-02-06" -> DateTime
  static DateTime? parseDateFromApi(String dateStr) {
    try {
      return DateFormat(AppConstants.dateFormatApi).parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Format relative time
  /// Example: "2 jam yang lalu", "kemarin", "minggu lalu"
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} minggu yang lalu';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} bulan yang lalu';
    } else {
      return '${(difference.inDays / 365).floor()} tahun yang lalu';
    }
  }

  /// Format phone number
  /// Example: "081234567890" -> "0812-3456-7890"
  static String phone(String phone) {
    if (phone.length < 10) return phone;

    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 11) {
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 12) {
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
    }
    return cleaned;
  }

  /// Format percentage
  /// Example: 0.125 -> "12,5%"
  static String percentage(double value, {int decimals = 1}) {
    final percentage = value * 100;
    return '${percentage.toStringAsFixed(decimals)}%';
  }

  /// Format number with thousand separator
  /// Example: 1234567 -> "1.234.567"
  static String number(num value, {int decimals = 0}) {
    final formatter = NumberFormat('#,##0${decimals > 0 ? '.${'0' * decimals}' : ''}', AppConstants.locale);
    return formatter.format(value).replaceAll(',', '.');
  }

  /// Format duration
  /// Example: Duration(hours: 2, minutes: 30) -> "2 jam 30 menit"
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours jam $minutes menit';
    } else if (hours > 0) {
      return '$hours jam';
    } else if (minutes > 0) {
      return '$minutes menit';
    } else {
      return '${duration.inSeconds} detik';
    }
  }

  /// Format file size
  /// Example: 1536 -> "1,5 KB"
  static String fileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Truncate text
  /// Example: "Long text here..." -> "Long text..."
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}$suffix';
  }

  /// Capitalize first letter
  /// Example: "hello world" -> "Hello world"
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Title case
  /// Example: "hello world" -> "Hello World"
  static String titleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty ? '' : capitalize(word))
        .join(' ');
  }
}
