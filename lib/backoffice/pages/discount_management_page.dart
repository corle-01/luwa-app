import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/discount_provider.dart';
import '../repositories/discount_repository.dart';

class DiscountManagementPage extends ConsumerWidget {
  const DiscountManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountAsync = ref.watch(discountListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Diskon'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showDiscountDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Diskon'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: discountAsync.when(
        data: (discountList) {
          if (discountList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.discount_outlined, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada diskon',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah diskon baru untuk pelanggan Anda',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showDiscountDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Diskon'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: discountList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final discount = discountList[index];
              return _DiscountCard(
                discount: discount,
                onEdit: () => _showDiscountDialog(context, ref, discount: discount),
                onDelete: () => _confirmDelete(context, ref, discount),
                onToggle: (isActive) => _toggleDiscount(context, ref, discount, isActive),
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
                onPressed: () => ref.invalidate(discountListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref, {DiscountModel? discount}) {
    showDialog(
      context: context,
      builder: (context) => _DiscountFormDialog(
        discount: discount,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(discountListProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DiscountModel discount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Diskon'),
        content: Text('Yakin ingin menghapus diskon "${discount.name}"?'),
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
                final repo = ref.read(discountRepositoryProvider);
                await repo.deleteDiscount(discount.id);
                ref.invalidate(discountListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Diskon "${discount.name}" berhasil dihapus')),
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

  Future<void> _toggleDiscount(BuildContext context, WidgetRef ref, DiscountModel discount, bool isActive) async {
    try {
      final repo = ref.read(discountRepositoryProvider);
      await repo.toggleDiscount(discount.id, isActive);
      ref.invalidate(discountListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diskon "${discount.name}" ${isActive ? 'diaktifkan' : 'dinonaktifkan'}')),
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

class _DiscountCard extends StatelessWidget {
  final DiscountModel discount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _DiscountCard({
    required this.discount,
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
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        discount.name,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      _typeBadge(),
                      const SizedBox(width: 8),
                      _statusBadge(),
                    ],
                  ),
                ),
                Switch(
                  value: discount.isActive,
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
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip(Icons.sell, 'Nilai: ${discount.displayValue}'),
                const SizedBox(width: 12),
                if (discount.minPurchase > 0)
                  _infoChip(Icons.shopping_cart, 'Min. belanja: ${FormatUtils.currency(discount.minPurchase)}'),
                if (discount.minPurchase > 0)
                  const SizedBox(width: 12),
                if (discount.isPercentage && discount.maxDiscount != null)
                  _infoChip(Icons.arrow_upward, 'Maks. diskon: ${FormatUtils.currency(discount.maxDiscount!)}'),
              ],
            ),
            if (discount.validFrom != null || discount.validUntil != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    _validityText(),
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeBadge() {
    final isPercent = discount.isPercentage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isPercent ? AppTheme.primaryColor : AppTheme.accentColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPercent ? '%' : 'Rp',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPercent ? AppTheme.primaryColor : AppTheme.accentColor,
        ),
      ),
    );
  }

  Widget _statusBadge() {
    String label;
    Color color;

    if (!discount.isActive) {
      label = 'Nonaktif';
      color = AppTheme.textTertiary;
    } else if (discount.isExpired) {
      label = 'Kedaluwarsa';
      color = AppTheme.warningColor;
    } else {
      label = 'Aktif';
      color = AppTheme.successColor;
    }

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

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  String _validityText() {
    final from = discount.validFrom;
    final until = discount.validUntil;

    if (from != null && until != null) {
      return '${FormatUtils.date(from)} - ${FormatUtils.date(until)}';
    } else if (from != null) {
      return 'Mulai ${FormatUtils.date(from)}';
    } else if (until != null) {
      return 'Sampai ${FormatUtils.date(until)}';
    }
    return '';
  }
}

class _DiscountFormDialog extends StatefulWidget {
  final DiscountModel? discount;
  final String outletId;
  final VoidCallback onSaved;

  const _DiscountFormDialog({this.discount, required this.outletId, required this.onSaved});

  @override
  State<_DiscountFormDialog> createState() => _DiscountFormDialogState();
}

class _DiscountFormDialogState extends State<_DiscountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _minPurchaseController;
  late final TextEditingController _maxDiscountController;
  late String _selectedType;
  DateTime? _validFrom;
  DateTime? _validUntil;
  bool _saving = false;

  static const _types = [
    ('percentage', 'Persentase'),
    ('fixed', 'Nominal'),
  ];

  bool get _isEditing => widget.discount != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.discount?.name ?? '');
    _valueController = TextEditingController(
      text: widget.discount != null ? _formatNumber(widget.discount!.value) : '',
    );
    _minPurchaseController = TextEditingController(
      text: widget.discount != null && widget.discount!.minPurchase > 0
          ? _formatNumber(widget.discount!.minPurchase)
          : '',
    );
    _maxDiscountController = TextEditingController(
      text: widget.discount?.maxDiscount != null
          ? _formatNumber(widget.discount!.maxDiscount!)
          : '',
    );
    _selectedType = widget.discount?.type ?? 'percentage';
    _validFrom = widget.discount?.validFrom;
    _validUntil = widget.discount?.validUntil;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _minPurchaseController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Diskon' : 'Tambah Diskon Baru'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Diskon',
                    prefixIcon: Icon(Icons.discount),
                    hintText: 'Contoh: Diskon Member 10%',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nama diskon wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipe Diskon',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _types
                      .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedType = v;
                        if (v == 'fixed') {
                          _maxDiscountController.clear();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueController,
                  decoration: InputDecoration(
                    labelText: 'Nilai Diskon',
                    prefixIcon: Icon(_selectedType == 'percentage' ? Icons.percent : Icons.payments),
                    prefixText: _selectedType == 'percentage' ? null : 'Rp ',
                    suffixText: _selectedType == 'percentage' ? '%' : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nilai diskon wajib diisi';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) return 'Nilai harus lebih dari 0';
                    if (_selectedType == 'percentage' && parsed > 100) {
                      return 'Persentase maksimal 100%';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minPurchaseController,
                  decoration: const InputDecoration(
                    labelText: 'Minimal Belanja (opsional)',
                    prefixIcon: Icon(Icons.shopping_cart),
                    prefixText: 'Rp ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
                if (_selectedType == 'percentage') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maxDiscountController,
                    decoration: const InputDecoration(
                      labelText: 'Maksimal Diskon (opsional)',
                      prefixIcon: Icon(Icons.arrow_upward),
                      prefixText: 'Rp ',
                      hintText: 'Batas maksimal potongan',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _DatePickerField(
                  label: 'Berlaku Dari (opsional)',
                  value: _validFrom,
                  onChanged: (date) => setState(() => _validFrom = date),
                ),
                const SizedBox(height: 12),
                _DatePickerField(
                  label: 'Berlaku Sampai (opsional)',
                  value: _validUntil,
                  onChanged: (date) => setState(() => _validUntil = date),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = DiscountRepository();
      final name = _nameController.text.trim();
      final value = double.parse(_valueController.text.trim());
      final minPurchase = _minPurchaseController.text.trim().isEmpty
          ? null
          : double.tryParse(_minPurchaseController.text.trim());
      final maxDiscount = _maxDiscountController.text.trim().isEmpty
          ? null
          : double.tryParse(_maxDiscountController.text.trim());

      if (_isEditing) {
        await repo.updateDiscount(
          id: widget.discount!.id,
          name: name,
          type: _selectedType,
          value: value,
          minPurchase: minPurchase,
          maxDiscount: _selectedType == 'percentage' ? maxDiscount : null,
          validFrom: _validFrom,
          validUntil: _validUntil,
        );
      } else {
        await repo.createDiscount(
          outletId: widget.outletId,
          name: name,
          type: _selectedType,
          value: value,
          minPurchase: minPurchase,
          maxDiscount: _selectedType == 'percentage' ? maxDiscount : null,
          validFrom: _validFrom,
          validUntil: _validUntil,
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('id', 'ID'),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          value != null ? FormatUtils.date(value!) : 'Pilih tanggal',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: value != null ? AppTheme.textPrimary : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
