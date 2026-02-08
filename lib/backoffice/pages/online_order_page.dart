import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/online_order_provider.dart';
import '../repositories/online_order_repository.dart';

// ============================================================
// Constants
// ============================================================

const _outletId = 'a0000000-0000-0000-0000-000000000001';

const _kGoFoodColor = Color(0xFF00AA13);
const _kGrabFoodColor = Color(0xFF00B14F);
const _kShopeeFoodColor = Color(0xFFEE4D2D);

final _currencyFormat =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

// ============================================================
// Helper: Platform color
// ============================================================

Color _platformColor(String platform) {
  switch (platform) {
    case 'gofood':
      return _kGoFoodColor;
    case 'grabfood':
      return _kGrabFoodColor;
    case 'shopeefood':
      return _kShopeeFoodColor;
    default:
      return AppTheme.primaryColor;
  }
}

IconData _platformIcon(String platform) {
  switch (platform) {
    case 'gofood':
      return Icons.delivery_dining;
    case 'grabfood':
      return Icons.motorcycle;
    case 'shopeefood':
      return Icons.shopping_bag_outlined;
    default:
      return Icons.storefront;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'incoming':
      return AppTheme.warningColor;
    case 'accepted':
      return AppTheme.infoColor;
    case 'preparing':
      return const Color(0xFF8B5CF6);
    case 'ready':
      return AppTheme.primaryColor;
    case 'picked_up':
      return AppTheme.secondaryColor;
    case 'delivered':
      return AppTheme.successColor;
    case 'cancelled':
    case 'rejected':
      return AppTheme.errorColor;
    default:
      return AppTheme.textSecondary;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'incoming':
      return Icons.notification_important_rounded;
    case 'accepted':
      return Icons.check_circle_outline;
    case 'preparing':
      return Icons.restaurant_rounded;
    case 'ready':
      return Icons.check_circle_rounded;
    case 'picked_up':
      return Icons.local_shipping_rounded;
    case 'delivered':
      return Icons.done_all_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    case 'rejected':
      return Icons.block_rounded;
    default:
      return Icons.help_outline;
  }
}

// ============================================================
// Main Page
// ============================================================

