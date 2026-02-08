import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/core/providers/ai/ai_insight_provider.dart';
import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/backoffice/ai/pages/ai_dashboard_page.dart';
import 'package:utter_app/backoffice/ai/pages/ai_action_log_page.dart';
import 'package:utter_app/backoffice/ai/pages/ai_settings_page.dart';
import 'package:utter_app/backoffice/ai/pages/ai_conversation_history.dart';

/// AI section for the Back Office sidebar menu.
///
/// Displays a collapsible section with navigation items
/// for all AI-related pages, including an unread badge on Insights.
class AiSidebarWidget extends ConsumerWidget {
  /// The currently active route, used to highlight the active item.
  final String? activeRoute;

  /// Callback when a navigation item is selected.
  final ValueChanged<Widget>? onNavigate;

  const AiSidebarWidget({
    super.key,
    this.activeRoute,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(aiInsightUnreadCountProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.aiPrimary, AppTheme.aiSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: const Icon(
            Icons.psychology,
            size: 18,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Utter AI',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: 0,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AppTheme.spacingS,
          bottom: AppTheme.spacingS,
        ),
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          _SidebarItem(
            icon: Icons.insights,
            label: 'Insights & Chat',
            badgeCount: unreadCount,
            isActive: activeRoute == 'ai_dashboard',
            onTap: () {
              onNavigate?.call(const AiDashboardPage());
            },
          ),
          _SidebarItem(
            icon: Icons.history,
            label: 'Action Log',
            isActive: activeRoute == 'ai_action_log',
            onTap: () {
              onNavigate?.call(const AiActionLogPage());
            },
          ),
          _SidebarItem(
            icon: Icons.tune,
            label: 'AI Settings',
            isActive: activeRoute == 'ai_settings',
            onTap: () {
              onNavigate?.call(const AiSettingsPage());
            },
          ),
          _SidebarItem(
            icon: Icons.forum_outlined,
            label: 'Riwayat Chat',
            isActive: activeRoute == 'ai_conversation_history',
            onTap: () {
              onNavigate?.call(const AiConversationHistory());
            },
          ),
        ],
      ),
    );
  }
}

/// A single sidebar navigation item with optional badge.
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS + 2,
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.aiPrimary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? AppTheme.aiPrimary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppTheme.aiPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
