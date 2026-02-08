import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/pos_shift_provider.dart';
import '../widgets/shift_open_dialog.dart';
import '../widgets/shift_close_dialog.dart';

class PosShiftPage extends ConsumerWidget {
  const PosShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftAsync = ref.watch(posShiftNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shift Management')),
      body: Center(
        child: shiftAsync.when(
          data: (shift) {
            if (shift == null) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  const Text('Tidak ada shift aktif', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ShiftOpenDialog(
                        outletId: ref.read(currentOutletIdProvider),
                        onOpen: (cashierId, cash) async {
                          await ref.read(posShiftNotifierProvider.notifier).openShift(cashierId, cash);
                        },
                      ),
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Buka Shift'),
                  ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 48, color: AppTheme.successColor),
                  const SizedBox(height: 16),
                  Text('Shift Aktif', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                  const SizedBox(height: 8),
                  Text('Durasi: ${shift.durationFormatted}', style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                  Text('Modal: ${FormatUtils.currency(shift.openingCash)}', style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (_) => const ShiftCloseDialog()),
                    icon: const Icon(Icons.lock),
                    label: const Text('Tutup Shift'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
    );
  }
}
