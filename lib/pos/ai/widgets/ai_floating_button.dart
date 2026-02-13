import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:luwa_app/core/providers/ai/ai_insight_provider.dart';
import 'package:luwa_app/shared/themes/app_theme.dart';

/// AI Floating Action Button
///
/// A beautiful FAB that appears on every POS page, providing quick
/// access to the Luwa AI assistant. Shows an unread insight badge
/// and pulses gently when new insights arrive.
class AiFloatingButton extends ConsumerStatefulWidget {
  /// Callback when the button is tapped (typically opens the AI panel).
  final VoidCallback onTap;

  const AiFloatingButton({
    super.key,
    required this.onTap,
  });

  @override
  ConsumerState<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends ConsumerState<AiFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Track the previous unread count to detect new arrivals.
  int _previousUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Start a gentle pulse animation and stop after a few cycles.
  void _triggerPulse() {
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _pulseController.forward().then((_) {
          if (mounted) _pulseController.reset();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(aiInsightUnreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Detect new insight arrival and trigger pulse.
    if (unreadCount > _previousUnreadCount && _previousUnreadCount >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerPulse();
      });
    }
    _previousUnreadCount = unreadCount;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main FAB with gradient
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.aiSecondary,
                    AppTheme.aiPrimary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.aiPrimary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppTheme.aiPrimary.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: widget.onTap,
                  customBorder: const CircleBorder(),
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Center(
                    child: Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 28,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Unread notification badge
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
