import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/modifier_provider.dart';
import '../repositories/modifier_repository.dart';

class ModifierManagementPage extends ConsumerWidget {
  const ModifierManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(boModifierGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Modifier'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showGroupDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Grup'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) => groups.isEmpty
            ? _buildEmpty(context, ref)
            : _buildGroupList(context, ref, groups),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, ref, e),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tune_rounded, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Belum ada modifier',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambah grup modifier untuk variasi produk\n(contoh: ukuran, topping, level pedas)',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showGroupDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Grup Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
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
            onPressed: () => ref.invalidate(boModifierGroupsProvider),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    BuildContext context,
    WidgetRef ref,
    List<BOModifierGroup> groups,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _ModifierGroupCard(
          group: group,
          onEdit: () => _showGroupDialog(context, ref, group: group),
          onDelete: () => _confirmDeleteGroup(context, ref, group),
          onAddOption: () => _showOptionDialog(context, ref, group),
          onEditOption: (option) =>
              _showOptionDialog(context, ref, group, option: option),
          onDeleteOption: (option) =>
              _confirmDeleteOption(context, ref, group, option),
        );
      },
    );
  }

  // ── Group Dialog ────────────────────────────────────────────────────────

  void _showGroupDialog(
    BuildContext context,
    WidgetRef ref, {
    BOModifierGroup? group,
  }) {
    showDialog(
      context: context,
      builder: (context) => _ModifierGroupFormDialog(
        group: group,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(boModifierGroupsProvider),
      ),
    );
  }

  // ── Option Dialog ───────────────────────────────────────────────────────

  void _showOptionDialog(
    BuildContext context,
    WidgetRef ref,
    BOModifierGroup group, {
    BOModifierOption? option,
  }) {
    showDialog(
      context: context,
      builder: (context) => _ModifierOptionFormDialog(
        groupId: group.id,
        option: option,
        existingCount: group.options.length,
        onSaved: () => ref.invalidate(boModifierGroupsProvider),
      ),
    );
  }

  // ── Confirm Delete Group ────────────────────────────────────────────────

  void _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    BOModifierGroup group,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Grup Modifier'),
        content: Text(
          'Yakin ingin menghapus grup "${group.name}"?\n\n'
          'Semua opsi di dalam grup ini dan link ke produk akan ikut terhapus.\n'
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repo = ref.read(boModifierRepositoryProvider);
                await repo.deleteModifierGroup(group.id);
                ref.invalidate(boModifierGroupsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Grup "${group.name}" berhasil dihapus'),
                    ),
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

  // ── Confirm Delete Option ───────────────────────────────────────────────

  void _confirmDeleteOption(
    BuildContext context,
    WidgetRef ref,
    BOModifierGroup group,
    BOModifierOption option,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Opsi'),
        content: Text(
          'Yakin ingin menghapus opsi "${option.name}" dari grup "${group.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repo = ref.read(boModifierRepositoryProvider);
                await repo.deleteModifierOption(option.id);
                ref.invalidate(boModifierGroupsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Opsi "${option.name}" berhasil dihapus'),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// Modifier group card (expandable with options list)
// ═══════════════════════════════════════════════════════════════════════════

class _ModifierGroupCard extends StatelessWidget {
  final BOModifierGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddOption;
  final ValueChanged<BOModifierOption> onEditOption;
  final ValueChanged<BOModifierOption> onDeleteOption;

  const _ModifierGroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onAddOption,
    required this.onEditOption,
    required this.onDeleteOption,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Group header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.04),
              border: Border(
                bottom: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildBadge(
                            group.isRequired ? 'Wajib' : 'Opsional',
                            group.isRequired
                                ? AppTheme.errorColor
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          _buildBadge(
                            group.selectionType == 'multiple'
                                ? 'Multi-pilih'
                                : 'Satu pilihan',
                            AppTheme.infoColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${group.options.length} opsi',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          if (group.minSelections != null ||
                              group.maxSelections != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Min: ${group.minSelections ?? 0}, Max: ${group.maxSelections ?? '-'}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                TextButton.icon(
                  onPressed: onAddOption,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Opsi'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edit Grup',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.errorColor),
                  onPressed: onDelete,
                  tooltip: 'Hapus Grup',
                ),
              ],
            ),
          ),

          // ── Options list ──────────────────────────────────────────
          if (group.options.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Belum ada opsi. Klik "Tambah Opsi" untuk menambahkan.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            )
          else
            ...group.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              final isLast = idx == group.options.length - 1;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: AppTheme.dividerColor,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 52), // indent under group icon
                    // Option name
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: option.isAvailable
                                ? AppTheme.successColor
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            option.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: option.isAvailable
                                  ? AppTheme.textPrimary
                                  : AppTheme.textTertiary,
                            ),
                          ),
                          if (option.isDefault) ...[
                            const SizedBox(width: 8),
                            _buildBadge('Default', AppTheme.successColor),
                          ],
                        ],
                      ),
                    ),

                    // Price adjustment
                    Expanded(
                      flex: 2,
                      child: Text(
                        option.priceAdjustment > 0
                            ? '+${FormatUtils.currency(option.priceAdjustment)}'
                            : option.priceAdjustment < 0
                                ? FormatUtils.currency(option.priceAdjustment)
                                : 'Gratis',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: option.priceAdjustment != 0
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Edit / delete option
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEditOption(option),
                      tooltip: 'Edit Opsi',
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.errorColor),
                      onPressed: () => onDeleteOption(option),
                      tooltip: 'Hapus Opsi',
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Modifier group form dialog (add / edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ModifierGroupFormDialog extends StatefulWidget {
  final BOModifierGroup? group;
  final String outletId;
  final VoidCallback onSaved;

  const _ModifierGroupFormDialog({
    this.group,
    required this.outletId,
    required this.onSaved,
  });

  @override
  State<_ModifierGroupFormDialog> createState() =>
      _ModifierGroupFormDialogState();
}

class _ModifierGroupFormDialogState extends State<_ModifierGroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late bool _isRequired;
  late String _selectionType;
  bool _saving = false;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.group?.name ?? '');
    _minController = TextEditingController(
      text: widget.group?.minSelections?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: widget.group?.maxSelections?.toString() ?? '',
    );
    _isRequired = widget.group?.isRequired ?? false;
    _selectionType = widget.group?.selectionType ?? 'single';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Grup Modifier' : 'Tambah Grup Modifier'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Grup',
                  hintText: 'contoh: Ukuran, Topping, Level Pedas',
                  prefixIcon: Icon(Icons.tune_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nama grup wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),

              // Selection type
              DropdownButtonFormField<String>(
                value: _selectionType,
                decoration: const InputDecoration(
                  labelText: 'Tipe Pilihan',
                  prefixIcon: Icon(Icons.checklist_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'single',
                    child: Text('Satu pilihan (single)'),
                  ),
                  DropdownMenuItem(
                    value: 'multiple',
                    child: Text('Multi-pilih (multiple)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectionType = v);
                },
              ),
              const SizedBox(height: 16),

              // Required toggle
              SwitchListTile(
                title: Text(
                  'Wajib dipilih',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _isRequired
                      ? 'Pelanggan harus memilih minimal 1 opsi'
                      : 'Pelanggan boleh melewati pilihan ini',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                value: _isRequired,
                onChanged: (v) => setState(() => _isRequired = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),

              // Min / Max selections
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      decoration: const InputDecoration(
                        labelText: 'Min Pilihan',
                        hintText: '0',
                        prefixIcon: Icon(Icons.remove_circle_outline),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      decoration: const InputDecoration(
                        labelText: 'Max Pilihan',
                        hintText: 'tak terbatas',
                        prefixIcon: Icon(Icons.add_circle_outline),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
      final repo = BOModifierRepository();
      final name = _nameController.text.trim();
      final minText = _minController.text.trim();
      final maxText = _maxController.text.trim();
      final minSelections =
          minText.isNotEmpty ? int.tryParse(minText) : null;
      final maxSelections =
          maxText.isNotEmpty ? int.tryParse(maxText) : null;

      if (_isEditing) {
        await repo.updateModifierGroup(
          widget.group!.id,
          name: name,
          isRequired: _isRequired,
          minSelections: minSelections,
          maxSelections: maxSelections,
          selectionType: _selectionType,
        );
      } else {
        await repo.createModifierGroup(
          outletId: widget.outletId,
          name: name,
          isRequired: _isRequired,
          minSelections: minSelections,
          maxSelections: maxSelections,
          selectionType: _selectionType,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Grup "$name" berhasil diupdate'
                  : 'Grup "$name" berhasil ditambahkan',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Modifier option form dialog (add / edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ModifierOptionFormDialog extends StatefulWidget {
  final String groupId;
  final BOModifierOption? option;
  final int existingCount;
  final VoidCallback onSaved;

  const _ModifierOptionFormDialog({
    required this.groupId,
    this.option,
    this.existingCount = 0,
    required this.onSaved,
  });

  @override
  State<_ModifierOptionFormDialog> createState() =>
      _ModifierOptionFormDialogState();
}

class _ModifierOptionFormDialogState
    extends State<_ModifierOptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late bool _isDefault;
  bool _saving = false;

  bool get _isEditing => widget.option != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.option?.name ?? '');
    _priceController = TextEditingController(
      text: widget.option != null
          ? widget.option!.priceAdjustment.toStringAsFixed(0)
          : '0',
    );
    _isDefault = widget.option?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Opsi Modifier' : 'Tambah Opsi Modifier'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Opsi',
                  hintText: 'contoh: Large, Extra Cheese, Pedas',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nama opsi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),

              // Price adjustment
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Penyesuaian Harga',
                  hintText: '0 = gratis, positif = tambah harga',
                  prefixIcon: Icon(Icons.payments_outlined),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) {
                      return 'Angka tidak valid';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Default toggle
              SwitchListTile(
                title: Text(
                  'Opsi default',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _isDefault
                      ? 'Opsi ini otomatis terpilih'
                      : 'Pelanggan harus memilih secara manual',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
      final repo = BOModifierRepository();
      final name = _nameController.text.trim();
      final priceText = _priceController.text.trim();
      final priceAdjustment =
          priceText.isEmpty ? 0.0 : double.parse(priceText);

      if (_isEditing) {
        await repo.updateModifierOption(
          widget.option!.id,
          name: name,
          priceAdjustment: priceAdjustment,
          isDefault: _isDefault,
        );
      } else {
        await repo.createModifierOption(
          groupId: widget.groupId,
          name: name,
          priceAdjustment: priceAdjustment,
          isDefault: _isDefault,
          sortOrder: widget.existingCount,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Opsi "$name" berhasil diupdate'
                  : 'Opsi "$name" berhasil ditambahkan',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
