import 'dart:async';

import 'package:flutter/material.dart';

import 'package:luwa_app/core/models/ai_insight.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';

/// AI Insight Toast
///
/// A toast / notification popup for proactive AI insights. Appears
/// at the top of the screen with a slide-down animation, auto-dismisses
/// after 5 seconds, and supports swipe-to-dismiss. Can be shown from
/// anywhere via the static [AiInsightToast.show] method.
class AiInsightToast {
  AiInsightToast._();

  /// Show an insight toast on the given overlay.
  ///
  /// Returns a function that can be called to dismiss the toast early.
  /// [onTap] is called when the user taps "Lihat".
  static VoidCallback show(
    BuildContext context, {
    required AiInsight insight,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    bool removed = false;

    void remove() {
      if (!removed) {
        removed = true;
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (context) => _AiInsightToastWidget(
        insight: insight,
        duration: duration,
        onDismiss: remove,
        onTap: () {
          remove();
          onTap?.call();
        },
      ),
    );

    overlay.insert(entry);
    return remove;
  }
}

/// Internal animated toast widget.
class _AiInsightToastWidget extends StatefulWidget {
  final AiInsight insight;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _AiInsightToastWidget({
    required this.insight,
    required this.duration,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_AiInsightToastWidget> createState() => _AiInsightToastWidgetState();
}

class _AiInsightToastWidgetState extends State<_AiInsightToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _startAutoHideTimer();
  }

  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _autoHideTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Severity-specific background color.
  Color _backgroundColor(AiInsight insight) {
    switch (insight.severity) {
      case 'info':
        return AppTheme.infoColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'critical':
        return AppTheme.errorColor;
      case 'positive':
        return AppTheme.successColor;
      default:
        return AppTheme.infoColor;
    }
  }

  /// Severity-specific icon.
  IconData _severityIcon(AiInsight insight) {
    switch (insight.severity) {
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'critical':
        return Icons.error_outline;
      case 'positive':
        return Icons.check_circle_outline;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final severityColor = _backgroundColor(widget.insight);

    return Positioned(
      top: topPadding + AppTheme.spacingS,
      left: isMobile ? AppTheme.spacingM : null,
      right: isMobile ? AppTheme.spacingM : AppTheme.spacingM,
      width: isMobile ? null : 420,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: ValueKey(widget.insight.id),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: severityColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: severityColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Severity color bar at top
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: severityColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.radiusL),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingM,
                        AppTheme.spacingS,
                        AppTheme.spacingS,
                        AppTheme.spacingS,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon + Title row
                          Row(
                            children: [
                              // Severity icon in colored circle
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Icon(
                                  _severityIcon(widget.insight),
                                  color: severityColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),

                              // Title + AI tag
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.aiPrimary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Haru AI',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.aiPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.insight.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Close button
                              IconButton(
                                onPressed: _dismiss,
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white38
                                      : AppTheme.textTertiary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                splashRadius: 16,
                              ),
                            ],
                          ),

                          // Description
                          if (widget.insight.description.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingXS),
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AppTheme.spacingS),
                              child: Text(
                                widget.insight.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark
                                      ? Colors.white60
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppTheme.spacingS),

                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Dismiss
                              TextButton(
                                onPressed: _dismiss,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white54
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),

                              // View
                              TextButton(
                                onPressed: widget.onTap,
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      severityColor.withValues(alpha: 0.1),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusM),
                                  ),
                                ),
                                child: Text(
                                  'Lihat',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: severityColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
