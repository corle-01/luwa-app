import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/pos_table_provider.dart';
import '../providers/pos_cart_provider.dart';


class TableSelectorDialog extends ConsumerWidget {
  const TableSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(posTablesProvider);
    final cart = ref.watch(posCartProvider);

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pilih Meja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            tablesAsync.when(
              data: (tables) {
                if (tables.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data meja')));
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tables.map((table) {
                    final isSelected = cart.tableId == table.id;
                    final isAvailable = table.status == 'available';
                    final color = isSelected ? AppTheme.primaryColor : isAvailable ? AppTheme.successColor : AppTheme.errorColor;
                    return GestureDetector(
                      onTap: isAvailable || isSelected ? () {
                        ref.read(posCartProvider.notifier).setTable(table.id, table.tableNumber);
                        Navigator.pop(context);
                      } : null,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color, width: isSelected ? 2 : 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(table.tableNumber, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                            Text('${table.capacity}p', style: TextStyle(fontSize: 11, color: color)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading tables'),
            ),
            if (cart.tableId != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () { ref.read(posCartProvider.notifier).setTable(null, null); Navigator.pop(context); },
                  child: const Text('Hapus Meja', style: TextStyle(color: AppTheme.errorColor)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
