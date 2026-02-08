import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/order.dart';
import '../providers/dashboard_provider.dart';
import '../ai/pages/ai_dashboard_page.dart';
import '../ai/pages/ai_settings_page.dart';
import '../ai/pages/ai_action_log_page.dart';
import '../ai/pages/ai_conversation_history.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final ordersAsync = ref.watch(recentOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(recentOrdersProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentOrdersProvider);
          // Wait for both to reload
          await ref.read(dashboardStatsProvider.future);
          await ref.read(recentOrdersProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Text(
                'Selamat datang di Utter App!',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI-Integrated F&B Management System',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Stats Cards ──
              statsAsync.when(
                loading: () => const _StatsLoading(),
                error: (err, _) => _StatsError(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
                data: (stats) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: 'Penjualan Hari Ini',
                      value: FormatUtils.currency(stats.todaySales),
                      icon: Icons.trending_up_rounded,
                      color: AppTheme.successColor,
                    ),
                    _StatCard(
                      title: 'Total Order',
                      value: stats.todayOrders.toString(),
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    _StatCard(
                      title: 'Produk Aktif',
                      value: stats.activeProducts.toString(),
                      icon: Icons.inventory_2_rounded,
                      color: AppTheme.accentColor,
                    ),
                    _StatCard(
                      title: 'Stok Rendah',
                      value: stats.lowStockCount.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: stats.lowStockCount > 0
                          ? AppTheme.errorColor
                          : AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Recent Orders ──
              Text(
                'Pesanan Terakhir',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ordersAsync.when(
                loading: () => const _OrdersLoading(),
                error: (err, _) => _OrdersError(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(recentOrdersProvider),
                ),
                data: (orders) => orders.isEmpty
                    ? _EmptyOrders()
                    : _RecentOrdersList(orders: orders),
              ),

              const SizedBox(height: 32),

              // ── Quick Menu ──
              Text(
                'Menu Cepat',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickMenuCard(
                    title: 'Utter AI',
                    subtitle: 'Chat & Insights',
                    icon: Icons.psychology,
                    color: AppTheme.aiPrimary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiDashboardPage()),
                    ),
                  ),
                  _QuickMenuCard(
                    title: 'AI Settings',
                    subtitle: 'Trust Level Config',
                    icon: Icons.tune,
                    color: AppTheme.aiSecondary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiSettingsPage()),
                    ),
                  ),
                  _QuickMenuCard(
                    title: 'Action Log',
                    subtitle: 'Riwayat Aksi AI',
                    icon: Icons.history,
                    color: AppTheme.secondaryColor,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiActionLogPage()),
                    ),
                  ),
                  _QuickMenuCard(
                    title: 'Riwayat Chat',
                    subtitle: 'Percakapan AI',
                    icon: Icons.chat_bubble_outline,
                    color: AppTheme.infoColor,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiConversationHistory()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stats Loading Shimmer
// ─────────────────────────────────────────────

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(
        4,
        (_) => SizedBox(
          width: 200,
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stats Error
// ─────────────────────────────────────────────

class _StatsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
          const SizedBox(height: 8),
          Text(
            'Gagal memuat statistik',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Recent Orders List
// ─────────────────────────────────────────────

class _RecentOrdersList extends StatelessWidget {
  final List<Order> orders;

  const _RecentOrdersList({required this.orders});

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'card':
        return 'Kartu';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return 'E-Wallet';
      case 'bank_transfer':
        return 'Transfer';
      default:
        return FormatUtils.capitalize(method);
    }
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'qris':
        return Icons.qr_code_2_outlined;
      case 'ewallet':
        return Icons.account_balance_wallet_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
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
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'No. Order',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Waktu',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Order rows
          ...orders.map((order) => _OrderRow(
                order: order,
                paymentLabel: _paymentLabel(order.paymentMethod),
                paymentIcon: _paymentIcon(order.paymentMethod),
              )),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;
  final String paymentLabel;
  final IconData paymentIcon;

  const _OrderRow({
    required this.order,
    required this.paymentLabel,
    required this.paymentIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              order.orderNumber ?? order.id.substring(0, 8),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              FormatUtils.time(order.createdAt),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              FormatUtils.currency(order.totalAmount),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(paymentIcon, size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  paymentLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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

// ─────────────────────────────────────────────
// Orders Loading
// ─────────────────────────────────────────────

class _OrdersLoading extends StatelessWidget {
  const _OrdersLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Orders Error
// ─────────────────────────────────────────────

class _OrdersError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OrdersError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Gagal memuat pesanan terakhir',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty Orders
// ─────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Belum ada pesanan hari ini',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Menu Card
// ─────────────────────────────────────────────

class _QuickMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
