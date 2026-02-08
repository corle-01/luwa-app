import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/table_provider.dart';
import '../repositories/table_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

class TableManagementPage extends ConsumerWidget {
  const TableManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tableListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Meja'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showTableDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Meja'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: tablesAsync.when(
        data: (tables) {
          if (tables.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_restaurant_outlined, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada meja',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah meja baru untuk mulai mengelola area restoran',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showTableDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Meja'),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
                  return _TableCard(
                    table: table,
                    onEdit: () => _showTableDialog(context, ref, table: table),
                    onDelete: () => _confirmDelete(context, ref, table),
                  );
                },
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
                onPressed: () => ref.invalidate(tableListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableDialog(BuildContext context, WidgetRef ref, {TableModel? table}) {
    showDialog(
      context: context,
      builder: (context) => _TableFormDialog(
        table: table,
        onSaved: () => ref.invalidate(tableListProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Meja'),
        content: Text('Yakin ingin menghapus Meja ${table.tableNumber}?'),
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
                final repo = ref.read(tableRepositoryProvider);
                await repo.deleteTable(table.id);
                ref.invalidate(tableListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Meja ${table.tableNumber} berhasil dihapus')),
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

class _TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableCard({
    required this.table,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: table.statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                table.statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: table.statusColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Table number (big, centered)
            Text(
              '${table.tableNumber}',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Meja',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            // Capacity
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${table.capacity} kursi',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            // Section
            if (table.section != null && table.section!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      table.section!,
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                  onPressed: onDelete,
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableFormDialog extends StatefulWidget {
  final TableModel? table;
  final VoidCallback onSaved;

  const _TableFormDialog({this.table, required this.onSaved});

  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tableNumberController;
  late final TextEditingController _capacityController;
  late final TextEditingController _sectionController;
  late String _selectedStatus;
  bool _saving = false;

  static const _statuses = [
    ('available', 'Tersedia'),
    ('occupied', 'Terisi'),
    ('reserved', 'Dipesan'),
    ('maintenance', 'Maintenance'),
  ];

  bool get _isEditing => widget.table != null;

  @override
  void initState() {
    super.initState();
    _tableNumberController = TextEditingController(
      text: widget.table != null ? '${widget.table!.tableNumber}' : '',
    );
    _capacityController = TextEditingController(
      text: widget.table != null ? '${widget.table!.capacity}' : '4',
    );
    _sectionController = TextEditingController(
      text: widget.table?.section ?? '',
    );
    _selectedStatus = widget.table?.status ?? 'available';
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _capacityController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Meja' : 'Tambah Meja Baru'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tableNumberController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Meja',
                  prefixIcon: Icon(Icons.tag),
                  hintText: 'Contoh: 1, 2, 3...',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nomor meja wajib diisi';
                  final num = int.tryParse(v.trim());
                  if (num == null || num <= 0) return 'Masukkan angka yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Kapasitas (jumlah kursi)',
                  prefixIcon: Icon(Icons.people),
                  hintText: 'Default: 4',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Kapasitas wajib diisi';
                  final num = int.tryParse(v.trim());
                  if (num == null || num <= 0) return 'Masukkan angka yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sectionController,
                decoration: const InputDecoration(
                  labelText: 'Section (opsional)',
                  prefixIcon: Icon(Icons.place),
                  hintText: 'Contoh: Indoor, Outdoor, VIP',
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedStatus = v);
                  },
                ),
              ],
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
      final repo = TableRepository();
      final tableNumber = int.parse(_tableNumberController.text.trim());
      final capacity = int.parse(_capacityController.text.trim());
      final section = _sectionController.text.trim().isEmpty ? null : _sectionController.text.trim();

      if (_isEditing) {
        await repo.updateTable(
          id: widget.table!.id,
          tableNumber: tableNumber,
          capacity: capacity,
          section: section ?? '',
          status: _selectedStatus,
        );
      } else {
        await repo.createTable(
          outletId: _outletId,
          tableNumber: tableNumber,
          capacity: capacity,
          section: section,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Meja $tableNumber berhasil diupdate' : 'Meja $tableNumber berhasil ditambahkan')),
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
