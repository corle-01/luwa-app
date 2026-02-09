import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_init.dart';
import 'shared/themes/app_theme.dart';
import 'kds/pages/kds_page.dart';

void main() async {
  await initializeApp();
  runApp(const ProviderScope(child: KitchenApp()));
}

class KitchenApp extends StatelessWidget {
  const KitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Utter Kitchen',
      debugShowCheckedModeBanner: false,
      // KDS always uses dark theme
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const KdsPage(),
    );
  }
}
