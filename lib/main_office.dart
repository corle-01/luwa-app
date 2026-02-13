import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_init.dart';
import 'core/providers/theme_provider.dart';
import 'shared/themes/app_theme.dart';
import 'backoffice/pages/backoffice_shell.dart';
import 'self_order/pages/self_order_shell.dart';

void main() async {
  await initializeApp();
  runApp(const ProviderScope(child: OfficeApp()));
}

class OfficeApp extends ConsumerWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Haru Office',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        // Self-order route: /#/self-order?table=TABLE_ID
        if (uri.path == '/self-order') {
          final tableId = uri.queryParameters['table'];
          return MaterialPageRoute(
            builder: (_) => SelfOrderShell(tableId: tableId),
          );
        }

        // Default: Back Office
        return MaterialPageRoute(
          builder: (_) => const BackOfficeShell(),
        );
      },
    );
  }
}
