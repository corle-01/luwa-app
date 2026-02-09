import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../shared/themes/app_theme.dart';
import '../online_food/online_food_screen.dart';
import '../providers/pos_shift_provider.dart';
import 'automation_toggle.dart';
import 'shift_close_dialog.dart';

class PosHeader extends ConsumerStatefulWidget {
  const PosHeader({super.key});

  @override
  ConsumerState<PosHeader> createState() => _PosHeaderState();
}

class _PosHeaderState extends ConsumerState<PosHeader> {
  late Timer _timer;
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(posShiftNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: Logo + Clock
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Utter logo
              if (!isMobile)
                Image.asset(
                  'assets/images/logo_utter_dark_sm.png',
                  height: 24,
                  fit: BoxFit.contain,
                ),
              if (!isMobile) const SizedBox(width: 16),
              // Clock with monospace look
              Text(
                _timeString,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(width: isMobile ? 8 : 24),
          // Middle: Shift status pill
          Expanded(
            child: shiftAsync.when(
              data: (shift) {
                if (shift == null) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tidak Ada Shift',
                          style: GoogleFonts.inter(
                            color: AppTheme.errorColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Active shift pill with green dot + duration + cashier name
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aktif ${shift.durationFormatted}',
                        style: GoogleFonts.inter(
                          color: AppTheme.successColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (shift.cashierName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 12,
                          color: AppTheme.successColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shift.cashierName!,
                          style: GoogleFonts.inter(
                            color: AppTheme.successColor.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
          const Spacer(),
          // Right side: Online Food + Close shift button + Automation toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Online Food button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnlineFoodScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delivery_dining, size: 16, color: Colors.white),
                        if (!isMobile) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Online Food',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 12),
              shiftAsync.whenData((shift) {
                if (shift != null) {
                  return TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ShiftCloseDialog(),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Tutup Shift'),
                  );
                }
                return const SizedBox.shrink();
              }).value ?? const SizedBox.shrink(),
              if (!isMobile) const SizedBox(width: 8),
              if (!isMobile) const AutomationToggle(),
            ],
          ),
        ],
      ),
    );
  }
}
