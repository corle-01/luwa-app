import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/staff_provider.dart';
import '../repositories/staff_repository.dart';

class StaffManagementPage extends ConsumerWidget {
  const StaffManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Staff'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showStaffDialog(context, ref),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Tambah Staff'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: staffAsync.when(
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada staff',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah kasir atau staff baru untuk mulai',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showStaffDialog(context, ref),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Tambah Staff'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staffList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return _StaffCard(
                staff: staff,
                onEdit: () => _showStaffDialog(context, ref, staff: staff),
                onDelete: () => _confirmDelete(context, ref, staff),
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
                onPressed: () => ref.invalidate(staffListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffDialog(BuildContext context, WidgetRef ref, {StaffProfile? staff}) {
    showDialog(
      context: context,
      builder: (context) => _StaffFormDialog(
        staff: staff,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(staffListProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, StaffProfile staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Staff'),
        content: Text('Yakin ingin menghapus ${staff.fullName}?'),
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
                final repo = ref.read(staffRepositoryProvider);
                await repo.deleteStaff(staff.id);
                ref.invalidate(staffListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${staff.fullName} berhasil dihapus')),
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

class _StaffCard extends StatelessWidget {
  final StaffProfile staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.staff,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor(staff.role).withValues(alpha: 0.15),
          child: Icon(_roleIcon(staff.role), color: _roleColor(staff.role), size: 22),
        ),
        title: Text(
          staff.fullName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor(staff.role).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                staff.roleLabel,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _roleColor(staff.role)),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              staff.hasPin ? Icons.lock : Icons.lock_open,
              size: 14,
              color: staff.hasPin ? AppTheme.successColor : AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              staff.hasPin ? 'PIN aktif' : 'Tanpa PIN',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return AppTheme.aiPrimary;
      case 'admin':
        return AppTheme.primaryColor;
      case 'manager':
        return AppTheme.accentColor;
      case 'cashier':
        return AppTheme.successColor;
      case 'kitchen':
        return AppTheme.warningColor;
      case 'waiter':
        return AppTheme.infoColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.star;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'cashier':
        return Icons.point_of_sale;
      case 'kitchen':
        return Icons.restaurant;
      case 'waiter':
        return Icons.room_service;
      default:
        return Icons.person;
    }
  }
}

class _StaffFormDialog extends StatefulWidget {
  final StaffProfile? staff;
  final String outletId;
  final VoidCallback onSaved;

  const _StaffFormDialog({this.staff, required this.outletId, required this.onSaved});

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _pinController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late String _selectedRole;
  bool _saving = false;

  static const _roles = [
    ('cashier', 'Kasir'),
    ('admin', 'Admin'),
    ('manager', 'Manager'),
    ('kitchen', 'Kitchen'),
    ('waiter', 'Waiter'),
  ];

  bool get _isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff?.fullName ?? '');
    _pinController = TextEditingController(text: widget.staff?.pin ?? '');
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _phoneController = TextEditingController(text: widget.staff?.phone ?? '');
    _selectedRole = widget.staff?.role ?? 'cashier';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Staff' : 'Tambah Staff Baru'),
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
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRole = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'PIN (opsional)',
                  prefixIcon: Icon(Icons.lock),
                  hintText: '4 digit',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length < 4) {
                    return 'PIN minimal 4 digit';
                  }
                  return null;
                },
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
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telepon (opsional)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
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
      final repo = StaffRepository();
      final name = _nameController.text.trim();
      final pin = _pinController.text.trim().isEmpty ? null : _pinController.text.trim();
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

      if (_isEditing) {
        await repo.updateStaff(
          id: widget.staff!.id,
          fullName: name,
          role: _selectedRole,
          pin: pin,
          email: email,
          phone: phone,
        );
      } else {
        await repo.createStaff(
          outletId: widget.outletId,
          fullName: name,
          role: _selectedRole,
          pin: pin,
          email: email,
          phone: phone,
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
