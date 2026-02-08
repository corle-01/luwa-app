import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/themes/app_theme.dart';
import '../../core/providers/outlet_provider.dart';

// All outlets (including inactive) for management
final _allOutletsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('outlets')
      .select()
      .order('name');
  return List<Map<String, dynamic>>.from(res);
});

class OutletManagementPage extends ConsumerWidget {
  const OutletManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletsAsync = ref.watch(_allOutletsProvider);
    final currentOutletId = ref.watch(currentOutletIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Outlet'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showOutletDialog(context, ref),
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('Tambah Outlet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: outletsAsync.when(
        data: (outlets) {
          if (outlets.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return _buildOutletList(context, ref, outlets, currentOutletId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(context, ref, e),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Belum ada outlet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambah outlet baru untuk memulai',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showOutletDialog(context, ref),
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('Tambah Outlet'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.invalidate(_allOutletsProvider),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletList(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> outlets,
    String currentOutletId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemCount: outlets.length,
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            final isCurrent = outlet['id'] == currentOutletId;

            return _OutletCard(
              outlet: outlet,
              isCurrent: isCurrent,
              onEdit: () => _showOutletDialog(context, ref, outlet: outlet),
              onDelete: () => _confirmDelete(context, ref, outlet),
              onToggleActive: () => _toggleActive(context, ref, outlet),
            );
          },
        );
      },
    );
  }

  void _showOutletDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? outlet}) {
    showDialog(
      context: context,
      builder: (context) => _OutletFormDialog(
        outlet: outlet,
        onSaved: () {
          ref.invalidate(_allOutletsProvider);
          ref.invalidate(outletsListProvider);
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> outlet) {
    final name = outlet['name'] as String? ?? 'Outlet';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yakin ingin menghapus outlet "$name"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.errorColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua data terkait outlet ini (produk, pesanan, dll) juga akan terhapus.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client
                    .from('outlets')
                    .delete()
                    .eq('id', outlet['id']);
                ref.invalidate(_allOutletsProvider);
                ref.invalidate(outletsListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$name" berhasil dihapus')),
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

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, Map<String, dynamic> outlet) async {
    final isActive = outlet['is_active'] as bool? ?? true;
    final name = outlet['name'] as String? ?? 'Outlet';
    try {
      await Supabase.instance.client
          .from('outlets')
          .update({'is_active': !isActive}).eq('id', outlet['id']);
      ref.invalidate(_allOutletsProvider);
      ref.invalidate(outletsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? '"$name" dinonaktifkan'
                  : '"$name" diaktifkan kembali',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Outlet Card
// ---------------------------------------------------------------------------

class _OutletCard extends StatefulWidget {
  final Map<String, dynamic> outlet;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _OutletCard({
    required this.outlet,
    required this.isCurrent,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  State<_OutletCard> createState() => _OutletCardState();
}

class _OutletCardState extends State<_OutletCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.outlet['name'] as String? ?? '-';
    final address = widget.outlet['address'] as String?;
    final phone = widget.outlet['phone'] as String?;
    final email = widget.outlet['email'] as String?;
    final isActive = widget.outlet['is_active'] as bool? ?? true;
    final timezone = widget.outlet['timezone'] as String? ?? 'Asia/Jakarta';
    final currency = widget.outlet['currency'] as String? ?? 'IDR';

    final cardColor = widget.isCurrent
        ? const Color(0xFF0D9488)
        : isActive
            ? AppTheme.primaryColor
            : AppTheme.textTertiary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? cardColor : AppTheme.borderColor,
              width: _hovering || widget.isCurrent ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? cardColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hovering ? 16 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: icon + name + badges
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.store_rounded,
                        color: cardColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '$timezone  |  $currency',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Badges
                    if (widget.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Aktif',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    if (!isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Nonaktif',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Info rows
                if (address != null && address.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: address,
                  ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    text: phone,
                  ),
                ],
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    text: email,
                  ),
                ],
                const Spacer(),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionChip(
                      icon: isActive
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      label: isActive ? 'Nonaktifkan' : 'Aktifkan',
                      color: isActive
                          ? AppTheme.warningColor
                          : AppTheme.successColor,
                      onTap: widget.onToggleActive,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: AppTheme.primaryColor,
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.delete_outline,
                      label: 'Hapus',
                      color: AppTheme.errorColor,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outlet Form Dialog
// ---------------------------------------------------------------------------

class _OutletFormDialog extends StatefulWidget {
  final Map<String, dynamic>? outlet;
  final VoidCallback onSaved;

  const _OutletFormDialog({this.outlet, required this.onSaved});

  @override
  State<_OutletFormDialog> createState() => _OutletFormDialogState();
}

class _OutletFormDialogState extends State<_OutletFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late String _selectedTimezone;
  late String _selectedCurrency;
  bool _saving = false;

  bool get _isEditing => widget.outlet != null;

  static const _timezones = [
    ('Asia/Jakarta', 'WIB (Jakarta)'),
    ('Asia/Makassar', 'WITA (Makassar)'),
    ('Asia/Jayapura', 'WIT (Jayapura)'),
    ('Asia/Singapore', 'SGT (Singapore)'),
    ('Asia/Kuala_Lumpur', 'MYT (Kuala Lumpur)'),
  ];

  static const _currencies = [
    ('IDR', 'IDR - Rupiah'),
    ('USD', 'USD - Dollar'),
    ('SGD', 'SGD - Singapore Dollar'),
    ('MYR', 'MYR - Ringgit'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.outlet?['name'] as String? ?? '');
    _addressController =
        TextEditingController(text: widget.outlet?['address'] as String? ?? '');
    _phoneController =
        TextEditingController(text: widget.outlet?['phone'] as String? ?? '');
    _emailController =
        TextEditingController(text: widget.outlet?['email'] as String? ?? '');
    _selectedTimezone =
        widget.outlet?['timezone'] as String? ?? 'Asia/Jakarta';
    _selectedCurrency = widget.outlet?['currency'] as String? ?? 'IDR';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_rounded : Icons.add_business_rounded,
            color: const Color(0xFF0D9488),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(_isEditing ? 'Edit Outlet' : 'Tambah Outlet Baru'),
        ],
      ),
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
                    labelText: 'Nama Outlet *',
                    prefixIcon: Icon(Icons.store),
                    hintText: 'cth. Warung Makan Bahagia - Cabang Sudirman',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nama outlet wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'Jl. Sudirman No. 123',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '08123456789',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    hintText: 'outlet@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _timezones.any((t) => t.$1 == _selectedTimezone)
                      ? _selectedTimezone
                      : 'Asia/Jakarta',
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: _timezones
                      .map((t) =>
                          DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedTimezone = v);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _currencies.any((c) => c.$1 == _selectedCurrency)
                      ? _selectedCurrency
                      : 'IDR',
                  decoration: const InputDecoration(
                    labelText: 'Mata Uang',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  items: _currencies
                      .map((c) =>
                          DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCurrency = v);
                  },
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
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
      final data = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'timezone': _selectedTimezone,
        'currency': _selectedCurrency,
      };

      if (_isEditing) {
        await Supabase.instance.client
            .from('outlets')
            .update(data)
            .eq('id', widget.outlet!['id']);
      } else {
        await Supabase.instance.client.from('outlets').insert(data);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        final name = _nameController.text.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? '"$name" berhasil diupdate'
                : '"$name" berhasil ditambahkan'),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
