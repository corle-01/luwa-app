import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/services/sync_service.dart';

// ---------------------------------------------------------------------------
// Offline Indicator Widget
// ---------------------------------------------------------------------------

/// A banner that slides in at the top of the screen to indicate connectivity
/// status and pending sync operations.
///
/// Usage: Place inside a [Stack] or [Column] at the top of your main layout.
///
/// ```dart
/// Stack(
///   children: [
///     // ... main content ...
///     const Positioned(top: 0, left: 0, right: 0, child: OfflineIndicator()),
///   ],
/// )
/// ```
///
/// States:
///   - **Online, no pending**: Hidden (zero height).
///   - **Online, pending > 0**: Blue info banner with pending count + sync button.
///   - **Offline**: Red banner with offline message.
///   - **Syncing**: Amber banner with progress message + spinning indicator.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectivityStatusProvider);
    final pendingCount = ref.watch(pendingQueueCountProvider);
    final totalCount = ref.watch(totalQueueCountProvider);

    // Determine the current display state
    final status = statusAsync.when(
      data: (s) => s,
      loading: () => ConnectivityStatus.online,
      error: (_, __) => ConnectivityStatus.online,
    );

    // Decide whether to show the banner
    final bool shouldShow =
        status == ConnectivityStatus.offline ||
        status == ConnectivityStatus.syncing ||
        pendingCount > 0;

    return _AnimatedBanner(
      visible: shouldShow,
      child: _BannerContent(
        status: status,
        pendingCount: pendingCount,
        totalCount: totalCount,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated slide wrapper
// ---------------------------------------------------------------------------

class _AnimatedBanner extends StatefulWidget {
  final bool visible;
  final Widget child;

  const _AnimatedBanner({required this.visible, required this.child});

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    if (widget.visible) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward();
    } else if (!widget.visible && oldWidget.visible) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner content (status-dependent)
// ---------------------------------------------------------------------------

class _BannerContent extends ConsumerWidget {
  final ConnectivityStatus status;
  final int pendingCount;
  final int totalCount;

  const _BannerContent({
    required this.status,
    required this.pendingCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _BannerStyle style = _styleFor(status, pendingCount);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Icon / spinner
              if (status == ConnectivityStatus.syncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(style.icon, color: Colors.white, size: 18),

              const SizedBox(width: 10),

              // Message
              Expanded(
                child: Text(
                  style.message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),

              // Pending count badge
              if (pendingCount > 0 && status != ConnectivityStatus.syncing)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pendingCount antrian',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Manual sync button (only when online with pending items)
              if (status == ConnectivityStatus.online && pendingCount > 0) ...[
                const SizedBox(width: 8),
                const _SyncButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _BannerStyle _styleFor(ConnectivityStatus status, int pendingCount) {
    switch (status) {
      case ConnectivityStatus.offline:
        return _BannerStyle(
          backgroundColor: const Color(0xFFEF4444), // errorColor
          icon: Icons.cloud_off_rounded,
          message: pendingCount > 0
              ? 'Anda sedang offline. $pendingCount pesanan menunggu sinkronisasi.'
              : 'Anda sedang offline. Pesanan akan disimpan dan disinkronkan.',
        );

      case ConnectivityStatus.syncing:
        return _BannerStyle(
          backgroundColor: const Color(0xFFF59E0B), // warningColor / amber
          icon: Icons.cloud_sync_rounded,
          message: 'Menyinkronkan $totalCount pesanan...',
        );

      case ConnectivityStatus.online:
        // Online but with pending items (shouldn't happen often,
        // but covers the brief window before auto-sync kicks in)
        return _BannerStyle(
          backgroundColor: const Color(0xFF3B82F6), // infoColor
          icon: Icons.cloud_upload_rounded,
          message: '$pendingCount pesanan belum disinkronkan.',
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sync button
// ---------------------------------------------------------------------------

class _SyncButton extends ConsumerWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final syncService = ref.read(syncServiceProvider);
          syncService.syncNow();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                'Sinkronkan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal style helper
// ---------------------------------------------------------------------------

class _BannerStyle {
  final Color backgroundColor;
  final IconData icon;
  final String message;

  const _BannerStyle({
    required this.backgroundColor,
    required this.icon,
    required this.message,
  });
}
