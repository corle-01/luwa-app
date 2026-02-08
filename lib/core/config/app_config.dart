import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App Configuration - loads from .env on native, hardcoded defaults on web
class AppConfig {
  static Map<String, String> _env = {};

  // Supabase
  static String get supabaseUrl =>
      _env['SUPABASE_URL'] ?? 'https://eavsygnrluburvrobvoj.supabase.co';
  static String get supabaseAnonKey =>
      _env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhdnN5Z25ybHVidXJ2cm9idm9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzNzM3MzAsImV4cCI6MjA4NTk0OTczMH0.L9K1RkRPZkDudYLRl-FhxMFuDibU_2Rj622Svx87Hc8';
  static String get supabaseServiceRoleKey =>
      _env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  // DeepSeek AI
  static String get deepseekApiKey => _env['DEEPSEEK_API_KEY'] ?? '';

  // App
  static String get appName => _env['APP_NAME'] ?? 'Utter App';
  static String get appVersion => _env['APP_VERSION'] ?? '1.0.0';
  static String get environment => _env['ENVIRONMENT'] ?? 'development';

  // Computed
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Initialize configuration
  static Future<void> initialize() async {
    // Skip dotenv on web — .env asset not available on GitHub Pages
    // and rootBundle.loadString throws uncatchable error in release JS
    if (kIsWeb) {
      _env = {};
      return;
    }
    try {
      await dotenv.load(fileName: '.env');
      _env = dotenv.env;
    } catch (_) {
      _env = {};
    }
  }
}
