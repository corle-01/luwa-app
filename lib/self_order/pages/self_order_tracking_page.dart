import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../shared/themes/app_theme.dart';
import '../providers/self_order_provider.dart';
import '../services/browser_notification_service.dart';
import 'self_order_menu_page.dart';

// ---------------------------------------------------------------------------
// Currency formatter
// ---------------------------------------------------------------------------
final _currencyFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Order tracking page for customer self-order flow.
///
/// Displays a visual status timeline, order items with kitchen status badges,
/// and auto-refreshes every 10 seconds via [selfOrderTrackingProvider].
///
/// Features browser push notification and in-app banner when order becomes
/// ready (step 2) or served (step 3).
class SelfOrderTrackingPage extends ConsumerWidget {
  final String orderId;
  final String tableId;

  const SelfOrderTrackingPage({
    super.key,
    required this.orderId,
    required this.tableId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(selfOrderTrackingProvider(orderId));
    final tableAsync = ref.watch(selfOrderTableInfoProvider(tableId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        body: SafeArea(
          child: orderAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            ),
            error: (error, _) => _buildErrorState(context, ref),
            data: (orderData) {
              if (orderData == null) {
                return _buildErrorState(context, ref);
              }

              final tableNumber = tableAsync.whenOrNull(
                data: (data) => data?['table_number']?.toString(),
              );

              return _TrackingBody(
                orderData: orderData,
                tableNumber: tableNumber,
                tableId: tableId,
                orderId: orderId,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppTheme.errorColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pesanan Tidak Ditemukan',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak dapat memuat data pesanan. Coba lagi.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.invalidate(selfOrderTrackingProvider(orderId)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TRACKING BODY (Stateful for elapsed time ticker + notifications)
// =============================================================================
class _TrackingBody extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String? tableNumber;
  final String tableId;
  final String orderId;

  const _TrackingBody({
    required this.orderData,
    required this.tableNumber,
    required this.tableId,
    required this.orderId,
  });

  @override
  State<_TrackingBody> createState() => _TrackingBodyState();
}

class _TrackingBodyState extends State<_TrackingBody>
    with TickerProviderStateMixin {
  late DateTime _orderTime;
  String _elapsedText = '';

  // ---------------------------------------------------------------------------
  // Notification state
  // ---------------------------------------------------------------------------
  int _previousStep = -1; // -1 = not yet initialised
  bool _notificationPermissionRequested = false;
  bool _showReadyBanner = false;

  // Animation controllers for the in-app ready banner
  late AnimationController _bannerSlideController;
  late Animation<Offset> _bannerSlideAnimation;
  late AnimationController _bannerPulseController;
  late Animation<double> _bannerPulseAnimation;
  late AnimationController _bannerIconBounceController;
  late Animation<double> _bannerIconBounceAnimation;

  @override
  void initState() {
    super.initState();
    _parseOrderTime();
    _updateElapsed();

    // Set up banner animations
    _bannerSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerSlideController,
      curve: Curves.easeOutBack,
    ));

    _bannerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bannerPulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _bannerPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _bannerIconBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bannerIconBounceAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _bannerIconBounceController,
      curve: Curves.elasticOut,
    ));

    // Initialise previous step from the first data we receive
    _previousStep = _getCurrentStep();

    // If order is already at step >= 2 on first load, show the banner
    if (_previousStep >= 2) {
      _showReadyBanner = true;
      // Animate banner in after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bannerSlideController.forward();
        _bannerPulseController.repeat(reverse: true);
        _bannerIconBounceController.forward();
      });
    }

    // Request browser notification permission
    _requestNotificationPermission();
  }

