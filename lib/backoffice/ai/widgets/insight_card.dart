import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/core/models/ai_insight.dart';
import 'package:luwa_app/core/providers/ai/ai_insight_provider.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';
import 'package:luwa_app/shared/utils/format_utils.dart';

/// A card widget that displays a single AI insight.
///
/// Color-coded by severity, with expandable details
/// and action buttons for suggested actions.
class InsightCard extends ConsumerStatefulWidget {
  /// The insight data to display.
  final AiInsight insight;

  /// Optional callback when the primary action is tapped.
  final VoidCallback? onAction;

  /// Optional callback when dismiss is tapped.
  final VoidCallback? onDismiss;

  const InsightCard({
    super.key,
    required this.insight,
    this.onAction,
    this.onDismiss,
  });

  @override
  ConsumerState<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<InsightCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'info':
        return 'Info';
      case 'warning':
        return 'Peringatan';
      case 'critical':
        return 'Kritis';
      case 'positive':
        return 'Positif';
      default:
        return severity;
    }
  }

  String _actionLabel(String? action) {
    if (action == null) return 'Tindakan';
    switch (action) {
      case 'create_po':
        return 'Buat PO';
      case 'adjust_price':
        return 'Naikkan Harga';
      case 'reorder':
        return 'Reorder Stok';
      case 'disable_product':
        return 'Nonaktifkan Produk';
      case 'enable_product':
        return 'Aktifkan Produk';
      case 'create_promo':
        return 'Buat Promo';
      case 'adjust_staffing':
        return 'Atur Jadwal';
      default:
        return FormatUtils.titleCase(action.replaceAll('_', ' '));
    }
  }

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_slideAnimation),
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            side: BorderSide(
              color: AppTheme.dividerColor,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Color-coded left border
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: insight.severityColor,
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: type icon + severity badge + time
                        Row(
                          children: [
                            Icon(
                              insight.typeIcon,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            _SeverityBadge(
                              label: _severityLabel(insight.severity),
                              color: insight.severityColor,
                            ),
                            const Spacer(),
                            Text(
                              FormatUtils.relativeTime(insight.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingS),

                        // Title
                        Text(
                          insight.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Description
                        Text(
                          insight.description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: _isExpanded ? null : 2,
                          overflow: _isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),

                        // Expanded data details
                        if (_isExpanded && insight.data != null) ...[
                          const SizedBox(height: AppTheme.spacingS),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusM),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detail Data',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...insight.data!.entries
                                    .take(6)
                                    .map((entry) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${FormatUtils.titleCase(entry.key.replaceAll('_', ' '))}:',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${entry.value}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary,
                                            ),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppTheme.spacingS),

                        // Action row
                        Row(
                          children: [
                            // Primary action button
                            if (insight.suggestedAction != null)
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: widget.onAction ??
                                      () {
                                        ref
                                            .read(
                                                aiInsightProvider.notifier)
                                            .actOnInsight(insight.id);
                                      },
                                  icon: const Icon(Icons.flash_on,
                                      size: 16),
                                  label: Text(
                                    _actionLabel(insight.suggestedAction),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        insight.severityColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              AppTheme.radiusM),
                                    ),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            // Expand button
                            if (insight.data != null)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                icon: AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0.0,
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.expand_more,
                                    size: 20,
                                  ),
                                ),
                                iconSize: 20,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                color: AppTheme.textTertiary,
                              ),
                            // Dismiss button
                            TextButton(
                              onPressed: widget.onDismiss ??
                                  () {
                                    ref
                                        .read(aiInsightProvider.notifier)
                                        .dismissInsight(insight.id);
                                  },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textTertiary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                minimumSize: const Size(0, 32),
                              ),
                              child: Text(
                                'Abaikan',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small colored badge showing the insight severity.
class _SeverityBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SeverityBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
