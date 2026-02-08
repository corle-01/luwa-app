import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/ai/ai_persona_provider.dart';
import '../../core/services/ai/ai_memory_service.dart';
import '../themes/app_theme.dart';

/// Animated Utter AI Avatar
///
/// A living, breathing bird avatar that reacts to business mood.
/// - Idle: gentle floating + breathing
/// - Thinking: faster bounce + glow pulse
/// - Happy (thriving/good): bounce with sparkle ring
/// - Concerned (slow/concerned): slight droop + muted glow
class UtterAvatar extends ConsumerStatefulWidget {
  /// Avatar size (diameter).
  final double size;

  /// Whether the AI is currently processing a message.
  final bool isThinking;

  /// Callback when the avatar is tapped.
  final VoidCallback? onTap;

  /// Unread insight/notification count.
  final int badgeCount;

  const UtterAvatar({
    super.key,
    this.size = 64,
    this.isThinking = false,
    this.onTap,
    this.badgeCount = 0,
  });

  @override
  ConsumerState<UtterAvatar> createState() => _UtterAvatarState();
}

class _UtterAvatarState extends ConsumerState<UtterAvatar>
    with TickerProviderStateMixin {
  // Breathing animation (scale)
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  // Floating animation (vertical offset)
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Glow pulse animation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Blink animation
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Breathing: gentle scale 1.0 → 1.04
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Floating: gentle vertical bob -3 → +3
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Glow pulse for thinking state
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Blink: periodic eye close (scale Y of overlay)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Start periodic blinking
    _startBlinking();
  }

  void _startBlinking() {
    Future.doWhile(() async {
      if (!mounted) return false;
      // Random interval between blinks: 2-5 seconds
      final delay = 2000 + math.Random().nextInt(3000);
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted) return false;
      await _blinkController.forward();
      if (!mounted) return false;
      await _blinkController.reverse();
      return mounted;
    });
  }

  @override
  void didUpdateWidget(UtterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinking != oldWidget.isThinking) {
      if (widget.isThinking) {
        _glowController.repeat(reverse: true);
        _breathController.duration = const Duration(milliseconds: 1200);
      } else {
        _glowController.stop();
        _glowController.value = 0;
        _breathController.duration = const Duration(milliseconds: 2800);
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Color _getMoodGlowColor(BusinessMood? mood) {
    switch (mood) {
      case BusinessMood.thriving:
        return const Color(0xFF10B981); // green
      case BusinessMood.good:
        return const Color(0xFF34D399); // light green
      case BusinessMood.steady:
        return AppTheme.aiPrimary; // purple
      case BusinessMood.slow:
        return const Color(0xFFF59E0B); // amber
      case BusinessMood.concerned:
        return const Color(0xFFEF4444); // red
      case null:
        return AppTheme.aiPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(aiBusinessMoodProvider)?.mood;
    final glowColor = _getMoodGlowColor(mood);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathAnimation,
          _floatAnimation,
          _glowAnimation,
          _blinkAnimation,
        ]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Transform.scale(
              scale: _breathAnimation.value,
              child: SizedBox(
                width: widget.size + 16,
                height: widget.size + 16,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer glow ring
                    Container(
                      width: widget.size + 12,
                      height: widget.size + 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withValues(
                              alpha: widget.isThinking
                                  ? _glowAnimation.value
                                  : 0.25,
                            ),
                            blurRadius: widget.isThinking ? 20 : 12,
                            spreadRadius: widget.isThinking ? 4 : 1,
                          ),
                        ],
                      ),
                    ),

                    // Avatar circle with image
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: glowColor.withValues(alpha: 0.6),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            // Bird avatar image
                            Image.asset(
                              'assets/images/utter_avatar.png',
                              width: widget.size,
                              height: widget.size,
                              fit: BoxFit.cover,
                            ),

                            // Blink overlay (semi-transparent bar that shrinks)
                            Positioned(
                              top: widget.size * 0.28,
                              left: widget.size * 0.15,
                              right: widget.size * 0.15,
                              child: Transform.scale(
                                scaleY: 1.0 - _blinkAnimation.value,
                                alignment: Alignment.center,
                                child: Container(
                                  height: widget.size * 0.12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A90D9)
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Thinking indicator (spinning dots)
                    if (widget.isThinking)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: _ThinkingIndicator(size: widget.size * 0.35),
                      ),

                    // Notification badge
                    if (widget.badgeCount > 0 && !widget.isThinking)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.errorColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.badgeCount > 99
                                    ? '99+'
                                    : '${widget.badgeCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Mood indicator dot
                    if (mood != null && !widget.isThinking)
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: glowColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Spinning thinking indicator (3 dots in a circle).
class _ThinkingIndicator extends StatefulWidget {
  final double size;
  const _ThinkingIndicator({required this.size});

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ThinkingDotsPainter(
              progress: _controller.value,
              color: AppTheme.aiPrimary,
              dotRadius: widget.size * 0.12,
            ),
          );
        },
      ),
    );
  }
}

class _ThinkingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double dotRadius;

  _ThinkingDotsPainter({
    required this.progress,
    required this.color,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - dotRadius;

    for (int i = 0; i < 3; i++) {
      final angle = (progress * 2 * math.pi) + (i * 2 * math.pi / 3);
      final dotCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final opacity = 0.4 + 0.6 * ((math.sin(progress * 2 * math.pi + i * 1.2) + 1) / 2);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_ThinkingDotsPainter old) => old.progress != progress;
}