  @override
  void dispose() {
    _bannerSlideController.dispose();
    _bannerPulseController.dispose();
    _bannerIconBounceController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Browser Notification permission request
  // ---------------------------------------------------------------------------
  Future<void> _requestNotificationPermission() async {
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;

    try {
      if (!isNotificationSupported()) return;
      final permission = getNotificationPermission();
      if (permission == 'default') {
        await requestNotificationPermission();
      }
    } catch (_) {
      // Notification API not available (e.g. non-browser platform) — ignore
    }
  }

  // ---------------------------------------------------------------------------
  // Fire browser notification + trigger in-app banner
  // ---------------------------------------------------------------------------
  void _onOrderBecameReady() {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Show browser push notification
    try {
      if (isNotificationSupported()) {
        showBrowserNotification(
          'Pesanan Siap!',
          'Pesanan Anda sudah siap diambil',
        );
      }
    } catch (_) {
      // Silently ignore if Notification API fails
    }

    // Show in-app animated banner
    setState(() {
      _showReadyBanner = true;
    });
    _bannerSlideController.forward(from: 0.0);
    _bannerPulseController.repeat(reverse: true);
    _bannerIconBounceController.forward(from: 0.0);
  }

  void _onOrderServed() {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Show browser push notification
    try {
      if (isNotificationSupported()) {
        showBrowserNotification(
          'Pesanan Disajikan!',
          'Pesanan Anda telah disajikan. Selamat menikmati!',
        );
      }
    } catch (_) {
      // Silently ignore
    }

    // Keep the banner visible (update text in build)
    if (!_showReadyBanner) {
      setState(() {
        _showReadyBanner = true;
      });
      _bannerSlideController.forward(from: 0.0);
      _bannerPulseController.repeat(reverse: true);
      _bannerIconBounceController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _TrackingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _parseOrderTime();
    _updateElapsed();

    // Detect status transitions
    final newStep = _getCurrentStep();
    if (_previousStep >= 0 && newStep != _previousStep) {
      // Transition to "ready" (step 2)
      if (newStep >= 2 && _previousStep < 2) {
        _onOrderBecameReady();
      }
      // Transition to "served/completed" (step 3)
      else if (newStep >= 3 && _previousStep < 3) {
        _onOrderServed();
      }
    }
    _previousStep = newStep;
  }

  void _parseOrderTime() {
    final createdAt = widget.orderData['created_at'] as String?;
    if (createdAt != null) {
      _orderTime = DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now();
    } else {
      _orderTime = DateTime.now();
    }
  }

  void _updateElapsed() {
    final diff = DateTime.now().difference(_orderTime);
    if (diff.inMinutes < 1) {
      _elapsedText = 'Baru saja';
    } else if (diff.inMinutes < 60) {
      _elapsedText = '${diff.inMinutes} menit lalu';
    } else {
      _elapsedText = '${diff.inHours} jam ${diff.inMinutes % 60} menit lalu';
    }
  }

  /// Determine current step index (0-3) based on order/kitchen status
  int _getCurrentStep() {
    final status = widget.orderData['status'] as String? ?? 'pending';
    final items = (widget.orderData['order_items'] as List<dynamic>?) ?? [];

    // Check aggregate kitchen status from items
    bool anyInProgress = false;
    bool allReady = items.isNotEmpty;
    bool allServed = items.isNotEmpty;

    for (final item in items) {
      final ks = (item as Map<String, dynamic>)['kitchen_status'] as String? ??
          'pending';
      if (ks == 'in_progress' || ks == 'cooking') anyInProgress = true;
      if (ks != 'ready' && ks != 'served') allReady = false;
      if (ks != 'served') allServed = false;
    }

    if (status == 'completed' || allServed) return 3;
    if (allReady) return 2;
    if (anyInProgress) return 1;
    return 0;
  }

  void _showCallWaiterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 32,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Panggil Pelayan',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pelayan akan segera menuju meja Anda.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pelayan telah dipanggil!',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.successColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Ya, Panggil Pelayan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismissBanner() {
    _bannerSlideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showReadyBanner = false;
        });
        _bannerPulseController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber =
        widget.orderData['order_number'] as String? ?? '-';
    final items =
        (widget.orderData['order_items'] as List<dynamic>?) ?? [];
    final currentStep = _getCurrentStep();

    return Column(
      children: [
        // Header
        _buildHeader(orderNumber),

        // In-app ready banner (animated, shown above the scroll content)
        if (_showReadyBanner) _buildReadyBanner(currentStep),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table & elapsed info
                _buildInfoRow(currentStep),

                const SizedBox(height: 24),

                // Status timeline
                _buildTimeline(currentStep),

                const SizedBox(height: 28),

                // Items list header
                Row(
                  children: [
                    Text(
                      'Detail Pesanan',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} item',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Items list
                ...items.map((item) =>
                    _buildItemCard(item as Map<String, dynamic>)),

                const SizedBox(height: 24),

                // Auto-refresh indicator
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.textTertiary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Diperbarui otomatis setiap 10 detik',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Action buttons
                _buildActionButtons(),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // READY BANNER (animated in-app notification)
  // ===========================================================================
  Widget _buildReadyBanner(int currentStep) {
    final isServed = currentStep >= 3;
    final bannerTitle = isServed ? 'Pesanan Disajikan!' : 'Pesanan Siap!';
    final bannerSubtitle = isServed
        ? 'Pesanan Anda telah disajikan. Selamat menikmati!'
        : 'Pesanan Anda sudah siap diambil';
    final bannerIcon = isServed
        ? Icons.done_all_rounded
        : Icons.room_service_rounded;
    final bannerGradient = isServed
        ? const [Color(0xFF10B981), Color(0xFF059669)]
        : const [Color(0xFF10B981), Color(0xFF34D399)];

    return SlideTransition(
      position: _bannerSlideAnimation,
      child: AnimatedBuilder(
        animation: _bannerPulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _bannerPulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bannerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.successColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _dismissBanner,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    // Animated bell/service icon
                    AnimatedBuilder(
                      animation: _bannerIconBounceController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: math.sin(
                                  _bannerIconBounceAnimation.value * math.pi * 4) *
                              0.15 *
                              (1 - _bannerIconBounceAnimation.value),
                          child: Transform.scale(
                            scale: 0.5 +
                                (_bannerIconBounceAnimation.value * 0.5),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            bannerIcon,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            bannerTitle,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bannerSubtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dismiss button
                    IconButton(
                      onPressed: _dismissBanner,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
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

  // ===========================================================================
  // HEADER
  // ===========================================================================
  Widget _buildHeader(String orderNumber) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(
            children: [
              Text(
                'Pesanan Kamu',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  orderNumber,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INFO ROW (Table number + elapsed time)
  // ===========================================================================
  Widget _buildInfoRow(int currentStep) {
    final statusLabels = [
      'Menunggu Konfirmasi',
      'Sedang Dimasak',
      'Siap Disajikan',
      'Selesai',
    ];

    final statusColors = [
      AppTheme.accentColor,
      AppTheme.infoColor,
      AppTheme.successColor,
      AppTheme.successColor,
    ];

    return Row(
      children: [
        // Table info chip
        if (widget.tableNumber != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 16,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Meja ${widget.tableNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(width: 10),

        // Elapsed time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                _elapsedText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColors[currentStep].withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusLabels[currentStep],
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColors[currentStep],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STATUS TIMELINE
  // ===========================================================================
  Widget _buildTimeline(int currentStep) {
    final steps = [
      _TimelineStep(
        title: 'Pesanan Diterima',
        subtitle: 'Pesanan masuk ke sistem',
        icon: Icons.receipt_long_rounded,
      ),
      _TimelineStep(
        title: 'Sedang Dimasak',
        subtitle: 'Dapur sedang menyiapkan',
        icon: Icons.soup_kitchen_rounded,
      ),
      _TimelineStep(
        title: 'Siap Disajikan',
        subtitle: 'Makanan siap diantar',
        icon: Icons.room_service_rounded,
      ),
      _TimelineStep(
        title: 'Selesai',
        subtitle: 'Pesanan telah disajikan',
        icon: Icons.check_circle_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isCompleted = index <= currentStep;
          final isActive = index == currentStep;
          final isLast = index == steps.length - 1;

          return _buildTimelineStep(
            step: step,
            isCompleted: isCompleted,
            isActive: isActive,
            isLast: isLast,
          );
        }),
      ),
    );
  }

  Widget _buildTimelineStep({
    required _TimelineStep step,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    final activeColor = isCompleted ? AppTheme.successColor : AppTheme.borderColor;
    final textColor =
        isCompleted ? AppTheme.textPrimary : AppTheme.textTertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator column
        Column(
          children: [
            // Circle/dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: isActive ? 40 : 32,
              height: isActive ? 40 : 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? activeColor.withValues(alpha: isActive ? 1.0 : 0.15)
                    : AppTheme.dividerColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: isActive
                    ? null
                    : Border.all(
                        color: isCompleted
                            ? activeColor.withValues(alpha: 0.3)
                            : AppTheme.dividerColor,
                        width: 2,
                      ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  step.icon,
                  size: isActive ? 20 : 16,
                  color: isActive
                      ? Colors.white
                      : (isCompleted ? activeColor : AppTheme.textTertiary),
                ),
              ),
            ),

            // Line connector
            if (!isLast)
              Container(
                width: 2.5,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? activeColor.withValues(alpha: 0.3)
                      : AppTheme.dividerColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),

        const SizedBox(width: 16),

        // Step text
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: isActive ? 6 : 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.inter(
                    fontSize: isActive ? 15 : 14,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isCompleted
                        ? AppTheme.textSecondary
                        : AppTheme.textTertiary,
                  ),
                ),
                if (!isLast) const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ITEM CARD
  // ===========================================================================
  Widget _buildItemCard(Map<String, dynamic> item) {
    final productName = item['product_name'] as String? ?? '-';
    final quantity = item['quantity'] as int? ?? 1;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
    final kitchenStatus = item['kitchen_status'] as String? ?? 'pending';
    final notes = item['notes'] as String?;
    final modifiers = item['modifiers'] as List<dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity badge
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${quantity}x',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),

                // Modifiers
                if (modifiers != null && modifiers.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    modifiers
                        .map((m) =>
                            (m as Map<String, dynamic>)['option'] ?? '')
                        .where((s) => s.toString().isNotEmpty)
                        .join(', '),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Notes
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '"$notes"',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.accentColor,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 6),

                // Price
                Text(
                  _currencyFormat.format(subtotal),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Kitchen status badge
          _buildKitchenBadge(kitchenStatus),
        ],
      ),
    );
  }

  Widget _buildKitchenBadge(String status) {
    final config = _kitchenStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 12,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _KitchenStatusConfig _kitchenStatusConfig(String status) {
    switch (status) {
      case 'in_progress':
      case 'cooking':
        return _KitchenStatusConfig(
          label: 'Dimasak',
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.accentColor,
        );
      case 'ready':
        return _KitchenStatusConfig(
          label: 'Siap',
          icon: Icons.check_circle_rounded,
          color: AppTheme.successColor,
        );
      case 'served':
        return _KitchenStatusConfig(
          label: 'Disajikan',
          icon: Icons.done_all_rounded,
          color: AppTheme.successColor,
        );
      case 'pending':
      default:
        return _KitchenStatusConfig(
          label: 'Menunggu',
          icon: Icons.schedule_rounded,
          color: AppTheme.textTertiary,
        );
    }
  }

  // ===========================================================================
  // ACTION BUTTONS
  // ===========================================================================
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Order again
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        SelfOrderMenuPage(tableId: widget.tableId),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
              label: Text(
                'Pesan Lagi',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Call waiter
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCallWaiterDialog,
            icon: Icon(
              Icons.notifications_active_rounded,
              size: 20,
              color: AppTheme.accentColor.withValues(alpha: 0.8),
            ),
            label: Text(
              'Panggil Pelayan',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.accentColor.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HELPER MODELS
// =============================================================================
class _TimelineStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _KitchenStatusConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _KitchenStatusConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
