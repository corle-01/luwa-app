import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/core/config/app_constants.dart';
import 'package:luwa_app/core/providers/ai/ai_action_log_provider.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';
import 'package:luwa_app/shared/utils/format_utils.dart';
import 'package:luwa_app/backoffice/ai/providers/bo_ai_provider.dart';
import 'package:luwa_app/backoffice/ai/widgets/action_log_row.dart';
import 'package:luwa_app/backoffice/ai/widgets/undo_banner.dart';

/// Full action history page showing all AI actions with filtering.
///
/// Supports filtering by feature key and date range,
/// pagination via "Load more", and pull-to-refresh.
class AiActionLogPage extends ConsumerStatefulWidget {
  const AiActionLogPage({super.key});

  @override
  ConsumerState<AiActionLogPage> createState() =>
      _AiActionLogPageState();
}

class _AiActionLogPageState extends ConsumerState<AiActionLogPage> {
  bool _showFilters = false;

  // Feature key options for filtering
  static const List<_FeatureOption> _featureOptions = [
    _FeatureOption(key: null, label: 'Semua Fitur'),
    _FeatureOption(
        key: AppConstants.featureStockAlert, label: 'Stock Alert'),
    _FeatureOption(
        key: AppConstants.featureAutoDisableProduct,
        label: 'Auto-disable Produk'),
    _FeatureOption(
        key: AppConstants.featureAutoEnableProduct,
        label: 'Auto-enable Produk'),
    _FeatureOption(
        key: AppConstants.featureAutoReorder,
        label: 'Auto Reorder'),
    _FeatureOption(
        key: AppConstants.featurePricingRecommendation,
        label: 'Pricing'),
    _FeatureOption(
        key: AppConstants.featureAutoPromo, label: 'Auto Promo'),
    _FeatureOption(
        key: AppConstants.featureDemandForecast,
        label: 'Demand Forecast'),
    _FeatureOption(
        key: AppConstants.featureMenuRecommendation,
        label: 'Menu Recommendation'),
    _FeatureOption(
        key: AppConstants.featureAnomalyAlert,
        label: 'Anomaly Detection'),
    _FeatureOption(
        key: AppConstants.featureStaffingSuggestion,
        label: 'Staffing'),
  ];

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(aiActionLogProvider);
    final logs = logState.logs;
    final isLoading = logState.isLoading;
    final hasMore = logState.hasMore;

    final undoableLogs = logState.undoableLogs;

    final boState = ref.watch(boAiProvider);
    final selectedFilter = boState.selectedLogFilter;
    final dateFrom = boState.logDateFrom;
    final dateTo = boState.logDateTo;

    // Apply local date filter
    final filteredLogs = _applyDateFilter(logs, dateFrom, dateTo);

