import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../shared/themes/app_theme.dart';
import '../providers/pos_shift_provider.dart';
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
              // Utter logo - fixed logic for correct contrast
              if (!isMobile)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/logo_utter_dark_sm.png' // Light gray for dark mode
                        : 'assets/images/logo_utter_light_sm.png', // Dark charcoal for light mode
                    height: 32,
                    fit: BoxFit.contain,
                  ),
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
          // Right side: Close shift button + Automation toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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


            ],
          ),
        ],
      ),
    );
  }
}
