import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/supplier_provider.dart';
import '../repositories/supplier_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

class SupplierManagementPage extends ConsumerWidget {
  const SupplierManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showSupplierDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Supplier'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: supplierAsync.when(
        data: (supplierList) {
          if (supplierList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada supplier',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah supplier baru untuk mulai',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showSupplierDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Supplier'),
                  ),
                ],
              ),
            );
          }

          return _SupplierListWithSearch(
            suppliers: supplierList,
            onEdit: (supplier) => _showSupplierDialog(context, ref, supplier: supplier),
            onDelete: (supplier) => _confirmDelete(context, ref, supplier),
            onAdd: () => _showSupplierDialog(context, ref),
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
                onPressed: () => ref.invalidate(supplierListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupplierDialog(BuildContext context, WidgetRef ref, {SupplierModel? supplier}) {
    showDialog(
      context: context,
      builder: (context) => _SupplierFormDialog(
        supplier: supplier,
        onSaved: () => ref.invalidate(supplierListProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Supplier'),
        content: Text('Yakin ingin menghapus ${supplier.name}?'),
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
                final repo = ref.read(supplierRepositoryProvider);
                await repo.deleteSupplier(supplier.id);
                ref.invalidate(supplierListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${supplier.name} berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
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

// ---------------------------------------------------------------------------
// Supplier list with search
// ---------------------------------------------------------------------------
class _SupplierListWithSearch extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final void Function(SupplierModel) onEdit;
  final void Function(SupplierModel) onDelete;
  final VoidCallback onAdd;

  const _SupplierListWithSearch({
    required this.suppliers,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<_SupplierListWithSearch> createState() => _SupplierListWithSearchState();
}

class _SupplierListWithSearchState extends State<_SupplierListWithSearch> {
  final _searchController = TextEditingController();
  List<SupplierModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.suppliers;
  }

  @override
  void didUpdateWidget(covariant _SupplierListWithSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suppliers != widget.suppliers) {
      _applyFilter();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.suppliers;
      } else {
        _filtered = widget.suppliers.where((s) {
          return s.name.toLowerCase().contains(query) ||
              (s.contactPerson != null && s.contactPerson!.toLowerCase().contains(query)) ||
              (s.phone != null && s.phone!.toLowerCase().contains(query)) ||
              (s.email != null && s.email!.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilter(),
            decoration: InputDecoration(
              hintText: 'Cari supplier berdasarkan nama, kontak, atau telepon...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilter();
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 48, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada supplier ditemukan',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coba kata kunci lain atau tambah supplier baru',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final supplier = _filtered[index];
                return _SupplierCard(
                  supplier: supplier,
                  onEdit: () => widget.onEdit(supplier),
                  onDelete: () => widget.onDelete(supplier),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Supplier card
// ---------------------------------------------------------------------------
class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
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
                CircleAvatar(
                  backgroundColor: const Color(0xFF0891B2).withValues(alpha: 0.15),
                  child: Text(
                    supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0891B2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 13, color: AppTheme.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              supplier.contactPerson!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
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
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (supplier.phone != null && supplier.phone!.isNotEmpty)
                  _InfoChip(
                    icon: Icons.phone_outlined,
                    label: supplier.phone!,
                    color: AppTheme.infoColor,
                  ),
                if (supplier.email != null && supplier.email!.isNotEmpty)
                  _InfoChip(
                    icon: Icons.email_outlined,
                    label: supplier.email!,
                    color: AppTheme.successColor,
                  ),
                if (supplier.address != null && supplier.address!.isNotEmpty)
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: supplier.address!,
                    color: AppTheme.accentColor,
                  ),
              ],
            ),
            if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                supplier.notes!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info chip
// ---------------------------------------------------------------------------
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supplier form dialog
// ---------------------------------------------------------------------------
class _SupplierFormDialog extends StatefulWidget {
  final SupplierModel? supplier;
  final VoidCallback onSaved;

  const _SupplierFormDialog({this.supplier, required this.onSaved});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  bool _saving = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactPersonController = TextEditingController(text: widget.supplier?.contactPerson ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _emailController = TextEditingController(text: widget.supplier?.email ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
    _notesController = TextEditingController(text: widget.supplier?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Supplier' : 'Tambah Supplier Baru'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Supplier',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactPersonController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kontak (opsional)',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telepon (opsional)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (opsional)',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat (opsional)',
                    prefixIcon: Icon(Icons.location_on),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = SupplierRepository();
      final name = _nameController.text.trim();
      final contactPerson = _contactPersonController.text.trim().isEmpty
          ? null
          : _contactPersonController.text.trim();
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (_isEditing) {
        await repo.updateSupplier(
          id: widget.supplier!.id,
          name: name,
          contactPerson: contactPerson,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
        );
      } else {
        await repo.createSupplier(
          outletId: _outletId,
          name: name,
          contactPerson: contactPerson,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '$name berhasil diupdate' : '$name berhasil ditambahkan'),
          ),
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