    // Listen for errors
    ref.listen<String?>(
      aiActionLogProvider.select((state) => state.error),
      (previous, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          ref.read(aiActionLogProvider.notifier).clearError();
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Action Log',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            icon: Icon(
              _showFilters
                  ? Icons.filter_list_off
                  : Icons.filter_list,
              color: _showFilters || selectedFilter != null
                  ? AppTheme.aiPrimary
                  : AppTheme.textSecondary,
            ),
            tooltip: 'Filter',
          ),
          IconButton(
            onPressed: () {
              ref.read(aiActionLogProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
            color: AppTheme.textSecondary,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
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

          // Filter bar
          if (_showFilters) _buildFilterBar(selectedFilter, dateFrom, dateTo),

          // Active filter indicator
          if (selectedFilter != null || dateFrom != null)
            _buildActiveFilterIndicator(selectedFilter, dateFrom, dateTo),

          // Content
          Expanded(
            child: filteredLogs.isEmpty && !isLoading
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(aiActionLogProvider.notifier)
                          .refresh();
                    },
                    child: ListView.builder(
                      itemCount:
                          filteredLogs.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredLogs.length) {
                          // Load more button
                          return _buildLoadMoreButton(isLoading);
                        }

                        final log = filteredLogs[index];

                        // Date header
                        final showDateHeader = index == 0 ||
                            !_isSameDay(
                              filteredLogs[index - 1].createdAt,
                              log.createdAt,
                            );

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              _buildDateHeader(log.createdAt),
                            ActionLogRow(actionLog: log),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    String? selectedFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feature filter dropdown
          Text(
            'Filter Fitur',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedFilter,
                isExpanded: true,
                icon: const Icon(Icons.expand_more,
                    color: AppTheme.textSecondary),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                items: _featureOptions.map((option) {
                  return DropdownMenuItem<String?>(
                    value: option.key,
                    child: Text(option.label),
                  );
                }).toList(),
                onChanged: (value) {
                  ref
                      .read(boAiProvider.notifier)
                      .setLogFilter(value);
                  // Reload logs with filter
                  final outletId =
                      ref.read(aiActionLogProvider).outletId;
                  if (outletId != null) {
                    ref
                        .read(aiActionLogProvider.notifier)
                        .loadLogs(outletId, featureKey: value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Date range picker
          Text(
            'Rentang Tanggal',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: 'Dari',
                  date: dateFrom,
                  onPicked: (date) {
                    ref.read(boAiProvider.notifier).setLogDateRange(
                          date,
                          dateTo,
                        );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppTheme.textTertiary,
                ),
              ),
              Expanded(
                child: _DatePickerButton(
                  label: 'Sampai',
                  date: dateTo,
                  onPicked: (date) {
                    ref.read(boAiProvider.notifier).setLogDateRange(
                          dateFrom,
                          date,
                        );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterIndicator(
    String? selectedFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      color: AppTheme.aiBackground,
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 14,
            color: AppTheme.aiPrimary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _buildFilterDescription(
                  selectedFilter, dateFrom, dateTo),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.aiPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              ref.read(boAiProvider.notifier).setLogFilter(null);
              ref
                  .read(boAiProvider.notifier)
                  .setLogDateRange(null, null);
              final outletId =
                  ref.read(aiActionLogProvider).outletId;
              if (outletId != null) {
                ref
                    .read(aiActionLogProvider.notifier)
                    .loadLogs(outletId);
              }
            },
            child: Text(
              'Reset',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.aiPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildFilterDescription(
    String? selectedFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  ) {
    final parts = <String>[];
    if (selectedFilter != null) {
      final label = _featureOptions
          .firstWhere(
            (o) => o.key == selectedFilter,
            orElse: () =>
                const _FeatureOption(key: null, label: 'Unknown'),
          )
          .label;
      parts.add('Fitur: $label');
    }
    if (dateFrom != null) {
      parts.add('Dari: ${FormatUtils.date(dateFrom)}');
    }
    if (dateTo != null) {
      parts.add('Sampai: ${FormatUtils.date(dateTo)}');
    }
    return parts.join(' | ');
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String label;
    if (dateOnly == today) {
      label = 'Hari Ini';
    } else if (dateOnly == yesterday) {
      label = 'Kemarin';
    } else {
      label = FormatUtils.date(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.aiPrimary,
                ),
              )
            : OutlinedButton(
                onPressed: () {
                  final selectedFilter =
                      ref.read(boAiProvider).selectedLogFilter;
                  ref
                      .read(aiActionLogProvider.notifier)
                      .loadMore(featureKey: selectedFilter);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.aiPrimary,
                  side: BorderSide(
                    color: AppTheme.aiPrimary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
                child: Text(
                  'Muat lebih banyak',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.history,
              size: 36,
              color: AppTheme.aiPrimary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Belum ada aksi',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua aksi yang dilakukan Luwa\nakan tercatat di sini.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<dynamic> _applyDateFilter(
    List<dynamic> logs,
    DateTime? from,
    DateTime? to,
  ) {
    if (from == null && to == null) return logs;
    return logs.where((log) {
      final created = log.createdAt as DateTime;
      if (from != null && created.isBefore(from)) return false;
      if (to != null) {
        final toEnd = to.add(const Duration(days: 1));
        if (created.isAfter(toEnd)) return false;
      }
      return true;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// A button that opens a date picker.
class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerButton({
    required this.label,
    this.date,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppTheme.aiPrimary,
                    ),
              ),
              child: child!,
            );
          },
        );
        onPicked(picked);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null ? FormatUtils.date(date!) : label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: date != null
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureOption {
  final String? key;
  final String label;

  const _FeatureOption({required this.key, required this.label});
}
