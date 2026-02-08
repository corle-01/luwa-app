import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/pos_checkout_provider.dart';
import '../providers/pos_order_provider.dart';
import '../widgets/order_detail_dialog.dart';

class PosOrderHistoryPage extends ConsumerWidget {
  const PosOrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(posTodayOrdersProvider);
    final orderCount = ref.watch(posOrderCountProvider);
    final todaySales = ref.watch(posTodaySalesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _SummaryCard(title: 'Total Order', value: '$orderCount', color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                _SummaryCard(title: 'Total Penjualan', value: FormatUtils.currency(todaySales), color: AppTheme.successColor),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) return const Center(child: Text('Belum ada pesanan hari ini'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final order = orders[i];
                    final statusColor = order.status == 'completed' ? AppTheme.successColor : order.status == 'cancelled' ? AppTheme.errorColor : AppTheme.accentColor;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => OrderDetailDialog(order: order),
                        ),
                        title: Text(order.orderNumber ?? '#${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${FormatUtils.time(order.createdAt)} - ${order.paymentMethod.toUpperCase()}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(FormatUtils.currency(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(order.status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _SummaryCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
