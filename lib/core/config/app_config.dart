import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App Configuration
///
/// Priority order:
/// 1. --dart-define at compile time (for CI/CD builds)
/// 2. .env file at runtime (for local development)
/// 3. Empty string fallback (app won't work without proper config)
class AppConfig {
  static Map<String, String> _env = {};

  // --dart-define values (baked in at compile time)
  static const _defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _defineDeepseekApiKey = String.fromEnvironment('DEEPSEEK_API_KEY');
  static const _defineTelegramBotToken = String.fromEnvironment('TELEGRAM_BOT_TOKEN');
  static const _defineEnvironment = String.fromEnvironment('ENVIRONMENT');

  // Supabase
  static String get supabaseUrl =>
      _defineSupabaseUrl.isNotEmpty ? _defineSupabaseUrl : (_env['SUPABASE_URL'] ?? '');
  static String get supabaseAnonKey =>
      _defineSupabaseAnonKey.isNotEmpty ? _defineSupabaseAnonKey : (_env['SUPABASE_ANON_KEY'] ?? '');
  static String get supabaseServiceRoleKey =>
      _env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  // DeepSeek AI
  static String get deepseekApiKey =>
      _defineDeepseekApiKey.isNotEmpty ? _defineDeepseekApiKey : (_env['DEEPSEEK_API_KEY'] ?? '');

  // Telegram Bot
  static String get telegramBotToken =>
      _defineTelegramBotToken.isNotEmpty ? _defineTelegramBotToken : (_env['TELEGRAM_BOT_TOKEN'] ?? '');

  // App
  static String get appName => _env['APP_NAME'] ?? 'Utter App';
  static String get appVersion => _env['APP_VERSION'] ?? '1.0.0';
  static String get environment =>
      _defineEnvironment.isNotEmpty ? _defineEnvironment : (_env['ENVIRONMENT'] ?? 'development');

  // Computed
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Initialize configuration
  static Future<void> initialize() async {
    // On web, --dart-define is the primary source (baked at compile time).
    // Skip dotenv on web — .env asset not available on GitHub Pages
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