class OnlineOrderPage extends ConsumerWidget {
  const OnlineOrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(onlineOrdersProvider);
    final statsAsync = ref.watch(onlineOrderStatsProvider);
    final incomingCount = ref.watch(incomingOrderCountProvider);
    final currentFilter = ref.watch(onlineOrderFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(onlineOrdersProvider);
          ref.invalidate(onlineOrderStatsProvider);
          await ref.read(onlineOrdersProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            // ── Top bar ──
            SliverToBoxAdapter(
              child: _TopBar(
                incomingCount: incomingCount,
                onRefresh: () {
                  ref.invalidate(onlineOrdersProvider);
                  ref.invalidate(onlineOrderStatsProvider);
                },
                onSimulate: () => _showSimulateDialog(context, ref),
              ),
            ),

            // ── Stats row ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: statsAsync.when(
                  loading: () => const _StatsLoadingRow(),
                  error: (err, _) => _StatsErrorRow(
                    message: err.toString(),
                    onRetry: () => ref.invalidate(onlineOrderStatsProvider),
                  ),
                  data: (stats) => _StatsRow(stats: stats),
                ),
              ),
            ),

            // ── Filters ──
            SliverToBoxAdapter(
              child: _FilterBar(
                currentFilter: currentFilter,
                onFilterChanged: (filter) {
                  ref.read(onlineOrderFilterProvider.notifier).state = filter;
                },
              ),
            ),

            // ── Order list ──
            ordersAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (err, _) => SliverFillRemaining(
                child: _OrdersErrorState(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(onlineOrdersProvider),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return const SliverFillRemaining(
                    child: _EmptyOrdersState(),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 480,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = orders[index];
                        return _OnlineOrderCard(
                          order: order,
                          onTap: () => _showOrderDetailDialog(
                              context, ref, order),
                          onAccept: order.status == 'incoming'
                              ? () => _handleAccept(context, ref, order)
                              : null,
                          onReject: order.status == 'incoming'
                              ? () =>
                                  _showRejectDialog(context, ref, order)
                              : null,
                          onStatusUpdate: _nextStatus(order.status) != null
                              ? () => _handleStatusUpdate(
                                  context, ref, order, _nextStatus(order.status)!)
                              : null,
                          nextStatusLabel: _nextStatusLabel(order.status),
                        );
                      },
                      childCount: orders.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Status flow helpers ──

  String? _nextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'accepted':
        return 'preparing';
      case 'preparing':
        return 'ready';
      case 'ready':
        return 'picked_up';
      case 'picked_up':
        return 'delivered';
      default:
        return null;
    }
  }

  String? _nextStatusLabel(String currentStatus) {
    switch (currentStatus) {
      case 'accepted':
        return 'Mulai Masak';
      case 'preparing':
        return 'Siap Diambil';
      case 'ready':
        return 'Sudah Diambil';
      case 'picked_up':
        return 'Terkirim';
      default:
        return null;
    }
  }

  // ── Action handlers ──

  Future<void> _handleAccept(
      BuildContext context, WidgetRef ref, OnlineOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Terima Pesanan?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Pesanan ${order.platformOrderNumber ?? order.platformOrderId} '
          'dari ${order.platformDisplayName} akan diterima dan dibuat sebagai order internal.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terima'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(onlineOrderRepositoryProvider);
      await repo.acceptOrder(order.id);
      ref.invalidate(onlineOrdersProvider);
      ref.invalidate(onlineOrderStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${order.platformOrderNumber} diterima'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menerima pesanan: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(
      BuildContext context, WidgetRef ref, OnlineOrder order) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tolak Pesanan',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan ${order.platformOrderNumber ?? order.platformOrderId} '
              'dari ${order.platformDisplayName} akan ditolak.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Alasan penolakan (opsional)',
                hintText: 'Contoh: Stok habis, toko tutup...',
                labelStyle: GoogleFonts.inter(fontSize: 13),
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textTertiary),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (reason == null || !context.mounted) return;

    try {
      final repo = ref.read(onlineOrderRepositoryProvider);
      await repo.rejectOrder(order.id, reason.isNotEmpty ? reason : null);
      ref.invalidate(onlineOrdersProvider);
      ref.invalidate(onlineOrderStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${order.platformOrderNumber} ditolak'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak pesanan: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleStatusUpdate(BuildContext context, WidgetRef ref,
      OnlineOrder order, String newStatus) async {
    try {
      final repo = ref.read(onlineOrderRepositoryProvider);
      await repo.updateOrderStatus(order.id, newStatus);
      ref.invalidate(onlineOrdersProvider);
      ref.invalidate(onlineOrderStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status diperbarui ke ${_statusLabelFromCode(newStatus)}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _statusLabelFromCode(String status) {
    switch (status) {
      case 'incoming':
        return 'Pesanan Masuk';
      case 'accepted':
        return 'Diterima';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'ready':
        return 'Siap Diambil';
      case 'picked_up':
        return 'Sudah Diambil';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  // ── Simulate dialog ──

  Future<void> _showSimulateDialog(BuildContext context, WidgetRef ref) async {
    final platform = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Simulasi Pesanan Masuk',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        children: [
          _SimulatePlatformOption(
            label: 'GoFood',
            color: _kGoFoodColor,
            icon: Icons.delivery_dining,
            onTap: () => Navigator.pop(ctx, 'gofood'),
          ),
          _SimulatePlatformOption(
            label: 'GrabFood',
            color: _kGrabFoodColor,
            icon: Icons.motorcycle,
            onTap: () => Navigator.pop(ctx, 'grabfood'),
          ),
          _SimulatePlatformOption(
            label: 'ShopeeFood',
            color: _kShopeeFoodColor,
            icon: Icons.shopping_bag_outlined,
            onTap: () => Navigator.pop(ctx, 'shopeefood'),
          ),
        ],
      ),
    );

    if (platform == null || !context.mounted) return;

    try {
      final repo = ref.read(onlineOrderRepositoryProvider);
      await repo.simulateIncomingOrder(_outletId, platform);
      ref.invalidate(onlineOrdersProvider);
      ref.invalidate(onlineOrderStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan simulasi dari ${platform == 'gofood' ? 'GoFood' : platform == 'grabfood' ? 'GrabFood' : 'ShopeeFood'} berhasil dibuat'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat simulasi: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ── Order detail dialog ──

  void _showOrderDetailDialog(
      BuildContext context, WidgetRef ref, OnlineOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => _OrderDetailDialog(
        order: order,
        onAccept: order.status == 'incoming'
            ? () {
                Navigator.pop(ctx);
                _handleAccept(context, ref, order);
              }
            : null,
        onReject: order.status == 'incoming'
            ? () {
                Navigator.pop(ctx);
                _showRejectDialog(context, ref, order);
              }
            : null,
        onStatusUpdate: _nextStatus(order.status) != null
            ? () {
                Navigator.pop(ctx);
                _handleStatusUpdate(
                    context, ref, order, _nextStatus(order.status)!);
              }
            : null,
        nextStatusLabel: _nextStatusLabel(order.status),
      ),
    );
  }
}

// ============================================================
// Top Bar
// ============================================================

class _TopBar extends StatelessWidget {
  final int incomingCount;
  final VoidCallback onRefresh;
  final VoidCallback onSimulate;

  const _TopBar({
    required this.incomingCount,
    required this.onRefresh,
    required this.onSimulate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          // Title + badge
          Expanded(
            child: Row(
              children: [
                Text(
                  'Pesanan Online',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (incomingCount > 0) ...[
                  const SizedBox(width: 12),
                  _IncomingBadge(count: incomingCount),
                ],
              ],
            ),
          ),
          // Actions
          OutlinedButton.icon(
            onPressed: onSimulate,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: Text('Simulasi Order',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingBadge extends StatelessWidget {
  final int count;
  const _IncomingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notification_important_rounded,
              size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$count masuk',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Stats Row
// ============================================================

class _StatsRow extends StatelessWidget {
  final OnlineOrderStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        // Total orders
        _StatMiniCard(
          title: 'Total Pesanan',
          value: stats.totalOrders.toString(),
          icon: Icons.receipt_long_rounded,
          color: AppTheme.primaryColor,
        ),
        // Total revenue
        _StatMiniCard(
          title: 'Total Pendapatan',
          value: FormatUtils.currencyCompact(stats.totalRevenue),
          icon: Icons.trending_up_rounded,
          color: AppTheme.successColor,
        ),
        // Per-platform cards
        ..._buildPlatformCards(),
      ],
    );
  }

  List<Widget> _buildPlatformCards() {
    final platforms = ['gofood', 'grabfood', 'shopeefood'];
    final displayNames = {'gofood': 'GoFood', 'grabfood': 'GrabFood', 'shopeefood': 'ShopeeFood'};

    return platforms.map((p) {
      final count = stats.ordersByPlatform[p] ?? 0;
      final revenue = stats.revenueByPlatform[p] ?? 0;
      return _PlatformStatCard(
        platform: displayNames[p]!,
        orderCount: count,
        revenue: revenue,
        color: _platformColor(p),
        icon: _platformIcon(p),
      );
    }).toList();
  }
}

class _StatMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformStatCard extends StatelessWidget {
  final String platform;
  final int orderCount;
  final double revenue;
  final Color color;
  final IconData icon;

  const _PlatformStatCard({
    required this.platform,
    required this.orderCount,
    required this.revenue,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                platform,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$orderCount pesanan',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            FormatUtils.currencyCompact(revenue),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsLoadingRow extends StatelessWidget {
  const _StatsLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _StatsErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StatsErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gagal memuat statistik',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.errorColor),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Filter Bar
// ============================================================

class _FilterBar extends StatelessWidget {
  final OnlineOrderFilter currentFilter;
  final ValueChanged<OnlineOrderFilter> onFilterChanged;

  const _FilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Platform:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Semua',
                  isSelected: currentFilter.platform == null,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(clearPlatform: true)),
                ),
                _FilterChip(
                  label: 'GoFood',
                  isSelected: currentFilter.platform == 'gofood',
                  color: _kGoFoodColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(platform: 'gofood')),
                ),
                _FilterChip(
                  label: 'GrabFood',
                  isSelected: currentFilter.platform == 'grabfood',
                  color: _kGrabFoodColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(platform: 'grabfood')),
                ),
                _FilterChip(
                  label: 'ShopeeFood',
                  isSelected: currentFilter.platform == 'shopeefood',
                  color: _kShopeeFoodColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(platform: 'shopeefood')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Status filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Status:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Semua',
                  isSelected: currentFilter.status == null,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(clearStatus: true)),
                ),
                _FilterChip(
                  label: 'Masuk',
                  isSelected: currentFilter.status == 'incoming',
                  color: AppTheme.warningColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(status: 'incoming')),
                ),
                _FilterChip(
                  label: 'Diproses',
                  isSelected: currentFilter.status == 'preparing',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(status: 'preparing')),
                ),
                _FilterChip(
                  label: 'Siap',
                  isSelected: currentFilter.status == 'ready',
                  color: AppTheme.primaryColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(status: 'ready')),
                ),
                _FilterChip(
                  label: 'Selesai',
                  isSelected: currentFilter.status == 'delivered',
                  color: AppTheme.successColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(status: 'delivered')),
                ),
                _FilterChip(
                  label: 'Dibatalkan',
                  isSelected: currentFilter.status == 'cancelled' ||
                      currentFilter.status == 'rejected',
                  color: AppTheme.errorColor,
                  onTap: () => onFilterChanged(
                      currentFilter.copyWith(status: 'cancelled')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.15)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : AppTheme.borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? chipColor : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Order Card
// ============================================================

class _OnlineOrderCard extends StatelessWidget {
  final OnlineOrder order;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStatusUpdate;
  final String? nextStatusLabel;

  const _OnlineOrderCard({
    required this.order,
    required this.onTap,
    this.onAccept,
    this.onReject,
    this.onStatusUpdate,
    this.nextStatusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final platformColor = _platformColor(order.platform);
    final sColor = _statusColor(order.status);
    final isIncoming = order.status == 'incoming';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isIncoming
                ? AppTheme.warningColor.withValues(alpha: 0.5)
                : AppTheme.borderColor.withValues(alpha: 0.5),
            width: isIncoming ? 1.5 : 1,
          ),
          boxShadow: isIncoming ? AppTheme.shadowMD : AppTheme.shadowSM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Platform badge + status + time ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: platformColor.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  // Platform badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: platformColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_platformIcon(order.platform),
                            size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          order.platformDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Order number
                  Expanded(
                    child: Text(
                      order.platformOrderNumber ?? order.platformOrderId,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(order.status),
                            size: 12, color: sColor),
                        const SizedBox(width: 3),
                        Text(
                          order.statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer info
                    if (order.customerName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.customerName!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.customerPhone != null)
                            Text(
                              FormatUtils.phone(order.customerPhone!),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Items list
                    Expanded(
                      child: _ItemsList(items: order.items),
                    ),

                    // Address (truncated)
                    if (order.customerAddress != null) ...[
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.customerAddress!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Driver info
                    if (order.driverName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.motorcycle,
                              size: 13, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            order.driverName!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (order.driverPhone != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${FormatUtils.phone(order.driverPhone!)})',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),

            // ── Footer: Total + time + actions ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Total + time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currencyFormat.format(order.total),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        FormatUtils.relativeTime(order.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  // Action buttons
                  if (onAccept != null || onReject != null || onStatusUpdate != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (onReject != null) ...[
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: OutlinedButton(
                                onPressed: onReject,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  side: const BorderSide(
                                      color: AppTheme.errorColor, width: 1),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text('Tolak',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (onAccept != null)
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                onPressed: onAccept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text('Terima',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        if (onStatusUpdate != null && nextStatusLabel != null)
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                onPressed: onStatusUpdate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  nextStatusLabel!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Items List (inside card) ──

class _ItemsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length > 3 ? 3 : items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (_, index) {
        if (index == 2 && items.length > 3) {
          return Text(
            '+${items.length - 2} item lainnya...',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppTheme.textTertiary,
            ),
          );
        }
        final item = items[index];
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final name = item['name'] as String? ?? 'Unknown';
        final notes = item['notes'] as String?;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${qty}x',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notes != null && notes.isNotEmpty)
                    Text(
                      notes,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// Empty / Error States
// ============================================================

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delivery_dining_outlined,
              size: 56, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Belum ada pesanan online hari ini',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gunakan tombol "Simulasi Order" untuk membuat pesanan percobaan',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OrdersErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(
            'Gagal memuat pesanan',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Simulate Platform Option
// ============================================================

class _SimulatePlatformOption extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SimulatePlatformOption({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Order Detail Dialog
// ============================================================

class _OrderDetailDialog extends StatelessWidget {
  final OnlineOrder order;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStatusUpdate;
  final String? nextStatusLabel;

  const _OrderDetailDialog({
    required this.order,
    this.onAccept,
    this.onReject,
    this.onStatusUpdate,
    this.nextStatusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final platformColor = _platformColor(order.platform);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 520.0 : screenWidth * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog Header ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: platformColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: platformColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_platformIcon(order.platform),
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          order.platformDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.platformOrderNumber ?? order.platformOrderId,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          FormatUtils.dateTime(order.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _StatusBadgeLarge(status: order.status, label: order.statusLabel),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),

            // ── Dialog Body (scrollable) ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Timeline
                    _StatusTimeline(order: order),
                    const SizedBox(height: 20),

                    // Customer info
                    _SectionHeader(title: 'Informasi Pelanggan'),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Nama',
                      value: order.customerName ?? '-',
                    ),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: order.customerPhone != null
                          ? FormatUtils.phone(order.customerPhone!)
                          : '-',
                    ),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Alamat',
                      value: order.customerAddress ?? '-',
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Items
                    _SectionHeader(title: 'Daftar Item'),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => _DetailItemRow(item: item)),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Fees breakdown
                    _SectionHeader(title: 'Rincian Biaya'),
                    const SizedBox(height: 8),
                    _FeeRow(label: 'Subtotal', amount: order.subtotal),
                    _FeeRow(label: 'Ongkos Kirim', amount: order.deliveryFee),
                    _FeeRow(label: 'Biaya Platform', amount: order.platformFee),
                    const Divider(height: 16),
                    _FeeRow(
                        label: 'Total', amount: order.total, isBold: true),

                    // Driver info
                    if (order.driverName != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Informasi Driver'),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.motorcycle,
                        label: 'Nama',
                        value: order.driverName!,
                      ),
                      if (order.driverPhone != null)
                        _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Telepon',
                          value: FormatUtils.phone(order.driverPhone!),
                        ),
                    ],

                    // Notes
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Catatan'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          order.notes!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Dialog Footer: Actions ──
            if (onAccept != null || onReject != null || onStatusUpdate != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    if (onReject != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 18),
                          label: Text('Tolak',
                              style:
                                  GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(
                                color: AppTheme.errorColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    if (onReject != null && onAccept != null)
                      const SizedBox(width: 12),
                    if (onAccept != null)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check, size: 18),
                          label: Text('Terima Pesanan',
                              style:
                                  GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    if (onStatusUpdate != null && nextStatusLabel != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onStatusUpdate,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text(nextStatusLabel!,
                              style:
                                  GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge Large ──

class _StatusBadgeLarge extends StatelessWidget {
  final String status;
  final String label;
  const _StatusBadgeLarge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Timeline ──

class _StatusTimeline extends StatelessWidget {
  final OnlineOrder order;
  const _StatusTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Pesanan Masuk',
        time: order.createdAt,
        isCompleted: true,
        isActive: order.status == 'incoming',
      ),
      _TimelineStep(
        label: 'Diterima',
        time: order.acceptedAt,
        isCompleted: order.acceptedAt != null,
        isActive: order.status == 'accepted',
      ),
      _TimelineStep(
        label: 'Disiapkan',
        time: order.preparedAt,
        isCompleted: order.preparedAt != null,
        isActive: order.status == 'preparing',
      ),
      _TimelineStep(
        label: 'Siap Diambil',
        time: null, // ready doesn't have a separate timestamp in this model
        isCompleted: order.status == 'ready' ||
            order.status == 'picked_up' ||
            order.status == 'delivered',
        isActive: order.status == 'ready',
      ),
      _TimelineStep(
        label: 'Diambil Driver',
        time: order.pickedUpAt,
        isCompleted: order.pickedUpAt != null,
        isActive: order.status == 'picked_up',
      ),
      _TimelineStep(
        label: 'Terkirim',
        time: order.deliveredAt,
        isCompleted: order.deliveredAt != null,
        isActive: order.status == 'delivered',
      ),
    ];

    // If cancelled or rejected, show a separate indicator
    final isCancelledOrRejected =
        order.status == 'cancelled' || order.status == 'rejected';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Pesanan',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (isCancelledOrRejected)
            Row(
              children: [
                Icon(
                  order.status == 'cancelled'
                      ? Icons.cancel_rounded
                      : Icons.block_rounded,
                  size: 20,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  order.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
                if (order.cancelledAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    FormatUtils.dateTime(order.cancelledAt!),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isLast = index == steps.length - 1;

                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step.isCompleted
                                  ? (step.isActive
                                      ? AppTheme.primaryColor
                                      : AppTheme.successColor)
                                  : AppTheme.borderColor,
                            ),
                            child: step.isCompleted
                                ? const Icon(Icons.check,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: step.isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: step.isCompleted
                                  ? AppTheme.textPrimary
                                  : AppTheme.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (step.time != null)
                            Text(
                              FormatUtils.time(step.time!),
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 20),
                            color: step.isCompleted
                                ? AppTheme.successColor
                                : AppTheme.borderColor,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  final String label;
  final DateTime? time;
  final bool isCompleted;
  final bool isActive;

  _TimelineStep({
    required this.label,
    this.time,
    required this.isCompleted,
    required this.isActive,
  });
}

// ── Section Header ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

// ── Detail Row ──

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textTertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail Item Row (for items list in dialog) ──

class _DetailItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DetailItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Unknown';
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final notes = item['notes'] as String?;
    final lineTotal = price * qty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${qty}x',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (notes != null && notes.isNotEmpty)
                  Text(
                    'Catatan: $notes',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(lineTotal),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fee Row ──

class _FeeRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _FeeRow({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.inter(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
