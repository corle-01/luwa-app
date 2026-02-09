import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_init.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/realtime_sync_service.dart';
import 'shared/themes/app_theme.dart';
import 'pos/pages/pos_main_page.dart';

void main() async {
  await initializeApp();
  runApp(const ProviderScope(child: PosApp()));
}

class PosApp extends ConsumerWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep Supabase Realtime active for live data sync
    ref.watch(realtimeSyncProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Utter POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const PosMainPage(),
    );
  }
}
