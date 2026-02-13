import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/core/models/ai_action_log.dart';
import 'package:luwa_app/core/providers/ai/ai_action_log_provider.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';
import 'package:luwa_app/shared/utils/format_utils.dart';

/// A single row in the action log list.
///
/// Displays timestamp, feature icon, description, action type badge,
/// undo button (with countdown), and expandable action data details.
class ActionLogRow extends ConsumerStatefulWidget {
  /// The action log entry to display.
  final AiActionLog actionLog;

  /// Optional callback when undo is tapped.
  final VoidCallback? onUndo;

  const ActionLogRow({
    super.key,
    required this.actionLog,
    this.onUndo,
  });

  @override
  ConsumerState<ActionLogRow> createState() => _ActionLogRowState();
}

class _ActionLogRowState extends ConsumerState<ActionLogRow> {
  bool _isExpanded = false;

  IconData _featureIcon(String featureKey) {
    switch (featureKey) {
      case 'stock_alert':
        return Icons.inventory_2_outlined;
      case 'auto_disable_product':
        return Icons.block_outlined;
      case 'auto_enable_product':
        return Icons.check_circle_outline;
      case 'draft_purchase_order':
      case 'send_purchase_order':
        return Icons.receipt_long_outlined;
      case 'auto_reorder':
        return Icons.refresh_outlined;
      case 'pricing_recommendation':
        return Icons.attach_money;
      case 'auto_promo':
        return Icons.local_offer_outlined;
      case 'demand_forecast':
        return Icons.trending_up;
      case 'menu_recommendation':
        return Icons.restaurant_menu;
      case 'anomaly_alert':
        return Icons.report_problem_outlined;
      case 'staffing_suggestion':
        return Icons.people_outline;
      default:
        return Icons.smart_toy_outlined;
    }
  }

  Color _actionTypeColor(String actionType) {
    switch (actionType) {
      case 'informed':
        return AppTheme.infoColor;
      case 'suggested':
        return AppTheme.warningColor;
      case 'auto_executed':
      case 'silent_executed':
        return AppTheme.successColor;
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'edited':
        return AppTheme.primaryColor;
      case 'undone':
        return AppTheme.textTertiary;
      default:
        return AppTheme.textTertiary;
    }
  }

  String _actionTypeLabel(String actionType) {
    switch (actionType) {
      case 'informed':
        return 'Informasi';
      case 'suggested':
        return 'Saran';
      case 'auto_executed':
        return 'Otomatis';
      case 'silent_executed':
        return 'Silent';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'edited':
        return 'Diedit';
      case 'undone':
        return 'Dibatalkan';
      default:
        return FormatUtils.titleCase(actionType.replaceAll('_', ' '));
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.actionLog;
    final isUndone = log.isUndone;

    return Column(
      children: [
        InkWell(
          onTap: log.actionData != null
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            child: Opacity(
              opacity: isUndone ? 0.5 : 1.0,
              child: Row(
                children: [
                  // Timestamp
                  SizedBox(
                    width: 48,
                    child: Text(
                      FormatUtils.time(log.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),

                  // Feature icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _actionTypeColor(log.actionType)
                          .withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Icon(
                      _featureIcon(log.featureKey),
                      size: 16,
                      color: _actionTypeColor(log.actionType),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),

                  // Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.actionDescription,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                            decoration: isUndone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (log.source != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            log.source!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),

                  // Action type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _actionTypeColor(log.actionType)
                          .withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      _actionTypeLabel(log.actionType),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _actionTypeColor(log.actionType),
                        decoration: isUndone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),

                  // Undo button or expand indicator
                  if (log.canUndo)
                    _UndoCountdownButton(
                      undoDeadline: log.undoDeadline!,
                      onUndo: widget.onUndo ??
                          () {
                            ref
                                .read(aiActionLogProvider.notifier)
                                .undoAction(log.id);
                          },
                    )
                  else if (log.actionData != null)
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: AppTheme.textTertiary,
                      ),
                    )
                  else
                    const SizedBox(width: 18),
                ],
              ),
            ),
          ),
        ),

        // Expanded details
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildExpandedDetails(),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildExpandedDetails() {
    final data = widget.actionLog.actionData;
    if (data == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingXL + 48,
        0,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Aksi',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          ...data.entries.take(8).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      FormatUtils.titleCase(
                          entry.key.replaceAll('_', ' ')),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// A small undo button with a countdown timer.
class _UndoCountdownButton extends StatefulWidget {
  final DateTime undoDeadline;
  final VoidCallback onUndo;

  const _UndoCountdownButton({
    required this.undoDeadline,
    required this.onUndo,
  });

  @override
  State<_UndoCountdownButton> createState() => _UndoCountdownButtonState();
}

class _UndoCountdownButtonState extends State<_UndoCountdownButton> {
  late Stream<int> _countdownStream;

  @override
  void initState() {
    super.initState();
    _countdownStream = Stream.periodic(
      const Duration(seconds: 1),
      (count) {
        final remaining =
            widget.undoDeadline.difference(DateTime.now()).inSeconds;
        return remaining > 0 ? remaining : 0;
      },
    ).takeWhile((seconds) => seconds > 0);
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _countdownStream,
      builder: (context, snapshot) {
        final remaining =
            widget.undoDeadline.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          return const SizedBox(width: 18);
        }

        final seconds = snapshot.data ?? remaining;

        return SizedBox(
          height: 28,
          child: TextButton(
            onPressed: widget.onUndo,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.warningColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                side: BorderSide(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              backgroundColor: AppTheme.warningColor.withValues(alpha: 0.08),
            ),
            child: Text(
              'Undo (${_formatCountdown(seconds)})',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
