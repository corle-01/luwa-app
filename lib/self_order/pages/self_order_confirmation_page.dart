import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/themes/app_theme.dart';
import '../providers/self_order_provider.dart';
import 'self_order_menu_page.dart';
import 'self_order_tracking_page.dart';

/// Success/confirmation page displayed after a self-order is submitted.
///
/// Shows an animated checkmark, the order number, table info,
/// and navigation buttons for tracking or ordering again.
class SelfOrderConfirmationPage extends ConsumerStatefulWidget {
  final String orderId;
  final String tableId;
  final String paymentMethod;

  const SelfOrderConfirmationPage({
    super.key,
    required this.orderId,
    required this.tableId,
    this.paymentMethod = 'cash',
  });

  @override
  ConsumerState<SelfOrderConfirmationPage> createState() =>
      _SelfOrderConfirmationPageState();
}

class _SelfOrderConfirmationPageState
    extends ConsumerState<SelfOrderConfirmationPage>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  late AnimationController _contentController;
  late Animation<double> _contentSlide;
  late Animation<double> _contentOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    // Checkmark animation
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: Curves.elasticOut,
      ),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Content slide-up animation
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOutCubic,
      ),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOut,
      ),
    );

    // Subtle pulse on the checkmark ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Stagger the animations
    _checkController.forward().then((_) {
      HapticFeedback.heavyImpact();
      _contentController.forward();
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToTracking() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SelfOrderTrackingPage(
          orderId: widget.orderId,
          tableId: widget.tableId,
        ),
      ),
    );
  }

  void _navigateToMenu() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SelfOrderMenuPage(tableId: widget.tableId),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync =
        ref.watch(selfOrderTrackingProvider(widget.orderId));
    final tableAsync =
        ref.watch(selfOrderTableInfoProvider(widget.tableId));

    final orderNumber = orderAsync.whenOrNull(
      data: (data) => data?['order_number'] as String?,
    );
    final tableNumber = tableAsync.whenOrNull(
      data: (data) => data?['table_number']?.toString(),
    );

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Animated checkmark
                  _buildCheckmark(),

                  const SizedBox(height: 32),

                  // Title & subtitle (animated)
                  AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _contentOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _contentSlide.value),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'Pesanan Berhasil!',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Pesananmu sedang disiapkan oleh dapur',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),

                        // Order number
                        if (orderNumber != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Nomor Pesanan',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  orderNumber,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Info cards row
                        Row(
                          children: [
                            // Table number
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.table_restaurant_rounded,
                                label: 'Nomor Meja',
                                value: tableNumber ?? '-',
                                color: AppTheme.infoColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Estimated time
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.schedule_rounded,
                                label: 'Perkiraan',
                                value: '10-15 menit',
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Payment status info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.paymentMethod == 'qris'
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.paymentMethod == 'qris'
                                  ? const Color(0xFF059669).withValues(alpha: 0.2)
                                  : const Color(0xFFD97706).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.paymentMethod == 'qris'
                                    ? Icons.check_circle_rounded
                                    : Icons.payments_rounded,
                                size: 24,
                                color: widget.paymentMethod == 'qris'
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.paymentMethod == 'qris'
                                          ? 'Pembayaran QRIS'
                                          : 'Bayar di Kasir',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: widget.paymentMethod == 'qris'
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.paymentMethod == 'qris'
                                          ? 'Pembayaran sedang diverifikasi kasir'
                                          : 'Silakan bayar di kasir saat pesanan siap',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: widget.paymentMethod == 'qris'
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        // CTA Buttons
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _navigateToTracking,
                              icon: const Icon(
                                  Icons.track_changes_rounded,
                                  size: 20),
                              label: Text(
                                'Lacak Pesanan',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _navigateToMenu,
                            icon: const Icon(
                                Icons.restaurant_menu_rounded,
                                size: 20),
                            label: Text(
                              'Pesan Lagi',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ANIMATED CHECKMARK
  // ===========================================================================
  Widget _buildCheckmark() {
    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _pulseController]),
      builder: (context, child) {
        return Opacity(
          opacity: _checkOpacity.value,
          child: Transform.scale(
            scale: _checkScale.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse ring
                if (_pulseController.isAnimating)
                  Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.15),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                // Main circle
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successColor,
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.successColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // INFO CARD
  // ===========================================================================
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 22,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
