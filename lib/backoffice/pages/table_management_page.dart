import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import '../../shared/themes/app_theme.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/table_provider.dart';
import '../repositories/table_repository.dart';

const _selfOrderBaseUrl =
    'https://ardhianawing.github.io/luwaapp/office/#/self-order';

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
        outletId: ref.read(currentOutletIdProvider),
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

  void _showQrDialog(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (context) => _TableQrDialog(table: table),
    );
  }

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
                  icon: Icon(Icons.qr_code_rounded, size: 18, color: AppTheme.primaryColor),
                  onPressed: () => _showQrDialog(context, table),
                  tooltip: 'QR Code',
                  visualDensity: VisualDensity.compact,
                ),
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
  final String outletId;
  final VoidCallback onSaved;

  const _TableFormDialog({this.table, required this.outletId, required this.onSaved});

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
      final tableNumber = _tableNumberController.text.trim();
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
          outletId: widget.outletId,
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

// ---------------------------------------------------------------------------
// QR Code Dialog for a table
// ---------------------------------------------------------------------------
class _TableQrDialog extends StatelessWidget {
  final TableModel table;

  const _TableQrDialog({required this.table});

  String get _selfOrderUrl =>
      '$_selfOrderBaseUrl?table=${table.id}';

  String get _qrImageUrl =>
      'https://api.qrserver.com/v1/create-qr-code/?size=500x500&data=${Uri.encodeComponent(_selfOrderUrl)}';

  /// Download QR code image via browser
  void _downloadQr(BuildContext context) {
    try {
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = _qrImageUrl;
      anchor.download = 'qr_meja_${table.tableNumber}.png';
      anchor.target = '_blank';
      anchor.style.display = 'none';
      web.document.body!.appendChild(anchor);
      anchor.click();
      web.document.body!.removeChild(anchor);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code sedang didownload...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal download: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.qr_code_rounded,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR Code - Meja ${table.tableNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (table.section != null && table.section!.isNotEmpty)
                  Text(
                    table.section!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            // QR code image
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Image.network(
                _qrImageUrl,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 32, color: AppTheme.errorColor),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat QR Code',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Table label under QR
            Text(
              'Meja ${table.tableNumber}',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan untuk pesan langsung',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 16),

            // URL display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                _selfOrderUrl,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Copy link button
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _selfOrderUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link berhasil disalin'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Salin Link'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        // Download QR image
        FilledButton.icon(
          onPressed: () => _downloadQr(context),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Download'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
