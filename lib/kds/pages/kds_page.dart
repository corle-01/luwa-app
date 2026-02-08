import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/kds_order.dart';
import '../providers/kds_provider.dart';
import '../repositories/kds_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KDS Color Palette — dark theme for kitchen screens
// ─────────────────────────────────────────────────────────────────────────────

class _KdsColors {
  static const Color background = Color(0xFF1A1A2E);
  static const Color card = Color(0xFF16213E);
  static const Color cardBorder = Color(0xFF1F3460);
  static const Color surface = Color(0xFF0F3460);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B8C8);
  static const Color textMuted = Color(0xFF6B7A94);

  // Status colors
  static const Color statusPending = Color(0xFF6B7A94);
  static const Color statusCooking = Color(0xFFF59E0B);
  static const Color statusReady = Color(0xFF10B981);
  static const Color statusServed = Color(0xFF3B82F6);

  // Timer colors
  static const Color timerGreen = Color(0xFF10B981);
  static const Color timerAmber = Color(0xFFF59E0B);
  static const Color timerRed = Color(0xFFEF4444);

  // Card tints by kitchen status
  static const Color cardWaiting = Color(0xFF16213E);
  static const Color cardInProgress = Color(0xFF1E2A1A);
  static const Color cardReady = Color(0xFF0F2922);

  // Badge backgrounds
  static const Color badgePendingBg = Color(0xFF2D3748);
  static const Color badgeCookingBg = Color(0xFF78350F);
  static const Color badgeReadyBg = Color(0xFF064E3B);
}

// ─────────────────────────────────────────────────────────────────────────────
// KDS Page — Full screen kitchen display
// ─────────────────────────────────────────────────────────────────────────────

class KdsPage extends ConsumerStatefulWidget {
  const KdsPage({super.key});

  @override
  ConsumerState<KdsPage> createState() => _KdsPageState();
}

