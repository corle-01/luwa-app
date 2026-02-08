import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/ai/ai_persona_provider.dart';
import '../../core/services/ai/ai_memory_service.dart';
import '../themes/app_theme.dart';

/// Animated Utter AI Avatar — fully programmatic (CustomPainter).
///
/// A cute owl/bird mascot drawn entirely in code.
/// Expressive animations:
/// - Eyes change shape based on mood (happy arcs, neutral dots, concerned)
/// - Natural blinking
/// - Breathing (subtle scale)
/// - Floating (vertical bob)
/// - Thinking: spinning glow halo + pupil animation
/// - Mood-reactive body glow color
class UtterAvatar extends ConsumerStatefulWidget {
  final double size;
  final bool isThinking;
  final VoidCallback? onTap;
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
  // Breathing: scale 1.0 → 1.05
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  // Floating: vertical bob
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Glow pulse (thinking)
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Blink: eye close 1.0 → 0.0
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  // Pupil look direction (thinking: wander)
  late AnimationController _pupilController;
  late Animation<double> _pupilAnimation;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pupilAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _pupilController, curve: Curves.easeInOut),
    );

    _startBlinking();

    if (widget.isThinking) {
      _glowController.repeat(reverse: true);
      _pupilController.repeat(reverse: true);
    }
  }

  void _startBlinking() {
    Future.doWhile(() async {
      if (!mounted) return false;
      final delay = 2500 + math.Random().nextInt(3000);
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted) return false;
      await _blinkController.forward();
      if (!mounted) return false;
      await _blinkController.reverse();
      // Occasional double blink
      if (math.Random().nextDouble() < 0.25) {
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return false;
        await _blinkController.forward();
        if (!mounted) return false;
        await _blinkController.reverse();
      }
      return mounted;
    });
  }

  @override
  void didUpdateWidget(UtterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinking != oldWidget.isThinking) {
      if (widget.isThinking) {
        _glowController.repeat(reverse: true);
        _pupilController.repeat(reverse: true);
        _breathController.duration = const Duration(milliseconds: 1400);
      } else {
        _glowController.stop();
        _glowController.value = 0;
        _pupilController.stop();
        _pupilController.value = 0;
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
    _pupilController.dispose();
    super.dispose();
  }

  Color _getMoodColor(BusinessMood? mood) {
    switch (mood) {
      case BusinessMood.thriving:
        return const Color(0xFF10B981);
      case BusinessMood.good:
        return const Color(0xFF34D399);
      case BusinessMood.steady:
        return const Color(0xFF6366F1);
      case BusinessMood.slow:
        return const Color(0xFFF59E0B);
      case BusinessMood.concerned:
        return const Color(0xFFEF4444);
      case null:
        return const Color(0xFF6366F1);
    }
  }

  _MascotExpression _getExpression(BusinessMood? mood) {
    if (widget.isThinking) return _MascotExpression.thinking;
    switch (mood) {
      case BusinessMood.thriving:
        return _MascotExpression.excited;
      case BusinessMood.good:
        return _MascotExpression.happy;
      case BusinessMood.steady:
      case null:
        return _MascotExpression.neutral;
      case BusinessMood.slow:
        return _MascotExpression.thinking;
      case BusinessMood.concerned:
        return _MascotExpression.concerned;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(aiBusinessMoodProvider)?.mood;
    final moodColor = _getMoodColor(mood);
    final expression = _getExpression(mood);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathAnimation,
          _floatAnimation,
          _glowAnimation,
          _blinkAnimation,
          _pupilAnimation,
        ]),
        builder: (context, _) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Transform.scale(
              scale: _breathAnimation.value,
              child: SizedBox(
                width: widget.size + 20,
                height: widget.size + 20,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Glow ring
                    CustomPaint(
                      size: Size(widget.size + 16, widget.size + 16),
                      painter: _GlowRingPainter(
                        color: moodColor,
                        glowAlpha: widget.isThinking
                            ? _glowAnimation.value
                            : 0.2,
                        isThinking: widget.isThinking,
                        thinkingProgress: _glowController.value,
                      ),
                    ),

                    // Main mascot
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _MascotPainter(
                        moodColor: moodColor,
                        expression: expression,
                        blinkValue: _blinkAnimation.value,
                        pupilOffset: widget.isThinking
                            ? _pupilAnimation.value * 0.15
                            : 0.0,
                      ),
                    ),

                    // Notification badge
                    if (widget.badgeCount > 0 && !widget.isThinking)
                      Positioned(
                        top: 0,
                        right: 0,
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
                              border:
                                  Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.3),
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
                    if (!widget.isThinking)
                      Positioned(
                        bottom: 2,
                        right: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: moodColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: moodColor.withValues(alpha: 0.4),
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

// ─────────────────────────────────────────────────────────
// Expressions
// ─────────────────────────────────────────────────────────
enum _MascotExpression {
  neutral,
  happy,
  excited,
  thinking,
  concerned,
}

// ─────────────────────────────────────────────────────────
// Glow ring painter
// ─────────────────────────────────────────────────────────
class _GlowRingPainter extends CustomPainter {
  final Color color;
  final double glowAlpha;
  final bool isThinking;
  final double thinkingProgress;

  _GlowRingPainter({
    required this.color,
    required this.glowAlpha,
    required this.isThinking,
    required this.thinkingProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Soft glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: glowAlpha * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, glowPaint);

    // Thinking: rotating arc segments
    if (isThinking) {
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 3; i++) {
        final startAngle =
            thinkingProgress * 2 * math.pi + (i * 2 * math.pi / 3);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 2),
          startAngle,
          0.5,
          false,
          arcPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) =>
      old.glowAlpha != glowAlpha || old.thinkingProgress != thinkingProgress;
}

// ─────────────────────────────────────────────────────────
// Main mascot painter — draws the bird/owl character
// ─────────────────────────────────────────────────────────
class _MascotPainter extends CustomPainter {
  final Color moodColor;
  final _MascotExpression expression;
  final double blinkValue; // 1.0 = eyes open, 0.0 = eyes closed
  final double pupilOffset; // -0.15 to 0.15 horizontal offset

  _MascotPainter({
    required this.moodColor,
    required this.expression,
    required this.blinkValue,
    required this.pupilOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── Body (rounded circle with gradient) ──
    final bodyRadius = w * 0.42;
    final bodyCenter = Offset(cx, cy + w * 0.02);

    // Body gradient: brand purple
    final bodyGradient = ui.Gradient.radial(
      Offset(cx - bodyRadius * 0.3, cy - bodyRadius * 0.3),
      bodyRadius * 1.6,
      [
        const Color(0xFF818CF8), // lighter indigo
        const Color(0xFF6366F1), // indigo-500
        const Color(0xFF4F46E5), // indigo-600
      ],
      [0.0, 0.5, 1.0],
    );
    final bodyPaint = Paint()..shader = bodyGradient;
    canvas.drawCircle(bodyCenter, bodyRadius, bodyPaint);

    // Body border
    final borderPaint = Paint()
      ..color = const Color(0xFF4338CA).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(bodyCenter, bodyRadius, borderPaint);

    // ── Ear tufts (little horn-like shapes on top) ──
    _drawEarTufts(canvas, cx, cy, bodyRadius);

    // ── Belly highlight ──
    final bellyCenter = Offset(cx, cy + bodyRadius * 0.25);
    final bellyRadius = bodyRadius * 0.55;
    final bellyPaint = Paint()
      ..color = const Color(0xFFE0E7FF).withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: bellyCenter,
        width: bellyRadius * 2,
        height: bellyRadius * 1.4,
      ),
      bellyPaint,
    );

    // ── Eyes ──
    _drawEyes(canvas, cx, cy, bodyRadius);

    // ── Beak ──
    _drawBeak(canvas, cx, cy, bodyRadius);

    // ── Cheek blush (for happy/excited) ──
    if (expression == _MascotExpression.happy ||
        expression == _MascotExpression.excited) {
      _drawCheekBlush(canvas, cx, cy, bodyRadius);
    }

    // ── Wings (small side shapes) ──
    _drawWings(canvas, cx, cy, bodyRadius);

    // ── Shine highlight on head ──
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - bodyRadius * 0.2, cy - bodyRadius * 0.35),
        width: bodyRadius * 0.3,
        height: bodyRadius * 0.15,
      ),
      shinePaint,
    );
  }

  void _drawEarTufts(Canvas canvas, double cx, double cy, double r) {
    final tuftPaint = Paint()..color = const Color(0xFF6366F1);

    // Left tuft
    final leftTuft = Path()
      ..moveTo(cx - r * 0.4, cy - r * 0.7)
      ..lineTo(cx - r * 0.55, cy - r * 1.15)
      ..lineTo(cx - r * 0.15, cy - r * 0.75)
      ..close();
    canvas.drawPath(leftTuft, tuftPaint);

    // Right tuft
    final rightTuft = Path()
      ..moveTo(cx + r * 0.4, cy - r * 0.7)
      ..lineTo(cx + r * 0.55, cy - r * 1.15)
      ..lineTo(cx + r * 0.15, cy - r * 0.75)
      ..close();
    canvas.drawPath(rightTuft, rightTuft == rightTuft ? tuftPaint : tuftPaint);

    // Tuft tips (lighter)
    final tipPaint = Paint()..color = const Color(0xFF818CF8);
    final leftTip = Path()
      ..moveTo(cx - r * 0.45, cy - r * 0.85)
      ..lineTo(cx - r * 0.55, cy - r * 1.15)
      ..lineTo(cx - r * 0.30, cy - r * 0.82)
      ..close();
    canvas.drawPath(leftTip, tipPaint);

    final rightTip = Path()
      ..moveTo(cx + r * 0.45, cy - r * 0.85)
      ..lineTo(cx + r * 0.55, cy - r * 1.15)
      ..lineTo(cx + r * 0.30, cy - r * 0.82)
      ..close();
    canvas.drawPath(rightTip, tipPaint);
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    final eyeY = cy - r * 0.12;
    final eyeSpacing = r * 0.35;
    final eyeRadius = r * 0.22;

    // Eye whites
    final whitePaint = Paint()..color = Colors.white;
    final leftEyeCenter = Offset(cx - eyeSpacing, eyeY);
    final rightEyeCenter = Offset(cx + eyeSpacing, eyeY);

    // Draw eye whites as ovals (slightly tall)
    final eyeRect = (Offset center) => Rect.fromCenter(
          center: center,
          width: eyeRadius * 2,
          height: eyeRadius * 2.2 * blinkValue,
        );

    if (blinkValue > 0.05) {
      canvas.drawOval(eyeRect(leftEyeCenter), whitePaint);
      canvas.drawOval(eyeRect(rightEyeCenter), whitePaint);

      // Eye border
      final eyeBorderPaint = Paint()
        ..color = const Color(0xFF312E81).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawOval(eyeRect(leftEyeCenter), eyeBorderPaint);
      canvas.drawOval(eyeRect(rightEyeCenter), eyeBorderPaint);

      // Pupils
      if (blinkValue > 0.3) {
        _drawPupils(canvas, leftEyeCenter, rightEyeCenter, eyeRadius);
      }
    } else {
      // Eyes closed — draw curved lines
      final closedPaint = Paint()
        ..color = const Color(0xFF312E81).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // Happy closed eyes: curved up (smile shape)
      if (expression == _MascotExpression.happy ||
          expression == _MascotExpression.excited) {
        for (final center in [leftEyeCenter, rightEyeCenter]) {
          final path = Path()
            ..moveTo(center.dx - eyeRadius, center.dy)
            ..quadraticBezierTo(
              center.dx,
              center.dy - eyeRadius * 0.8,
              center.dx + eyeRadius,
              center.dy,
            );
          canvas.drawPath(path, closedPaint);
        }
      } else {
        // Normal closed: horizontal lines
        for (final center in [leftEyeCenter, rightEyeCenter]) {
          canvas.drawLine(
            Offset(center.dx - eyeRadius, center.dy),
            Offset(center.dx + eyeRadius, center.dy),
            closedPaint,
          );
        }
      }
    }

    // Expression-specific eye decorations
    if (blinkValue > 0.3) {
      _drawExpressionEyes(
          canvas, leftEyeCenter, rightEyeCenter, eyeRadius);
    }
  }

  void _drawPupils(Canvas canvas, Offset leftCenter, Offset rightCenter,
      double eyeRadius) {
    final pupilRadius = eyeRadius * 0.55;
    final pupilPaint = Paint()..color = const Color(0xFF1E1B4B);

    // Pupil offset based on thinking animation
    final offset = Offset(pupilOffset * eyeRadius, 0);

    canvas.drawCircle(leftCenter + offset, pupilRadius, pupilPaint);
    canvas.drawCircle(rightCenter + offset, pupilRadius, pupilPaint);

    // Pupil highlight (white dot)
    final highlightPaint = Paint()..color = Colors.white;
    final hlOffset = Offset(
      -pupilRadius * 0.3 + pupilOffset * eyeRadius,
      -pupilRadius * 0.3,
    );
    canvas.drawCircle(
        leftCenter + hlOffset, pupilRadius * 0.3, highlightPaint);
    canvas.drawCircle(
        rightCenter + hlOffset, pupilRadius * 0.3, highlightPaint);
  }

  void _drawExpressionEyes(Canvas canvas, Offset leftCenter,
      Offset rightCenter, double eyeRadius) {
    switch (expression) {
      case _MascotExpression.excited:
        // Star sparkles near eyes
        final sparklePaint = Paint()
          ..color = const Color(0xFFFBBF24).withValues(alpha: 0.8);
        for (final center in [leftCenter, rightCenter]) {
          _drawSparkle(
            canvas,
            Offset(center.dx + eyeRadius * 1.1, center.dy - eyeRadius * 0.6),
            eyeRadius * 0.2,
            sparklePaint,
          );
        }
        break;
      case _MascotExpression.concerned:
        // Worried eyebrows (angled lines above eyes)
        final browPaint = Paint()
          ..color = const Color(0xFF312E81).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        // Left eyebrow: angled down-out
        canvas.drawLine(
          Offset(leftCenter.dx - eyeRadius * 0.6,
              leftCenter.dy - eyeRadius * 1.5),
          Offset(leftCenter.dx + eyeRadius * 0.6,
              leftCenter.dy - eyeRadius * 1.2),
          browPaint,
        );
        // Right eyebrow: angled down-out (mirrored)
        canvas.drawLine(
          Offset(rightCenter.dx - eyeRadius * 0.6,
              rightCenter.dy - eyeRadius * 1.2),
          Offset(rightCenter.dx + eyeRadius * 0.6,
              rightCenter.dy - eyeRadius * 1.5),
          browPaint,
        );
        break;
      default:
        break;
    }
  }

  void _drawSparkle(
      Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final outerX = center.dx + size * math.cos(angle);
      final outerY = center.dy + size * math.sin(angle);
      final innerAngle = angle + math.pi / 4;
      final innerX = center.dx + size * 0.35 * math.cos(innerAngle);
      final innerY = center.dy + size * 0.35 * math.sin(innerAngle);

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBeak(Canvas canvas, double cx, double cy, double r) {
    final beakY = cy + r * 0.15;
    final beakSize = r * 0.18;

    // Beak: small rounded triangle
    final beakPaint = Paint()..color = const Color(0xFFFBBF24);
    final beakPath = Path()
      ..moveTo(cx - beakSize, beakY)
      ..quadraticBezierTo(cx, beakY + beakSize * 1.3, cx + beakSize, beakY)
      ..quadraticBezierTo(cx, beakY - beakSize * 0.3, cx - beakSize, beakY)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    // Beak highlight
    final beakHighlightPaint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.6);
    final highlightPath = Path()
      ..moveTo(cx - beakSize * 0.5, beakY)
      ..quadraticBezierTo(
          cx, beakY + beakSize * 0.5, cx + beakSize * 0.5, beakY)
      ..quadraticBezierTo(
          cx, beakY - beakSize * 0.15, cx - beakSize * 0.5, beakY)
      ..close();
    canvas.drawPath(highlightPath, beakHighlightPaint);

    // Mouth expression below beak
    if (expression == _MascotExpression.happy ||
        expression == _MascotExpression.excited) {
      // Small smile curve below beak
      final smilePaint = Paint()
        ..color = const Color(0xFF4338CA).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      final smilePath = Path()
        ..moveTo(cx - beakSize * 0.7, beakY + beakSize * 1.1)
        ..quadraticBezierTo(
          cx,
          beakY + beakSize * 1.6,
          cx + beakSize * 0.7,
          beakY + beakSize * 1.1,
        );
      canvas.drawPath(smilePath, smilePaint);
    } else if (expression == _MascotExpression.concerned) {
      // Small frown
      final frownPaint = Paint()
        ..color = const Color(0xFF4338CA).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      final frownPath = Path()
        ..moveTo(cx - beakSize * 0.5, beakY + beakSize * 1.5)
        ..quadraticBezierTo(
          cx,
          beakY + beakSize * 1.0,
          cx + beakSize * 0.5,
          beakY + beakSize * 1.5,
        );
      canvas.drawPath(frownPath, frownPaint);
    }
  }

  void _drawCheekBlush(Canvas canvas, double cx, double cy, double r) {
    final blushPaint = Paint()
      ..color = const Color(0xFFFDA4AF).withValues(alpha: 0.35);
    final blushRadius = r * 0.14;
    final blushY = cy + r * 0.15;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - r * 0.55, blushY),
        width: blushRadius * 2.2,
        height: blushRadius * 1.5,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + r * 0.55, blushY),
        width: blushRadius * 2.2,
        height: blushRadius * 1.5,
      ),
      blushPaint,
    );
  }

  void _drawWings(Canvas canvas, double cx, double cy, double r) {
    final wingPaint = Paint()
      ..color = const Color(0xFF4F46E5).withValues(alpha: 0.7);

    // Left wing
    final leftWing = Path()
      ..moveTo(cx - r * 0.85, cy + r * 0.1)
      ..quadraticBezierTo(
        cx - r * 1.15,
        cy - r * 0.1,
        cx - r * 0.95,
        cy - r * 0.35,
      )
      ..quadraticBezierTo(
        cx - r * 0.75,
        cy - r * 0.1,
        cx - r * 0.72,
        cy + r * 0.15,
      )
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Right wing
    final rightWing = Path()
      ..moveTo(cx + r * 0.85, cy + r * 0.1)
      ..quadraticBezierTo(
        cx + r * 1.15,
        cy - r * 0.1,
        cx + r * 0.95,
        cy - r * 0.35,
      )
      ..quadraticBezierTo(
        cx + r * 0.75,
        cy - r * 0.1,
        cx + r * 0.72,
        cy + r * 0.15,
      )
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Wing highlight
    final wingHighlight = Paint()
      ..color = const Color(0xFF818CF8).withValues(alpha: 0.4);
    final leftHighlight = Path()
      ..moveTo(cx - r * 0.83, cy + r * 0.05)
      ..quadraticBezierTo(
        cx - r * 1.0,
        cy - r * 0.05,
        cx - r * 0.90,
        cy - r * 0.2,
      )
      ..quadraticBezierTo(
        cx - r * 0.80,
        cy - r * 0.05,
        cx - r * 0.78,
        cy + r * 0.1,
      )
      ..close();
    canvas.drawPath(leftHighlight, wingHighlight);

    final rightHighlight = Path()
      ..moveTo(cx + r * 0.83, cy + r * 0.05)
      ..quadraticBezierTo(
        cx + r * 1.0,
        cy - r * 0.05,
        cx + r * 0.90,
        cy - r * 0.2,
      )
      ..quadraticBezierTo(
        cx + r * 0.80,
        cy - r * 0.05,
        cx + r * 0.78,
        cy + r * 0.1,
      )
      ..close();
    canvas.drawPath(rightHighlight, wingHighlight);
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.blinkValue != blinkValue ||
      old.pupilOffset != pupilOffset ||
      old.expression != expression ||
      old.moodColor != moodColor;
}

// ─────────────────────────────────────────────────────────
// Mini avatar for inline use (message bubbles, headers)
// ─────────────────────────────────────────────────────────

/// A static (non-animated) version of the Utter mascot for use
/// in message bubbles, headers, and other inline contexts.
class UtterMiniAvatar extends StatelessWidget {
  final double size;

  const UtterMiniAvatar({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _MascotPainter(
            moodColor: const Color(0xFF6366F1),
            expression: _MascotExpression.neutral,
            blinkValue: 1.0,
            pupilOffset: 0.0,
          ),
        ),
      ),
    );
  }
}
