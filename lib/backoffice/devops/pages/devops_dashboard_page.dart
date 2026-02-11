import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/backoffice/devops/widgets/devops_chat_panel.dart';
import 'package:utter_app/backoffice/devops/widgets/system_health_card.dart';

/// DevOps Console - Technical troubleshooting dashboard
///
/// Target users: Developers, System Admins
/// Focus: Backend debugging, database diagnostics, system health
///
/// Separated from Office AI to keep business users focused on operations
/// without technical complexity.
class DevOpsDashboardPage extends ConsumerWidget {
  const DevOpsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Dark blue-gray
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.engineering, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DevOps Console',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Technical Troubleshooting',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Quick status indicators
          _buildQuickStatus(Icons.storage, 'DB', Colors.green),
          const SizedBox(width: 8),
          _buildQuickStatus(Icons.cell_tower, 'RT', Colors.green),
          const SizedBox(width: 16),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildQuickStatus(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: System overview
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System Health Card
                const SystemHealthCard(),

                const SizedBox(height: 16),

                // Quick Actions
                _buildQuickActionsCard(),

                const SizedBox(height: 16),

                // Documentation Links
                _buildDocumentationCard(),
              ],
            ),
          ),
        ),

        const VerticalDivider(width: 1),

        // Right: DevOps AI Chat
        const Expanded(
          flex: 2,
          child: DevOpsChatPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppTheme.surfaceColor,
            child: TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'System'),
                Tab(icon: Icon(Icons.chat), text: 'AI Assistant'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // System tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SystemHealthCard(),
                      const SizedBox(height: 16),
                      _buildQuickActionsCard(),
                    ],
                  ),
                ),
                // AI tab
                const DevOpsChatPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, size: 20, color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionChip(
                Icons.sync,
                'Test DB Connection',
                Colors.blue,
              ),
              _buildActionChip(
                Icons.cell_tower,
                'Check Realtime',
                Colors.purple,
              ),
              _buildActionChip(
                Icons.security,
                'Verify RLS Policies',
                Colors.orange,
              ),
              _buildActionChip(
                Icons.update,
                'Migration Status',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color color) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12),
      ),
      onPressed: () {
        // TODO: Trigger AI action via chat
      },
    );
  }

  Widget _buildDocumentationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Documentation',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDocLink('Supabase Dashboard', 'https://supabase.com/dashboard'),
          _buildDocLink('Database Docs', 'https://supabase.com/docs/guides/database'),
          _buildDocLink('Realtime Guide', 'https://supabase.com/docs/guides/realtime'),
          _buildDocLink('RLS Policies', 'https://supabase.com/docs/guides/auth/row-level-security'),
        ],
      ),
    );
  }

  Widget _buildDocLink(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
          const Spacer(),
          const Icon(Icons.open_in_new, size: 14, color: AppTheme.textTertiary),
        ],
      ),
    );
  }
}
