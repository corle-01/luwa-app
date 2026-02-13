import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:luwa_app/shared/themes/app_theme.dart';

/// A persistent banner showing an undo action with a countdown timer.
///
/// Automatically dismisses when the undo deadline passes.
/// Displays the action description, remaining time, and an "Undo" button.
class UndoBanner extends StatefulWidget {
  /// Description of the action that can be undone.
  final String actionDescription;

  /// The deadline after which the undo is no longer available.
  final DateTime undoDeadline;

  /// Callback when the user taps "Undo".
  final VoidCallback onUndo;

  /// Callback when the banner is dismissed (either by timeout or user).
  final VoidCallback? onDismiss;

  const UndoBanner({
    super.key,
    required this.actionDescription,
    required this.undoDeadline,
    required this.onUndo,
    this.onDismiss,
  });

  @override
  State<UndoBanner> createState() => _UndoBannerState();
}

class _UndoBannerState extends State<UndoBanner>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _remainingSeconds = 0;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateRemaining();
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _dismiss();
      }
    });
  }

  void _updateRemaining() {
    final remaining =
        widget.undoDeadline.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() {
        _remainingSeconds = remaining > 0 ? remaining : 0;
      });
    }
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    _slideController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  void _handleUndo() {
    widget.onUndo();
    _dismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '$minutes menit $seconds detik';
    }
    return '$seconds detik';
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0 && _isDismissed) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.warningColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Warning icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Icon(
                Icons.undo_rounded,
                size: 16,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),

            // Description + countdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.actionDescription,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bisa dibatalkan dalam ${_formatCountdown(_remainingSeconds)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),

            // Undo button
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: _handleUndo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Undo',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Close button
            IconButton(
              onPressed: _dismiss,
              icon: Icon(
                Icons.close,
                size: 16,
                color: AppTheme.textTertiary,
              ),
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
