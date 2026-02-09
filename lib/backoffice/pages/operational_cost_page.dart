import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/operational_cost.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/operational_cost_provider.dart';
import '../repositories/operational_cost_repository.dart';

class OperationalCostPage extends ConsumerStatefulWidget {
  const OperationalCostPage({super.key});

  @override
  ConsumerState<OperationalCostPage> createState() => _OperationalCostPageState();
}

class _OperationalCostPageState extends ConsumerState<OperationalCostPage> {
  @override
  Widget build(BuildContext context) {
    final costsAsync = ref.watch(operationalCostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biaya Operasional'),
      ),
      body: costsAsync.when(
        data: (costs) => _buildBody(costs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('Error: $e', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(operationalCostsProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<OperationalCost> costs) {
    final operational = costs.where((c) => c.category == 'operational').toList();
    final labor = costs.where((c) => c.category == 'labor').toList();
    final bonusItem = costs.where((c) => c.category == 'bonus').toList();
    final totalOps = operational.fold(0.0, (sum, c) => sum + c.amount);
    final totalLabor = labor.fold(0.0, (sum, c) => sum + c.amount);
    final grandTotal = totalOps + totalLabor;
    final bonusPct = bonusItem.isNotEmpty ? bonusItem.first.amount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryCards(totalOps, totalLabor, grandTotal),
          const SizedBox(height: 24),

          // Operational costs section
          _buildSection(
            title: 'Biaya Operasional',
            icon: Icons.store_outlined,
            iconColor: AppTheme.primaryColor,
            items: operational,
            category: 'operational',
          ),
          const SizedBox(height: 20),

          // Labor costs section
          _buildSection(
            title: 'Tenaga Kerja',
            icon: Icons.people_outline,
            iconColor: AppTheme.accentColor,
            items: labor,
            category: 'labor',
          ),
          const SizedBox(height: 20),

          // Bonus allocation section
          _buildBonusSection(bonusItem.isNotEmpty ? bonusItem.first : null, bonusPct),
          const SizedBox(height: 20),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total biaya bulanan akan otomatis dihitung ke HPP per porsi berdasarkan jumlah penjualan. Bonus dihitung dari laba bersih (Pendapatan - HPP Bahan - Biaya Operasional).',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusSection(OperationalCost? bonusItem, double bonusPct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.card_giftcard_rounded, size: 20, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            Text(
              'Alokasi Bonus Karyawan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Persentase dari Laba Bersih',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jika laba bersih positif, sekian persen akan dialokasikan sebagai bonus',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _BonusPercentInput(
                  currentValue: bonusPct,
                  onChanged: bonusItem != null
                      ? (val) => _updateCost(bonusItem.id, val)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double totalOps, double totalLabor, double grandTotal) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        children: [
          _buildSummaryCard('Operasional', totalOps, Icons.store_outlined, AppTheme.primaryColor),
          const SizedBox(height: 8),
          _buildSummaryCard('Tenaga Kerja', totalLabor, Icons.people_outline, AppTheme.accentColor),
          const SizedBox(height: 8),
          _buildSummaryCard('Total / Bulan', grandTotal, Icons.account_balance_wallet_outlined, AppTheme.successColor),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Operasional', totalOps, Icons.store_outlined, AppTheme.primaryColor)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Tenaga Kerja', totalLabor, Icons.people_outline, AppTheme.accentColor)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Total / Bulan', grandTotal, Icons.account_balance_wallet_outlined, AppTheme.successColor)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double amount, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FormatUtils.currency(amount),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<OperationalCost> items,
    required String category,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddCostDialog(category),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Center(
              child: Text(
                'Belum ada biaya',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final cost = entry.value;
                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1),
                    _CostItemTile(
                      cost: cost,
                      onAmountChanged: (amount) => _updateCost(cost.id, amount),
                      onDelete: () => _confirmDelete(cost),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showAddCostDialog(String category) {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == 'labor' ? 'Tambah Tenaga Kerja' : 'Tambah Biaya Operasional'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Biaya',
                    prefixIcon: Icon(Icons.label_outline),
                    hintText: 'Contoh: Sewa Tempat, Gaji Kasir',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah per Bulan',
                    prefixIcon: Icon(Icons.payments_outlined),
                    prefixText: 'Rp ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final outletId = ref.read(currentOutletIdProvider);
              try {
                await OperationalCostRepository().addCost(
                  outletId: outletId,
                  category: category,
                  name: nameController.text.trim(),
                  amount: double.tryParse(amountController.text.trim()) ?? 0,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                ref.invalidate(operationalCostsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCost(String id, double amount) async {
    try {
      await OperationalCostRepository().updateCost(id, amount: amount);
      ref.invalidate(operationalCostsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal update: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _confirmDelete(OperationalCost cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Biaya'),
        content: Text('Yakin ingin menghapus "${cost.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await OperationalCostRepository().deleteCost(cost.id);
                ref.invalidate(operationalCostsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${cost.name}" berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Cost item tile (inline editable amount)
// ═══════════════════════════════════════════════════════════════════════════

class _CostItemTile extends StatefulWidget {
  final OperationalCost cost;
  final void Function(double) onAmountChanged;
  final VoidCallback onDelete;

  const _CostItemTile({
    required this.cost,
    required this.onAmountChanged,
    required this.onDelete,
  });

  @override
  State<_CostItemTile> createState() => _CostItemTileState();
}

class _CostItemTileState extends State<_CostItemTile> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.cost.amount.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_CostItemTile old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      _controller.text = widget.cost.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveAmount() {
    final amount = double.tryParse(_controller.text.trim()) ?? 0;
    widget.onAmountChanged(amount);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Name + notes
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.cost.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (widget.cost.notes != null && widget.cost.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.cost.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount (editable)
          SizedBox(
            width: isMobile ? 130 : 160,
            child: _editing
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: 'Rp ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onSubmitted: (_) => _saveAmount(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _saveAmount,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () => setState(() => _editing = true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              FormatUtils.currency(widget.cost.amount),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.cost.amount > 0
                                    ? AppTheme.textPrimary
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          Icon(Icons.edit_outlined, size: 14, color: AppTheme.textTertiary),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
            onPressed: widget.onDelete,
            tooltip: 'Hapus',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bonus percent input widget
// ═══════════════════════════════════════════════════════════════════════════

class _BonusPercentInput extends StatefulWidget {
  final double currentValue;
  final void Function(double)? onChanged;

  const _BonusPercentInput({
    required this.currentValue,
    this.onChanged,
  });

  @override
  State<_BonusPercentInput> createState() => _BonusPercentInputState();
}

class _BonusPercentInputState extends State<_BonusPercentInput> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentValue.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_BonusPercentInput old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      _controller.text = widget.currentValue.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final val = double.tryParse(_controller.text.trim()) ?? 0;
    final clamped = val.clamp(0, 100).toDouble();
    widget.onChanged?.call(clamped);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 120,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: '%',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: widget.onChanged != null ? () => setState(() => _editing = true) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.currentValue.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 14, color: AppTheme.warningColor),
          ],
        ),
      ),
    );
  }
}
