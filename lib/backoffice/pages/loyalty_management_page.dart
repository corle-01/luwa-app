import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/loyalty_provider.dart';
import '../repositories/loyalty_repository.dart';

class LoyaltyManagementPage extends ConsumerStatefulWidget {
  const LoyaltyManagementPage({super.key});

  @override
  ConsumerState<LoyaltyManagementPage> createState() => _LoyaltyManagementPageState();
}

class _LoyaltyManagementPageState extends ConsumerState<LoyaltyManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalitas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Program'),
            Tab(text: 'Riwayat Transaksi'),
          ],
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => _showProgramDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Program'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProgramTab(
            onAdd: () => _showProgramDialog(context, ref),
          ),
          const _TransactionHistoryTab(),
        ],
      ),
    );
  }

  void _showProgramDialog(BuildContext context, WidgetRef ref, {LoyaltyProgram? program}) {
    showDialog(
      context: context,
      builder: (context) => _ProgramFormDialog(
        program: program,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(loyaltyProgramsProvider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Tab 1: Program List
// ─────────────────────────────────────────────────

class _ProgramTab extends ConsumerWidget {
  final VoidCallback onAdd;

  const _ProgramTab({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(loyaltyProgramsProvider);

    return programsAsync.when(
      data: (programs) {
        if (programs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_outlined, size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'Belum ada program loyalitas',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buat program loyalitas untuk meningkatkan retensi pelanggan',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Program'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: programs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final program = programs[index];
            return _ProgramCard(
              program: program,
              onEdit: () {
                showDialog(
                  context: context,
                  builder: (context) => _ProgramFormDialog(
                    program: program,
                    onSaved: () => ref.invalidate(loyaltyProgramsProvider),
                  ),
                );
              },
              onDelete: () => _confirmDelete(context, ref, program),
              onToggle: (isActive) => _toggleProgram(context, ref, program, isActive),
            );
          },
        );
      },
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
              onPressed: () => ref.invalidate(loyaltyProgramsProvider),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LoyaltyProgram program) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Program'),
        content: Text('Yakin ingin menghapus program "${program.name}"?\n\nSemua data transaksi terkait akan tetap tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repo = ref.read(loyaltyRepositoryProvider);
                await repo.deleteProgram(program.id);
                ref.invalidate(loyaltyProgramsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Program "${program.name}" berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: AppTheme.errorColor),
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

  Future<void> _toggleProgram(BuildContext context, WidgetRef ref, LoyaltyProgram program, bool isActive) async {
    try {
      final repo = ref.read(loyaltyRepositoryProvider);
      await repo.updateProgram(
        id: program.id,
        name: program.name,
        description: program.description,
        pointsPerAmount: program.pointsPerAmount,
        amountPerPoint: program.amountPerPoint,
        minRedeemPoints: program.minRedeemPoints,
        redeemValue: program.redeemValue,
        isActive: isActive,
      );
      ref.invalidate(loyaltyProgramsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Program "${program.name}" ${isActive ? 'diaktifkan' : 'dinonaktifkan'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────
// Program Card
// ─────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final LoyaltyProgram program;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _ProgramCard({
    required this.program,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFFE11D48),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              program.name,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(),
                        ],
                      ),
                      if (program.description != null && program.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          program.description!,
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: program.isActive,
                  onChanged: onToggle,
                  activeColor: AppTheme.successColor,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                  onPressed: onDelete,
                  tooltip: 'Hapus',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ruleChip(
                  Icons.monetization_on_outlined,
                  'Mendapat ${FormatUtils.number(program.pointsPerAmount)} poin per ${FormatUtils.currency(program.amountPerPoint)}',
                  AppTheme.successColor,
                ),
                _ruleChip(
                  Icons.redeem_outlined,
                  'Min. tukar ${program.minRedeemPoints} poin',
                  AppTheme.accentColor,
                ),
                _ruleChip(
                  Icons.discount_outlined,
                  '1 poin = ${FormatUtils.currency(program.redeemValue)} diskon',
                  AppTheme.infoColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge() {
    final isActive = program.isActive;
    final label = isActive ? 'Aktif' : 'Nonaktif';
    final color = isActive ? AppTheme.successColor : AppTheme.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Widget _ruleChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Tab 2: Transaction History
// ─────────────────────────────────────────────────

class _TransactionHistoryTab extends ConsumerStatefulWidget {
  const _TransactionHistoryTab();

  @override
  ConsumerState<_TransactionHistoryTab> createState() => _TransactionHistoryTabState();
}

class _TransactionHistoryTabState extends ConsumerState<_TransactionHistoryTab> {
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(loyaltyTransactionsProvider(_typeFilter));

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Filter:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Semua',
                selected: _typeFilter == null,
                onSelected: () => setState(() => _typeFilter = null),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Dapat Poin',
                selected: _typeFilter == 'earn',
                onSelected: () => setState(() => _typeFilter = 'earn'),
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Tukar Poin',
                selected: _typeFilter == 'redeem',
                onSelected: () => setState(() => _typeFilter = 'redeem'),
                color: AppTheme.accentColor,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.invalidate(loyaltyTransactionsProvider(_typeFilter)),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Transaction list
        Expanded(
          child: txAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada transaksi loyalitas',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Transaksi akan muncul saat pelanggan mendapat atau menukar poin',
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return _TransactionRow(transaction: tx);
                },
              );
            },
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
                    onPressed: () => ref.invalidate(loyaltyTransactionsProvider(_typeFilter)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? chipColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final LoyaltyTransaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isEarn = transaction.type == 'earn';
    final typeColor = isEarn ? AppTheme.successColor : AppTheme.accentColor;
    final typeIcon = isEarn ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final typeLabel = isEarn ? 'Dapat Poin' : 'Tukar Poin';
    final pointSign = isEarn ? '+' : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        transaction.customerName ?? 'Pelanggan',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.description ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Points and amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$pointSign${transaction.points} poin',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
                const SizedBox(height: 2),
                if (transaction.amount > 0)
                  Text(
                    FormatUtils.currency(transaction.amount),
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Date
            Text(
              FormatUtils.date(transaction.createdAt),
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Program Form Dialog (Create / Edit)
// ─────────────────────────────────────────────────

class _ProgramFormDialog extends StatefulWidget {
  final LoyaltyProgram? program;
  final String outletId;
  final VoidCallback onSaved;

  const _ProgramFormDialog({this.program, required this.outletId, required this.onSaved});

  @override
  State<_ProgramFormDialog> createState() => _ProgramFormDialogState();
}

class _ProgramFormDialogState extends State<_ProgramFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pointsPerAmountController;
  late final TextEditingController _amountPerPointController;
  late final TextEditingController _minRedeemController;
  late final TextEditingController _redeemValueController;
  bool _saving = false;

  bool get _isEditing => widget.program != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.program?.name ?? '');
    _descriptionController = TextEditingController(text: widget.program?.description ?? '');
    _pointsPerAmountController = TextEditingController(
      text: widget.program != null ? _formatNum(widget.program!.pointsPerAmount) : '1',
    );
    _amountPerPointController = TextEditingController(
      text: widget.program != null ? _formatNum(widget.program!.amountPerPoint) : '10000',
    );
    _minRedeemController = TextEditingController(
      text: widget.program != null ? widget.program!.minRedeemPoints.toString() : '10',
    );
    _redeemValueController = TextEditingController(
      text: widget.program != null ? _formatNum(widget.program!.redeemValue) : '10000',
    );
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsPerAmountController.dispose();
    _amountPerPointController.dispose();
    _minRedeemController.dispose();
    _redeemValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Program Loyalitas' : 'Tambah Program Loyalitas'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Program',
                    prefixIcon: Icon(Icons.card_giftcard),
                    hintText: 'Contoh: Program Loyalitas Member',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nama program wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)',
                    prefixIcon: Icon(Icons.description_outlined),
                    hintText: 'Deskripsi singkat program loyalitas',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 20),
                Text(
                  'Aturan Mendapat Poin',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pointsPerAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Poin Diperoleh',
                          prefixIcon: Icon(Icons.star),
                          hintText: '1',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null || parsed <= 0) return 'Harus > 0';
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'per',
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _amountPerPointController,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah Belanja (Rp)',
                          prefixIcon: Icon(Icons.payments_outlined),
                          hintText: '10000',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null || parsed <= 0) return 'Harus > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.infoColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _earnPreviewText(),
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.infoColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Aturan Penukaran Poin',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _minRedeemController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Poin untuk Tukar',
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: '10',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    final parsed = int.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) return 'Harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _redeemValueController,
                  decoration: const InputDecoration(
                    labelText: 'Nilai Diskon per Poin (Rp)',
                    prefixIcon: Icon(Icons.redeem),
                    hintText: '10000',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) return 'Harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _redeemPreviewText(),
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }

  String _earnPreviewText() {
    final pts = double.tryParse(_pointsPerAmountController.text.trim()) ?? 1;
    final amt = double.tryParse(_amountPerPointController.text.trim()) ?? 10000;
    return 'Pelanggan mendapat ${FormatUtils.number(pts)} poin setiap belanja ${FormatUtils.currency(amt)}';
  }

  String _redeemPreviewText() {
    final minPts = int.tryParse(_minRedeemController.text.trim()) ?? 10;
    final val = double.tryParse(_redeemValueController.text.trim()) ?? 10000;
    final totalDiscount = minPts * val;
    return 'Min. $minPts poin untuk tukar. Contoh: $minPts poin = diskon ${FormatUtils.currency(totalDiscount)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = LoyaltyRepository();
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final pointsPerAmount = double.parse(_pointsPerAmountController.text.trim());
      final amountPerPoint = double.parse(_amountPerPointController.text.trim());
      final minRedeemPoints = int.parse(_minRedeemController.text.trim());
      final redeemValue = double.parse(_redeemValueController.text.trim());

      if (_isEditing) {
        await repo.updateProgram(
          id: widget.program!.id,
          name: name,
          description: description,
          pointsPerAmount: pointsPerAmount,
          amountPerPoint: amountPerPoint,
          minRedeemPoints: minRedeemPoints,
          redeemValue: redeemValue,
          isActive: widget.program!.isActive,
        );
      } else {
        await repo.createProgram(
          outletId: widget.outletId,
          name: name,
          description: description,
          pointsPerAmount: pointsPerAmount,
          amountPerPoint: amountPerPoint,
          minRedeemPoints: minRedeemPoints,
          redeemValue: redeemValue,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '"$name" berhasil diupdate' : '"$name" berhasil ditambahkan')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}
