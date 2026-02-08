import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/tax_provider.dart';
import '../repositories/tax_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

class TaxManagementPage extends ConsumerWidget {
  const TaxManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxAsync = ref.watch(taxListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pajak'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showTaxDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Pajak'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: taxAsync.when(
        data: (taxList) {
          if (taxList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada pajak',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah pajak atau service charge untuk outlet Anda',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showTaxDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Pajak'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: taxList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tax = taxList[index];
              return _TaxCard(
                tax: tax,
                onEdit: () => _showTaxDialog(context, ref, tax: tax),
                onDelete: () => _confirmDelete(context, ref, tax),
                onToggle: (isActive) => _toggleTax(context, ref, tax, isActive),
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
                onPressed: () => ref.invalidate(taxListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaxDialog(BuildContext context, WidgetRef ref, {TaxModel? tax}) {
    showDialog(
      context: context,
      builder: (context) => _TaxFormDialog(
        tax: tax,
        onSaved: () => ref.invalidate(taxListProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TaxModel tax) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pajak'),
        content: Text('Yakin ingin menghapus "${tax.name}"?'),
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
                final repo = ref.read(taxRepositoryProvider);
                await repo.deleteTax(tax.id);
                ref.invalidate(taxListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tax.name} berhasil dihapus')),
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

  Future<void> _toggleTax(BuildContext context, WidgetRef ref, TaxModel tax, bool isActive) async {
    try {
      final repo = ref.read(taxRepositoryProvider);
      await repo.toggleTax(tax.id, isActive);
      ref.invalidate(taxListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tax.name} ${isActive ? 'diaktifkan' : 'dinonaktifkan'}')),
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

class _TaxCard extends StatelessWidget {
  final TaxModel tax;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _TaxCard({
    required this.tax,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (tax.isActive ? AppTheme.primaryColor : AppTheme.textTertiary).withValues(alpha: 0.15),
          child: Icon(
            tax.type == 'percentage' ? Icons.percent : Icons.payments_outlined,
            color: tax.isActive ? AppTheme.primaryColor : AppTheme.textTertiary,
            size: 22,
          ),
        ),
        title: Text(
          tax.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: tax.isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tax.displayValue,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (tax.type == 'percentage' ? AppTheme.infoColor : AppTheme.accentColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tax.typeLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tax.type == 'percentage' ? AppTheme.infoColor : AppTheme.accentColor,
                ),
              ),
            ),
            if (tax.isInclusive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inklusif',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.successColor),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: tax.isActive,
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
      ),
    );
  }
}

class _TaxFormDialog extends StatefulWidget {
  final TaxModel? tax;
  final VoidCallback onSaved;

  const _TaxFormDialog({this.tax, required this.onSaved});

  @override
  State<_TaxFormDialog> createState() => _TaxFormDialogState();
}

class _TaxFormDialogState extends State<_TaxFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late String _selectedType;
  late bool _isInclusive;
  bool _saving = false;

  static const _types = [
    ('percentage', 'Persentase (%)'),
    ('fixed', 'Nominal (Rp)'),
  ];

  bool get _isEditing => widget.tax != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tax?.name ?? '');
    _valueController = TextEditingController(
      text: widget.tax != null
          ? (widget.tax!.value.truncateToDouble() == widget.tax!.value
              ? widget.tax!.value.toInt().toString()
              : widget.tax!.value.toString())
          : '',
    );
    _selectedType = widget.tax?.type ?? 'percentage';
    _isInclusive = widget.tax?.isInclusive ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Pajak' : 'Tambah Pajak Baru'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pajak',
                  prefixIcon: Icon(Icons.label),
                  hintText: 'cth: PPN, Service Charge',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama pajak wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipe',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _types
                    .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedType = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: 'Nilai',
                  prefixIcon: Icon(
                    _selectedType == 'percentage' ? Icons.percent : Icons.payments_outlined,
                  ),
                  hintText: _selectedType == 'percentage' ? 'cth: 10' : 'cth: 5000',
                  suffixText: _selectedType == 'percentage' ? '%' : 'Rp',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nilai wajib diisi';
                  }
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Masukkan angka yang valid';
                  }
                  if (_selectedType == 'percentage' && parsed > 100) {
                    return 'Persentase tidak boleh lebih dari 100%';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  'Pajak Inklusif',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Pajak sudah termasuk dalam harga produk',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                ),
                value: _isInclusive,
                onChanged: (v) => setState(() => _isInclusive = v),
                activeColor: AppTheme.successColor,
                contentPadding: EdgeInsets.zero,
              ),
            ],
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = TaxRepository();
      final name = _nameController.text.trim();
      final value = double.parse(_valueController.text.trim());

      if (_isEditing) {
        await repo.updateTax(
          id: widget.tax!.id,
          name: name,
          type: _selectedType,
          value: value,
          isInclusive: _isInclusive,
        );
      } else {
        await repo.createTax(
          outletId: _outletId,
          name: name,
          type: _selectedType,
          value: value,
          isInclusive: _isInclusive,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '$name berhasil diupdate' : '$name berhasil ditambahkan')),
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
