import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/core/providers/ai/ai_insight_provider.dart';
import 'package:luwa_app/core/providers/ai/ai_action_log_provider.dart';
import 'package:luwa_app/core/providers/ai/ai_trust_provider.dart';
import 'package:luwa_app/core/providers/ai/ai_persona_provider.dart';
import 'package:luwa_app/core/providers/ai/ai_chat_provider.dart';
import 'package:luwa_app/core/providers/outlet_provider.dart';
import 'package:luwa_app/core/services/ai/ai_memory_service.dart';
import 'package:luwa_app/core/services/ai/ai_prediction_service.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';
import 'package:luwa_app/shared/utils/format_utils.dart';
import 'package:luwa_app/shared/widgets/luwa_avatar.dart';
import 'package:luwa_app/shared/widgets/avatar_chat_overlay.dart';
import 'package:luwa_app/backoffice/ai/providers/bo_ai_provider.dart';
import 'package:luwa_app/backoffice/ai/widgets/insight_card.dart';
import 'package:luwa_app/backoffice/ai/widgets/pending_approval_card.dart';
import 'package:luwa_app/backoffice/ai/widgets/action_log_row.dart';
import 'package:luwa_app/backoffice/ai/widgets/undo_banner.dart';
import 'package:luwa_app/backoffice/ai/pages/ai_settings_page.dart';

/// The main AI Dashboard page for the Back Office.
///
/// Full-width dashboard with floating avatar overlay for chat.
/// - OTAK (Memory): Stored insights from conversations
/// - Action Center: Chat via floating avatar overlay
/// - Business Intelligence: Business mood, forecasts, warnings
class AiDashboardPage extends ConsumerStatefulWidget {
  const AiDashboardPage({super.key});

  @override
  ConsumerState<AiDashboardPage> createState() => _AiDashboardPageState();
}

