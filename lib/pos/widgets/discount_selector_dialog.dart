import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/cart.dart';
import '../../core/providers/outlet_provider.dart';
import '../repositories/pos_discount_repository.dart';
import '../providers/pos_cart_provider.dart';

class DiscountSelectorDialog extends ConsumerWidget {
  const DiscountSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final repo = PosDiscountRepository();

    return Dialog(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pilih Diskon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: repo.getActiveDiscounts(ref.watch(currentOutletIdProvider)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                final discounts = snapshot.data ?? [];
                if (discounts.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Tidak ada diskon aktif')));
                return Column(
                  children: discounts.map((d) {
                    final isSelected = cart.discount?.id == d.id;
                    return ListTile(
                      title: Text(d.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(d.type == 'percentage' ? '${d.value.toInt()}%' : FormatUtils.currency(d.value)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.successColor) : null,
                      selected: isSelected,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        ref.read(posCartProvider.notifier).setDiscount(CartDiscount(id: d.id, name: d.name, type: d.type, value: d.value));
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                );
              },
            ),
            if (cart.discount != null)
              Center(
                child: TextButton(
                  onPressed: () { ref.read(posCartProvider.notifier).setDiscount(null); Navigator.pop(context); },
                  child: const Text('Hapus Diskon', style: TextStyle(color: AppTheme.errorColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