class _KdsPageState extends ConsumerState<KdsPage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  int _previousOrderCount = -1; // -1 means first load, skip flash
  bool _flashNewOrder = false;

  @override
  void initState() {
    super.initState();
    // Update clock + elapsed timers every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  /// Detect new orders arriving and flash
  void _checkForNewOrders(int currentCount) {
    if (_previousOrderCount == -1) {
      // First load — do not flash
      _previousOrderCount = currentCount;
      return;
    }
    if (currentCount > _previousOrderCount) {
      setState(() => _flashNewOrder = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _flashNewOrder = false);
      });
    }
    _previousOrderCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auto-refresh stream to keep orders fresh
    ref.listen(kdsAutoRefreshProvider, (_, __) {});

    final ordersAsync = ref.watch(kdsOrdersProvider);
    final waitingCount = ref.watch(kdsWaitingCountProvider);
    final inProgressCount = ref.watch(kdsInProgressCountProvider);
    final readyCount = ref.watch(kdsReadyCountProvider);

    return Scaffold(
      backgroundColor: _KdsColors.background,
      body: Column(
        children: [
          // ── Top bar ──
          _KdsTopBar(
            now: _now,
            waitingCount: waitingCount,
            inProgressCount: inProgressCount,
            readyCount: readyCount,
            flashNewOrder: _flashNewOrder,
          ),

          // ── Main content ──
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: _KdsColors.statusCooking,
                ),
              ),
              error: (error, _) => _KdsErrorState(
                error: error.toString(),
                onRetry: () => ref.invalidate(kdsOrdersProvider),
              ),
              data: (orders) {
                _checkForNewOrders(orders.length);

                if (orders.isEmpty) {
                  return const _KdsEmptyState();
                }

                return _KdsOrderGrid(
                  orders: orders,
                  now: _now,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _KdsTopBar extends StatelessWidget {
  final DateTime now;
  final int waitingCount;
  final int inProgressCount;
  final int readyCount;
  final bool flashNewOrder;

  const _KdsTopBar({
    required this.now,
    required this.waitingCount,
    required this.inProgressCount,
    required this.readyCount,
    required this.flashNewOrder,
  });

  String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: _KdsColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Chef hat icon + title
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _KdsColors.statusCooking.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant,
              color: _KdsColors.statusCooking,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Kitchen Display',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _KdsColors.textPrimary,
            ),
          ),

          const SizedBox(width: 24),

          // Status badges
          _StatusBadge(
            label: '$waitingCount Menunggu',
            color: _KdsColors.statusCooking,
            backgroundColor: _KdsColors.badgeCookingBg,
          ),
          const SizedBox(width: 10),
          _StatusBadge(
            label: '$inProgressCount Diproses',
            color: _KdsColors.statusServed,
            backgroundColor: const Color(0xFF1E3A5F),
          ),
          const SizedBox(width: 10),
          _StatusBadge(
            label: '$readyCount Siap',
            color: _KdsColors.statusReady,
            backgroundColor: _KdsColors.badgeReadyBg,
          ),

          const SizedBox(width: 16),

          // Auto-refresh indicator (pulsing dot)
          _PulsingDot(flash: flashNewOrder),

          const Spacer(),

          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _KdsColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: _KdsColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatClock(now),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _KdsColors.textPrimary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Back button
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: _KdsColors.textSecondary, size: 18),
            label: Text(
              'Kembali',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _KdsColors.textSecondary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _KdsColors.textMuted.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge (pill shape)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Dot (auto-refresh / new order indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final bool flash;

  const _PulsingDot({required this.flash});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.flash ? _KdsColors.timerRed : _KdsColors.statusReady;
    final dotSize = widget.flash ? 12.0 : 8.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: _animation.value * 0.5),
                blurRadius: widget.flash ? 12 : 6,
                spreadRadius: widget.flash ? 2 : 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Grid — responsive columns
// ─────────────────────────────────────────────────────────────────────────────

class _KdsOrderGrid extends StatelessWidget {
  final List<KdsOrder> orders;
  final DateTime now;

  const _KdsOrderGrid({
    required this.orders,
    required this.now,
  });

  int _columnCount(double width) {
    if (width > 1400) return 4;
    if (width > 1000) return 3;
    if (width > 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final padding = 16.0;
        final spacing = 12.0;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: GridView.builder(
            key: ValueKey(orders.length),
            padding: EdgeInsets.all(padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              // Use a reasonable aspect ratio; cards auto-size via mainAxisExtent
              childAspectRatio: 0.75,
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _KdsOrderCard(
                order: order,
                now: now,
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Card
// ─────────────────────────────────────────────────────────────────────────────

class _KdsOrderCard extends ConsumerWidget {
  final KdsOrder order;
  final DateTime now;

  const _KdsOrderCard({
    required this.order,
    required this.now,
  });

  Color _cardBackground() {
    switch (order.kitchenStatus) {
      case 'ready':
        return _KdsColors.cardReady;
      case 'in_progress':
        return _KdsColors.cardInProgress;
      default:
        return _KdsColors.cardWaiting;
    }
  }

  Color _cardBorderColor() {
    switch (order.kitchenStatus) {
      case 'ready':
        return _KdsColors.statusReady.withValues(alpha: 0.4);
      case 'in_progress':
        return _KdsColors.statusCooking.withValues(alpha: 0.3);
      default:
        return _KdsColors.cardBorder;
    }
  }

  Color _timerColor(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    if (minutes > 15) return _KdsColors.timerRed;
    if (minutes >= 5) return _KdsColors.timerAmber;
    return _KdsColors.timerGreen;
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine_in':
        return 'Dine In';
      case 'takeaway':
        return 'Takeaway';
      default:
        return type;
    }
  }

  Color _orderTypeBadgeColor(String type) {
    switch (type) {
      case 'dine_in':
        return _KdsColors.statusServed;
      case 'takeaway':
        return _KdsColors.statusCooking;
      default:
        return _KdsColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed = now.difference(order.createdAt);
    final timerCol = _timerColor(elapsed);
    final allReady = order.items.isNotEmpty &&
        order.items.every((i) => i.kitchenStatus == 'ready');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _cardBackground(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorderColor(), width: 1.5),
        boxShadow: [
          if (order.kitchenStatus == 'ready')
            BoxShadow(
              color: _KdsColors.statusReady.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Color(0x30000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card header ──
          _CardHeader(
            orderNumber: order.orderNumber ?? order.id.substring(0, 8),
            elapsed: elapsed,
            timerColor: timerCol,
            orderType: order.orderType,
            orderTypeLabel: _orderTypeLabel(order.orderType),
            orderTypeBadgeColor: _orderTypeBadgeColor(order.orderType),
            tableNumber: order.tableNumber,
            isOverdue: order.isOverdue,
          ),

          const Divider(height: 1, color: _KdsColors.cardBorder),

          // ── Items list ──
          Expanded(
            child: _CardItemsList(
              items: order.items,
              orderId: order.id,
            ),
          ),

          const Divider(height: 1, color: _KdsColors.cardBorder),

          // ── Action buttons ──
          _CardActions(
            orderId: order.id,
            allReady: allReady,
            kitchenStatus: order.kitchenStatus,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Header
// ─────────────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String orderNumber;
  final Duration elapsed;
  final Color timerColor;
  final String orderType;
  final String orderTypeLabel;
  final Color orderTypeBadgeColor;
  final int? tableNumber;
  final bool isOverdue;

  const _CardHeader({
    required this.orderNumber,
    required this.elapsed,
    required this.timerColor,
    required this.orderType,
    required this.orderTypeLabel,
    required this.orderTypeBadgeColor,
    required this.tableNumber,
    required this.isOverdue,
  });

  String _formatElapsed(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOverdue
            ? _KdsColors.timerRed.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: order number, timer, type badge
          Row(
            children: [
              // Order number
              Expanded(
                child: Text(
                  '#$orderNumber',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _KdsColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: timerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: timerColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatElapsed(elapsed),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: timerColor,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Order type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: orderTypeBadgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: orderTypeBadgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  orderTypeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: orderTypeBadgeColor,
                  ),
                ),
              ),
            ],
          ),

          // Second row: table number (if dine in)
          if (orderType == 'dine_in' && tableNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              'Meja $tableNumber',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _KdsColors.textSecondary,
              ),
            ),
          ],

          // Customer name / notes at order level
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Items List
// ─────────────────────────────────────────────────────────────────────────────

class _CardItemsList extends ConsumerWidget {
  final List<KdsOrderItem> items;
  final String orderId;

  const _CardItemsList({
    required this.items,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Tidak ada item',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _KdsColors.textMuted,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ItemRow(item: item);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Item Row — with tappable status badge
// ─────────────────────────────────────────────────────────────────────────────

class _ItemRow extends ConsumerWidget {
  final KdsOrderItem item;

  const _ItemRow({required this.item});

  String _statusLabel(String status) {
    switch (status) {
      case 'cooking':
        return 'Masak';
      case 'ready':
        return 'Siap';
      case 'pending':
      default:
        return 'Tunggu';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'cooking':
        return _KdsColors.statusCooking;
      case 'ready':
        return _KdsColors.statusReady;
      case 'pending':
      default:
        return _KdsColors.statusPending;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'cooking':
        return _KdsColors.badgeCookingBg;
      case 'ready':
        return _KdsColors.badgeReadyBg;
      case 'pending':
      default:
        return _KdsColors.badgePendingBg;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'cooking':
        return Icons.local_fire_department;
      case 'ready':
        return Icons.check_circle;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  /// Cycle: pending -> cooking -> ready
  String _nextStatus(String current) {
    switch (current) {
      case 'pending':
        return 'cooking';
      case 'cooking':
        return 'ready';
      case 'ready':
        return 'ready'; // Already done, no cycle further
      default:
        return 'cooking';
    }
  }

  Future<void> _onTapStatus(WidgetRef ref) async {
    if (item.kitchenStatus == 'ready') return; // Already done

    final next = _nextStatus(item.kitchenStatus);
    try {
      final repo = ref.read(kdsRepositoryProvider);
      await repo.updateItemStatus(item.id, next);
      ref.invalidate(kdsOrdersProvider);
    } catch (e) {
      // Silently handle — kitchen display should not show error dialogs
      debugPrint('KDS: Failed to update item status: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(item.kitchenStatus);
    final bgColor = _statusBgColor(item.kitchenStatus);
    final label = _statusLabel(item.kitchenStatus);
    final icon = _statusIcon(item.kitchenStatus);
    final isTappable = item.kitchenStatus != 'ready';

    // Build modifier strings
    final modifierTexts = <String>[];
    if (item.modifiers != null) {
      for (final mod in item.modifiers!) {
        final name = mod['name'] ?? mod['modifier_name'] ?? '';
        if (name.toString().isNotEmpty) {
          modifierTexts.add('+ $name');
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main item row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity + product name
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${item.quantity}x ',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _KdsColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: item.productName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _KdsColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Tappable status badge
            GestureDetector(
              onTap: isTappable ? () => _onTapStatus(ref) : null,
              child: MouseRegion(
                cursor: isTappable
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Modifiers
        if (modifierTexts.isNotEmpty) ...[
          const SizedBox(height: 2),
          for (final mod in modifierTexts)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 1),
              child: Text(
                mod,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _KdsColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],

        // Item notes
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 12,
                  color: _KdsColors.timerAmber,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _KdsColors.timerAmber,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Action Buttons
// ─────────────────────────────────────────────────────────────────────────────

class _CardActions extends ConsumerStatefulWidget {
  final String orderId;
  final bool allReady;
  final String kitchenStatus;

  const _CardActions({
    required this.orderId,
    required this.allReady,
    required this.kitchenStatus,
  });

  @override
  ConsumerState<_CardActions> createState() => _CardActionsState();
}

class _CardActionsState extends ConsumerState<_CardActions> {
  bool _loading = false;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
      ref.invalidate(kdsOrdersProvider);
    } catch (e) {
      debugPrint('KDS action error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(kdsRepositoryProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _KdsColors.textSecondary,
                ),
              ),
            )
          : Row(
              children: [
                // Recall button (icon only)
                _ActionIconButton(
                  icon: Icons.replay,
                  tooltip: 'Recall',
                  color: _KdsColors.textMuted,
                  onTap: () => _runAction(
                    () => repo.recallOrder(widget.orderId),
                  ),
                ),

                const Spacer(),

                if (widget.allReady) ...[
                  // Serve button — all items ready
                  _ActionButton(
                    label: 'Sajikan',
                    icon: Icons.room_service,
                    color: _KdsColors.statusServed,
                    onTap: () => _runAction(
                      () => repo.markOrderServed(widget.orderId),
                    ),
                  ),
                ] else ...[
                  // Start All button
                  _ActionButton(
                    label: 'Mulai Semua',
                    icon: Icons.local_fire_department,
                    color: _KdsColors.statusCooking,
                    onTap: () => _runAction(
                      () => repo.startAllItems(widget.orderId),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Complete All button
                  _ActionButton(
                    label: 'Selesai',
                    icon: Icons.check_circle_outline,
                    color: _KdsColors.statusReady,
                    onTap: () => _runAction(
                      () => repo.completeAllItems(widget.orderId),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button (text + icon)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovering
                ? widget.color.withValues(alpha: 0.25)
                : widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovering ? 0.6 : 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Icon Button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _hovering
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovering
                  ? widget.color
                  : widget.color.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _KdsEmptyState extends StatelessWidget {
  const _KdsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _KdsColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 52,
              color: _KdsColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tidak ada pesanan aktif',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _KdsColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan baru akan muncul otomatis',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _KdsColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────

class _KdsErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _KdsErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _KdsColors.timerRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 44,
              color: _KdsColors.timerRed,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Gagal memuat pesanan',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _KdsColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _KdsColors.textMuted,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _KdsColors.statusCooking.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _KdsColors.statusCooking.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Coba Lagi',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _KdsColors.statusCooking,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