class _AiDashboardPageState extends ConsumerState<AiDashboardPage> {
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    // Load persona data on init
    Future.microtask(() {
      ref.read(aiPersonaProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final undoableLogs = ref.watch(aiUndoableActionsProvider);
    final isLoading = ref.watch(aiChatLoadingProvider);
    final unreadCount = ref.watch(aiInsightUnreadCountProvider);
    final outletId = ref.watch(currentOutletIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Top bar with mood indicator
              _buildTopBar(context),

              // Undo banners
              ...undoableLogs.take(1).map((log) {
                return UndoBanner(
                  actionDescription: log.actionDescription,
                  undoDeadline: log.undoDeadline!,
                  onUndo: () {
                    ref
                        .read(aiActionLogProvider.notifier)
                        .undoAction(log.id);
                  },
                );
              }),

              // Main content - full width dashboard
              Expanded(child: _buildDashboardContent()),

              // Bottom status bar
              _buildStatusBar(),
            ],
          ),

          // Floating AI Avatar button (bottom-right)
          if (!_chatOpen)
            Positioned(
              bottom: 64,
              right: 24,
              child: LuwaAvatar(
                size: 56,
                isThinking: isLoading,
                badgeCount: unreadCount,
                onTap: () => setState(() => _chatOpen = true),
              ),
            ),

          // Chat overlay (slides in from right)
          if (_chatOpen)
            AvatarChatOverlay(
              onClose: () => setState(() => _chatOpen = false),
              outletId: outletId,
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final mood = ref.watch(aiBusinessMoodProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // AI Avatar Logo
          LuwaAvatar(size: 36),
          const SizedBox(width: AppTheme.spacingS),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Luwa AI',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'AI Co-Pilot untuk bisnis kamu',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppTheme.spacingM),
          // Business Mood Indicator
          if (mood != null) _buildMoodBadge(mood),
          const Spacer(),
          // Refresh button
          IconButton(
            onPressed: () {
              ref.read(aiPersonaProvider.notifier).refreshMood();
            },
            icon: const Icon(Icons.refresh_outlined),
            color: AppTheme.textSecondary,
            tooltip: 'Refresh mood & prediksi',
            iconSize: 20,
          ),
          // Settings button
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AiSettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            color: AppTheme.textSecondary,
            tooltip: 'AI Settings',
          ),
        ],
      ),
    );
  }

  /// Business mood badge shown in the top bar.
  Widget _buildMoodBadge(BusinessMoodData mood) {
    final moodConfig = _getMoodConfig(mood.mood);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: moodConfig.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: moodConfig.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(moodConfig.icon, size: 14, color: moodConfig.color),
          const SizedBox(width: 4),
          Text(
            moodConfig.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: moodConfig.color,
            ),
          ),
        ],
      ),
    );
  }

  // ======== DASHBOARD CONTENT (full-width, scrollable) ========

  Widget _buildDashboardContent() {
    final insights = ref.watch(aiActiveInsightsProvider);
    final pendingApprovals = ref.watch(aiPendingApprovalsProvider);
    final insightFilter = ref.watch(boAiInsightFilterProvider);
    final isLoading = ref.watch(aiInsightProvider).isLoading;
    final personaState = ref.watch(aiPersonaProvider);

    // Apply filter
    final filteredInsights = insightFilter == null
        ? insights
        : insights.where((i) => i.severity == insightFilter).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(aiInsightProvider.notifier).refresh();
        await ref.read(aiActionLogProvider.notifier).refresh();
        await ref.read(aiPersonaProvider.notifier).refreshMood();
      },
      child: CustomScrollView(
        slivers: [
          // === Business Intelligence: Business Mood + Predictions Card ===
          SliverToBoxAdapter(
            child: _buildPredictionCard(personaState),
          ),

          // === OTAK: AI Memory Section ===
          SliverToBoxAdapter(
            child: _buildMemorySection(personaState),
          ),

          // Insights section header + filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM,
                AppTheme.spacingM,
                AppTheme.spacingM,
                AppTheme.spacingS,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights,
                        size: 20,
                        color: AppTheme.aiPrimary,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Insights',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.aiPrimary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  // Filter chips
                  _buildFilterChips(insightFilter),
                ],
              ),
            ),
          ),

          // Insights list
          if (filteredInsights.isEmpty && !isLoading)
            SliverToBoxAdapter(child: _buildInsightsEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return InsightCard(insight: filteredInsights[index]);
                  },
                  childCount: filteredInsights.length,
                ),
              ),
            ),

          // Pending Approvals section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM,
                AppTheme.spacingL,
                AppTheme.spacingM,
                AppTheme.spacingS,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    size: 20,
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'Menunggu Persetujuan',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (pendingApprovals.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.spacingS),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        '${pendingApprovals.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Pending approvals list
          if (pendingApprovals.isEmpty)
            SliverToBoxAdapter(
              child: _buildPendingEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return PendingApprovalCard(
                      actionLog: pendingApprovals[index],
                    );
                  },
                  childCount: pendingApprovals.length,
                ),
              ),
            ),

          // Recent Actions section
          SliverToBoxAdapter(
            child: _buildRecentActionsSection(),
          ),

          // Bottom padding for floating avatar
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 120),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActionsSection() {
    final actionLogs = ref.watch(aiActionLogsProvider);
    final recentActions = actionLogs.take(8).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingL,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Aksi Terakhir',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          if (recentActions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Center(
                child: Text(
                  'Belum ada aksi terbaru',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                children: recentActions
                    .map((log) => ActionLogRow(actionLog: log))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// Business Intelligence: Business Mood + Predictions card at the top of the left column.
  Widget _buildPredictionCard(AiPersonaState personaState) {
    final mood = personaState.mood;
    final prediction = personaState.prediction;

    if (mood == null && prediction == null) {
      if (personaState.isLoading) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final moodConfig = mood != null
        ? _getMoodConfig(mood.mood)
        : _getMoodConfig(BusinessMood.steady);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              moodConfig.color.withValues(alpha: 0.05),
              moodConfig.color.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: moodConfig.color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Business Intelligence
            Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  size: 18,
                  color: moodConfig.color,
                ),
                const SizedBox(width: 6),
                Text(
                  'Business Intelligence',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                // Mood indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: moodConfig.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(moodConfig.icon, size: 12, color: moodConfig.color),
                      const SizedBox(width: 3),
                      Text(
                        moodConfig.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: moodConfig.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Mood description
            if (mood != null)
              Text(
                mood.moodText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),

            const SizedBox(height: AppTheme.spacingS),

            // Stats row
            if (mood != null)
              Row(
                children: [
                  _buildMiniStat(
                    'Hari ini',
                    'Rp ${_formatCurrency(mood.todayRevenue)}',
                    Icons.payments_outlined,
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  _buildMiniStat(
                    'Order',
                    '${mood.todayOrders}',
                    Icons.receipt_long_outlined,
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  _buildMiniStat(
                    'Rata-rata',
                    'Rp ${_formatCurrency(mood.avgDailyRevenue)}',
                    Icons.trending_flat_outlined,
                  ),
                ],
              ),

            // Prediction section
            if (prediction != null &&
                prediction.predictedBusyHours.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              Divider(color: moodConfig.color.withValues(alpha: 0.15)),
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Prediksi jam sibuk: ',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      prediction.predictedBusyHours
                          .map((h) =>
                              '${h.toString().padLeft(2, '0')}:00')
                          .join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Warnings
            if (mood != null && mood.warnings.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              ...mood.warnings.map((warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            warning,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  /// OTAK: AI Memory section showing stored insights.
  Widget _buildMemorySection(AiPersonaState personaState) {
    final memories = personaState.memories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        0,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: AppTheme.aiPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Memori AI',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (memories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.aiBackground,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '${memories.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.aiPrimary,
                      ),
                    ),
                  ),
                if (memories.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      _showClearMemoriesDialog(context);
                    },
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),

            if (memories.isEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Belum ada memori. AI akan mulai menyimpan pola dan insight penting dari percakapan kamu.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  height: 1.4,
                ),
              ),
            ] else ...[
              const SizedBox(height: AppTheme.spacingS),
              // Show top 5 memories
              ...memories.take(5).map((memory) => _buildMemoryItem(memory)),
              if (memories.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${memories.length - 5} memori lainnya',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryItem(AiMemory memory) {
    final categoryConfig = _getMemoryCategoryConfig(memory.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            categoryConfig.icon,
            size: 13,
            color: categoryConfig.color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              memory.insight,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (memory.reinforceCount > 1)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                '${memory.reinforceCount}x',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppTheme.textTertiary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======== SHARED WIDGETS ========

  Widget _buildFilterChips(String? activeFilter) {
    final filters = [
      _FilterChipData(label: 'Semua', value: null),
      _FilterChipData(label: 'Kritis', value: 'critical'),
      _FilterChipData(label: 'Peringatan', value: 'warning'),
      _FilterChipData(label: 'Info', value: 'info'),
      _FilterChipData(label: 'Positif', value: 'positive'),
    ];

    return Wrap(
      spacing: AppTheme.spacingS,
      children: filters.map((filter) {
        final isActive = activeFilter == filter.value;
        return FilterChip(
          label: Text(
            filter.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Colors.white : AppTheme.textSecondary,
            ),
          ),
          selected: isActive,
          onSelected: (selected) {
            ref.read(boAiProvider.notifier).setInsightFilter(
                  selected ? filter.value : null,
                );
          },
          selectedColor: AppTheme.aiPrimary,
          backgroundColor: AppTheme.surfaceColor,
          side: BorderSide(
            color: isActive
                ? AppTheme.aiPrimary
                : AppTheme.dividerColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildInsightsEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.aiBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 36,
                color: AppTheme.aiPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Semua baik!',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada insight aktif saat ini.\nLuwa akan memberi tahu jika ada yang perlu perhatian.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Center(
        child: Text(
          'Tidak ada aksi yang menunggu persetujuan.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final trustState = ref.watch(aiTrustProvider);
    final settings = trustState.settings;
    final personaState = ref.watch(aiPersonaProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Persona indicators
          _buildPersonaDot(
            'Memory',
            Icons.psychology_outlined,
            AppTheme.aiPrimary,
            personaState.memories.isNotEmpty,
          ),
          const SizedBox(width: AppTheme.spacingS),
          _buildPersonaDot(
            'Action Center',
            Icons.bolt_rounded,
            AppTheme.successColor,
            true, // Always active (function calling)
          ),
          const SizedBox(width: AppTheme.spacingS),
          _buildPersonaDot(
            'Business Intelligence',
            Icons.lightbulb_outlined,
            const Color(0xFF8B5CF6), // Purple for intelligence
            personaState.mood != null,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Icon(
            Icons.shield_outlined,
            size: 14,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            'Trust:',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          // Show colored dots for active trust levels
          if (settings.isEmpty)
            Text(
              'N/A',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: settings.where((s) => s.isEnabled).map((setting) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message:
                            '${_featureDisplayName(setting.featureKey)}: ${setting.trustLevelLabel}',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _trustDotColor(setting.trustLevel),
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            'Powered by DeepSeek',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaDot(
    String label,
    IconData icon,
    Color color,
    bool isActive,
  ) {
    return Tooltip(
      message: '$label ${isActive ? "aktif" : "belum aktif"}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : AppTheme.dividerColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 10,
              color: isActive ? color : AppTheme.textTertiary,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isActive ? color : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearMemoriesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hapus Semua Memori?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'AI akan melupakan semua pola dan insight yang sudah dipelajari. Tindakan ini tidak bisa dibatalkan.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(aiPersonaProvider.notifier).clearMemories();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ======== HELPER METHODS ========

  Color _trustDotColor(int level) {
    switch (level) {
      case 0:
        return AppTheme.trustLevelInform;
      case 1:
        return AppTheme.trustLevelSuggest;
      case 2:
        return AppTheme.trustLevelAuto;
      case 3:
        return AppTheme.trustLevelSilent;
      default:
        return AppTheme.textTertiary;
    }
  }

  String _featureDisplayName(String featureKey) {
    switch (featureKey) {
      case 'stock_alert':
        return 'Stock Alert';
      case 'auto_disable_product':
        return 'Auto-disable Produk';
      case 'auto_enable_product':
        return 'Auto-enable Produk';
      case 'auto_reorder':
        return 'Auto Reorder';
      case 'pricing_recommendation':
        return 'Pricing';
      case 'auto_promo':
        return 'Auto Promo';
      case 'demand_forecast':
        return 'Forecast';
      case 'menu_recommendation':
        return 'Menu Recommendation';
      case 'anomaly_alert':
        return 'Anomaly Detection';
      case 'staffing_suggestion':
        return 'Staffing';
      default:
        return FormatUtils.titleCase(featureKey.replaceAll('_', ' '));
    }
  }

  _MoodConfig _getMoodConfig(BusinessMood mood) {
    switch (mood) {
      case BusinessMood.thriving:
        return _MoodConfig(
          icon: Icons.rocket_launch_rounded,
          label: 'Luar Biasa',
          color: const Color(0xFF10B981), // Emerald
        );
      case BusinessMood.good:
        return _MoodConfig(
          icon: Icons.thumb_up_rounded,
          label: 'Bagus',
          color: const Color(0xFF3B82F6), // Blue
        );
      case BusinessMood.steady:
        return _MoodConfig(
          icon: Icons.trending_flat_rounded,
          label: 'Stabil',
          color: const Color(0xFF6B7280), // Gray
        );
      case BusinessMood.slow:
        return _MoodConfig(
          icon: Icons.trending_down_rounded,
          label: 'Lambat',
          color: const Color(0xFFF59E0B), // Amber
        );
      case BusinessMood.concerned:
        return _MoodConfig(
          icon: Icons.sentiment_dissatisfied_rounded,
          label: 'Perlu Perhatian',
          color: const Color(0xFFEF4444), // Red
        );
    }
  }

  _MemoryCategoryConfig _getMemoryCategoryConfig(String category) {
    switch (category) {
      case 'sales':
        return _MemoryCategoryConfig(
          icon: Icons.trending_up,
          color: AppTheme.successColor,
        );
      case 'product':
        return _MemoryCategoryConfig(
          icon: Icons.restaurant_menu,
          color: AppTheme.aiPrimary,
        );
      case 'stock':
        return _MemoryCategoryConfig(
          icon: Icons.inventory_2_outlined,
          color: AppTheme.warningColor,
        );
      case 'customer':
        return _MemoryCategoryConfig(
          icon: Icons.people_outline,
          color: AppTheme.infoColor,
        );
      case 'operational':
        return _MemoryCategoryConfig(
          icon: Icons.settings_outlined,
          color: AppTheme.textSecondary,
        );
      default:
        return _MemoryCategoryConfig(
          icon: Icons.lightbulb_outline,
          color: AppTheme.textSecondary,
        );
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toStringAsFixed(0);
  }
}

class _FilterChipData {
  final String label;
  final String? value;

  const _FilterChipData({required this.label, required this.value});
}

class _MoodConfig {
  final IconData icon;
  final String label;
  final Color color;

  const _MoodConfig({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _MemoryCategoryConfig {
  final IconData icon;
  final Color color;

  const _MemoryCategoryConfig({
    required this.icon,
    required this.color,
  });
}
