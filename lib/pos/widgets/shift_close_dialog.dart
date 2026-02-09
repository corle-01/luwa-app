import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/shift.dart';
import '../providers/pos_shift_provider.dart';

class ShiftCloseDialog extends ConsumerStatefulWidget {
  const ShiftCloseDialog({super.key});

  @override
  ConsumerState<ShiftCloseDialog> createState() => _ShiftCloseDialogState();
}

class _ShiftCloseDialogState extends ConsumerState<ShiftCloseDialog> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;
  ShiftSummary? _summary;
  Future<ShiftSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    // Fetch summary once on init, not on every rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shift = ref.read(posShiftNotifierProvider).value;
      if (shift != null) {
        setState(() {
          _summaryFuture = ref.read(posShiftRepositoryProvider).getShiftSummary(shift.id);
        });
      }
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _closingCash => double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final shift = ref.watch(posShiftNotifierProvider).value;
    if (shift == null) return const SizedBox();

    final shiftId = shift.id;

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tutup Shift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FutureBuilder<ShiftSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                _summary = snapshot.data!;
                final summary = _summary!;
                return Column(
                  children: [
                    _InfoRow('Total Penjualan', FormatUtils.currency(summary.totalSales)),
                    _InfoRow('Total Order', '${summary.totalOrders}'),
                    _InfoRow('Cash', FormatUtils.currency(summary.totalCash)),
                    _InfoRow('Non-Cash', FormatUtils.currency(summary.totalNonCash)),
                    const Divider(height: 16),
                    _InfoRow('Kas Awal', FormatUtils.currency(shift.openingCash)),
                    _InfoRow('Uang Diharapkan', FormatUtils.currency(summary.expectedCash)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Uang Akhir di Kasir', prefixText: 'Rp '),
              onChanged: (_) => setState(() {}),
            ),
            // Realtime discrepancy
            if (_summary != null && _cashController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final discrepancy = _closingCash - _summary!.expectedCash;
                final isMatch = discrepancy.abs() < 1;
                final isOver = discrepancy > 0;
                final color = isMatch
                    ? AppTheme.successColor
                    : (isOver ? AppTheme.warningColor : AppTheme.errorColor);
                final label = isMatch
                    ? 'Sesuai'
                    : (isOver ? 'Lebih' : 'Kurang');
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Selisih ($label)', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                      Text(
                        '${discrepancy >= 0 ? '+' : ''}${FormatUtils.currency(discrepancy)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : () async {
                  setState(() => _loading = true);
                  await ref.read(posShiftNotifierProvider.notifier).closeShift(_closingCash, notes: _notesController.text.isEmpty ? null : _notesController.text);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
                child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Tutup Shift'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
