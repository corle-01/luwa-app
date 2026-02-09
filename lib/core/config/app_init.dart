import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_config.dart';

/// Shared initialization for all app entry points (POS, Office, Kitchen).
Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    initializeDateFormatting('id_ID', null),
    AppConfig.initialize(),
  ]);

  final supabaseKey = AppConfig.isDevelopment &&
          AppConfig.supabaseServiceRoleKey.isNotEmpty &&
          !AppConfig.supabaseServiceRoleKey.startsWith('your-')
      ? AppConfig.supabaseServiceRoleKey
      : AppConfig.supabaseAnonKey;

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: supabaseKey,
  );

  // Disable runtime font fetching — falls back to system fonts instantly
  GoogleFonts.config.allowRuntimeFetching = false;
}
