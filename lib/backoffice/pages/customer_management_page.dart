import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/customer_provider.dart';
import '../repositories/customer_repository.dart';

class CustomerManagementPage extends ConsumerWidget {
  const CustomerManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showCustomerDialog(context, ref),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Tambah Pelanggan'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: customerAsync.when(
        data: (customerList) {
          if (customerList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada pelanggan',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah pelanggan baru untuk mulai',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCustomerDialog(context, ref),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Tambah Pelanggan'),
                  ),
                ],
              ),
            );
          }

          return _CustomerListWithSearch(
            customers: customerList,
            onEdit: (customer) => _showCustomerDialog(context, ref, customer: customer),
            onDelete: (customer) => _confirmDelete(context, ref, customer),
            onAdd: () => _showCustomerDialog(context, ref),
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
                onPressed: () => ref.invalidate(customerListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerDialog(BuildContext context, WidgetRef ref, {CustomerModel? customer}) {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(
        customer: customer,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(customerListProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text('Yakin ingin menghapus ${customer.name}?'),
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
                final repo = ref.read(customerRepositoryProvider);
                await repo.deleteCustomer(customer.id);
                ref.invalidate(customerListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${customer.name} berhasil dihapus')),
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
}

class _CustomerListWithSearch extends StatefulWidget {
  final List<CustomerModel> customers;
  final void Function(CustomerModel) onEdit;
  final void Function(CustomerModel) onDelete;
  final VoidCallback onAdd;

  const _CustomerListWithSearch({
    required this.customers,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<_CustomerListWithSearch> createState() => _CustomerListWithSearchState();
}

class _CustomerListWithSearchState extends State<_CustomerListWithSearch> {
  final _searchController = TextEditingController();
  List<CustomerModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
  }

  @override
  void didUpdateWidget(covariant _CustomerListWithSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customers != widget.customers) {
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
        _filtered = widget.customers;
      } else {
        _filtered = widget.customers.where((c) {
          return c.name.toLowerCase().contains(query) ||
              (c.phone != null && c.phone!.toLowerCase().contains(query)) ||
              (c.email != null && c.email!.toLowerCase().contains(query));
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
              hintText: 'Cari pelanggan berdasarkan nama atau telepon...',
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
                    'Tidak ada pelanggan ditemukan',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coba kata kunci lain atau tambah pelanggan baru',
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
                final customer = _filtered[index];
                return _CustomerCard(
                  customer: customer,
                  onEdit: () => widget.onEdit(customer),
                  onDelete: () => widget.onDelete(customer),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
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
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                            Icon(Icons.phone_outlined, size: 13, color: AppTheme.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              customer.phone!,
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (customer.email != null && customer.email!.isNotEmpty) ...[
                            Icon(Icons.email_outlined, size: 13, color: AppTheme.textTertiary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                customer.email!,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
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
            Row(
              children: [
                _StatChip(
                  icon: Icons.shopping_bag_outlined,
                  label: '${customer.totalVisits} kunjungan',
                  color: AppTheme.infoColor,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: FormatUtils.currency(customer.totalSpent),
                  color: AppTheme.successColor,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.star,
                  label: '${customer.loyaltyPoints} poin',
                  color: AppTheme.accentColor,
                ),
                const Spacer(),
                if (customer.createdAt != null)
                  Text(
                    'Member sejak ${FormatUtils.date(customer.createdAt!)}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
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
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

class _CustomerFormDialog extends StatefulWidget {
  final CustomerModel? customer;
  final String outletId;
  final VoidCallback onSaved;

  const _CustomerFormDialog({this.customer, required this.outletId, required this.onSaved});

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  bool _saving = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
    _notesController = TextEditingController(text: widget.customer?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
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
      final repo = CustomerRepository();
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (_isEditing) {
        await repo.updateCustomer(
          id: widget.customer!.id,
          name: name,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
        );
      } else {
        await repo.createCustomer(
          outletId: widget.outletId,
          name: name,
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
