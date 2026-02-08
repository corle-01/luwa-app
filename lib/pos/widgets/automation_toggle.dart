import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/pos_automation_provider.dart';

class AutomationToggle extends ConsumerWidget {
  const AutomationToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuto = ref.watch(posAutomationProvider);

    return GestureDetector(
      onTap: () => ref.read(posAutomationProvider.notifier).toggle(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAuto
              ? AppTheme.successColor.withValues(alpha: 0.1)
              : AppTheme.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAuto ? AppTheme.successColor : AppTheme.accentColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAuto ? Icons.auto_mode : Icons.touch_app,
              size: 16,
              color: isAuto ? AppTheme.successColor : AppTheme.accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              isAuto ? 'AUTO' : 'MANUAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isAuto ? AppTheme.successColor : AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
