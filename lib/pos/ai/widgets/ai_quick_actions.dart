import 'package:flutter/material.dart';

import 'package:luwa_app/shared/themes/app_theme.dart';

/// Quick Action definition.
class _QuickAction {
  final IconData icon;
  final String label;
  final String message;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.message,
  });
}

/// AI Quick Actions
///
/// A horizontally scrollable row of pre-defined quick action chips.
/// Tapping a chip sends the corresponding question / command as a
/// chat message to the AI assistant.
class AiQuickActions extends StatelessWidget {
  /// Callback that receives the quick action text to send as a message.
  final ValueChanged<String> onActionTap;

  /// Optional list of extra quick actions to show alongside the defaults.
  final List<QuickActionItem>? extraActions;

  const AiQuickActions({
    super.key,
    required this.onActionTap,
    this.extraActions,
  });

  /// Default quick actions in Bahasa Indonesia.
  static const List<_QuickAction> _defaultActions = [
    _QuickAction(
      icon: Icons.show_chart,
      label: 'Sales hari ini',
      message: 'Berapa sales hari ini?',
    ),
    _QuickAction(
      icon: Icons.inventory_2_outlined,
      label: 'Cek stok rendah',
      message: 'Cek stok rendah',
    ),
    _QuickAction(
      icon: Icons.emoji_events_outlined,
      label: 'Produk terlaris',
      message: 'Produk terlaris minggu ini',
    ),
    _QuickAction(
      icon: Icons.summarize_outlined,
      label: 'Ringkasan shift',
      message: 'Ringkasan shift',
    ),
    _QuickAction(
      icon: Icons.report_problem_outlined,
      label: 'Anomali hari ini?',
      message: 'Ada anomali hari ini?',
    ),
    _QuickAction(
      icon: Icons.price_change_outlined,
      label: 'Saran harga',
      message: 'Saran harga produk',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Merge default actions with any extra actions.
    final allActions = <Widget>[
      ..._defaultActions.map((action) => _buildChip(
            context: context,
            icon: action.icon,
            label: action.label,
            onTap: () => onActionTap(action.message),
            isDark: isDark,
          )),
      if (extraActions != null)
        ...extraActions!.map((action) => _buildChip(
              context: context,
              icon: action.icon,
              label: action.label,
              onTap: () => onActionTap(action.message),
              isDark: isDark,
            )),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: allActions
              .expand((chip) => [
                    chip,
                    const SizedBox(width: AppTheme.spacingS),
                  ])
              .toList()
            ..removeLast(), // Remove trailing spacer.
        ),
      ),
    );
  }

  /// Build a single quick action chip.
  Widget _buildChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: AppTheme.aiPrimary,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      onPressed: onTap,
      backgroundColor: isDark
          ? AppTheme.aiPrimary.withValues(alpha: 0.12)
          : AppTheme.aiBackground,
      side: BorderSide(
        color: isDark
            ? AppTheme.aiPrimary.withValues(alpha: 0.25)
            : AppTheme.aiPrimary.withValues(alpha: 0.15),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Public quick action item for custom / contextual suggestions.
class QuickActionItem {
  final IconData icon;
  final String label;
  final String message;

  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.message,
  });
}
