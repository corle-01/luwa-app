import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/core/models/ai_action_log.dart';
import 'package:luwa_app/core/providers/ai/ai_action_log_provider.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';
import 'package:luwa_app/shared/utils/format_utils.dart';

/// A compact card for displaying actions that need user approval.
///
/// Shows the action description, feature badge, trust level,
/// and Approve/Edit/Reject buttons.
class PendingApprovalCard extends ConsumerWidget {
  /// The action log entry awaiting approval.
  final AiActionLog actionLog;

  /// Callback when the Approve button is tapped.
  final VoidCallback? onApprove;

  /// Callback when the Edit button is tapped.
  final VoidCallback? onEdit;

  /// Callback when the Reject button is tapped.
  final VoidCallback? onReject;

  const PendingApprovalCard({
    super.key,
    required this.actionLog,
    this.onApprove,
    this.onEdit,
    this.onReject,
  });

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

  String _featureLabel(String featureKey) {
    switch (featureKey) {
      case 'stock_alert':
        return 'Stok';
      case 'auto_disable_product':
        return 'Nonaktif Produk';
      case 'auto_enable_product':
        return 'Aktif Produk';
      case 'draft_purchase_order':
        return 'Draft PO';
      case 'send_purchase_order':
        return 'Kirim PO';
      case 'auto_reorder':
        return 'Auto Reorder';
      case 'pricing_recommendation':
        return 'Harga';
      case 'auto_promo':
        return 'Promo';
      case 'demand_forecast':
        return 'Forecast';
      case 'menu_recommendation':
        return 'Menu';
      case 'anomaly_alert':
        return 'Anomali';
      case 'staffing_suggestion':
        return 'Staffing';
      default:
        return FormatUtils.titleCase(featureKey.replaceAll('_', ' '));
    }
  }

  String _trustLevelLabel(int level) {
    switch (level) {
      case 0:
        return 'Inform';
      case 1:
        return 'Suggest';
      case 2:
        return 'Auto';
      case 3:
        return 'Silent';
      default:
        return 'Unknown';
    }
  }

  Color _trustLevelColor(int level) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: BorderSide(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: feature icon + badges + time
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.aiBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    _featureIcon(actionLog.featureKey),
                    size: 18,
                    color: AppTheme.aiPrimary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                // Feature label badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.aiBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    _featureLabel(actionLog.featureKey),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.aiPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Trust level badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        _trustLevelColor(actionLog.trustLevel).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    _trustLevelLabel(actionLog.trustLevel),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _trustLevelColor(actionLog.trustLevel),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  FormatUtils.relativeTime(actionLog.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Action description
            Text(
              actionLog.actionDescription,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Action buttons: Approve / Edit / Reject
            Row(
              children: [
                // Approve button
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onApprove ??
                          () {
                            ref
                                .read(aiActionLogProvider.notifier)
                                .approveAction(actionLog.id, 'current_user');
                          },
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        'Setuju',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusM),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                // Edit button
                SizedBox(
                  height: 36,
                  width: 36,
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.infoColor,
                      side: const BorderSide(color: AppTheme.infoColor),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.edit_outlined, size: 16),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                // Reject button
                SizedBox(
                  height: 36,
                  width: 36,
                  child: OutlinedButton(
                    onPressed: onReject ??
                        () {
                          ref
                              .read(aiActionLogProvider.notifier)
                              .rejectAction(actionLog.id, 'current_user');
                        },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
