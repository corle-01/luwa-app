import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../repositories/purchase_order_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/inventory_repository.dart';

class PurchaseOrderPage extends ConsumerWidget {
  const PurchaseOrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poAsync = ref.watch(purchaseOrderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Order'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showCreatePODialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Buat PO'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: poAsync.when(
        data: (poList) {
          if (poList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_checkout_rounded, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada Purchase Order',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Buat PO baru untuk memesan bahan baku dari supplier',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreatePODialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Buat PO'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: poList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final po = poList[index];
              return _POCard(
                po: po,
                onTap: () => _showPODetail(context, ref, po.id),
                onDelete: po.status == 'draft'
                    ? () => _confirmDeletePO(context, ref, po)
                    : null,
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
                onPressed: () => ref.invalidate(purchaseOrderListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePODialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreatePODialog(
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(purchaseOrderListProvider),
      ),
    );
  }

  void _showPODetail(BuildContext context, WidgetRef ref, String poId) {
    showDialog(
      context: context,
      builder: (context) => _PODetailDialog(
        poId: poId,
        onUpdated: () {
          ref.invalidate(purchaseOrderListProvider);
          ref.invalidate(purchaseOrderDetailProvider(poId));
        },
      ),
    );
  }

  void _confirmDeletePO(BuildContext context, WidgetRef ref, PurchaseOrderModel po) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Purchase Order'),
        content: Text('Yakin ingin menghapus ${po.poNumber}? Hanya PO dengan status Draft yang bisa dihapus.'),
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
                final repo = ref.read(purchaseOrderRepositoryProvider);
                await repo.deletePO(po.id);
                ref.invalidate(purchaseOrderListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${po.poNumber} berhasil dihapus')),
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

// ---------------------------------------------------------------------------
// PO Card
// ---------------------------------------------------------------------------
class _POCard extends StatelessWidget {
  final PurchaseOrderModel po;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _POCard({
    required this.po,
    required this.onTap,
    this.onDelete,
  });

  Color _statusColor() {
    switch (po.status) {
      case 'draft':
        return const Color(0xFF6B7280);
      case 'ordered':
        return const Color(0xFF2563EB);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'received':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      po.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    po.poNumber,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    FormatUtils.currency(po.totalAmount),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                      onPressed: onDelete,
                      tooltip: 'Hapus',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    po.supplierName ?? '-',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    po.orderDate != null ? FormatUtils.date(po.orderDate!) : '-',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (po.expectedDate != null) ...[
                    const SizedBox(width: 20),
                    Icon(Icons.access_time, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'ETA: ${FormatUtils.date(po.expectedDate!)}',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
                    ),
                  ],
                ],
              ),
              if (po.notes != null && po.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  po.notes!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create PO Dialog
// ---------------------------------------------------------------------------
class _CreatePODialog extends StatefulWidget {
  final String outletId;
  final VoidCallback onSaved;

  const _CreatePODialog({required this.outletId, required this.onSaved});

  @override
  State<_CreatePODialog> createState() => _CreatePODialogState();
}

class _POItemEntry {
  String? ingredientId;
  String ingredientName = '';
  String unit = 'pcs';
  double quantity = 0;
  double unitCost = 0;
  double get totalCost => quantity * unitCost;
}

class _CreatePODialogState extends State<_CreatePODialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _selectedSupplierId;
  DateTime? _expectedDate;
  final List<_POItemEntry> _items = [];
  bool _saving = false;

  List<SupplierModel> _suppliers = [];
  List<IngredientModel> _ingredients = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supplierRepo = SupplierRepository();
      final inventoryRepo = InventoryRepository();
      final suppliers = await supplierRepo.getSuppliers(widget.outletId);
      final ingredients = await inventoryRepo.getIngredients(widget.outletId);
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _ingredients = ingredients;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + item.totalCost);

  void _addItem() {
    setState(() {
      _items.add(_POItemEntry());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _pickExpectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loadingData
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Text(
                            'Buat Purchase Order',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Supplier selection
                      DropdownButtonFormField<String>(
                        value: _selectedSupplierId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Supplier',
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                        items: _suppliers.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedSupplierId = v),
                        validator: (v) => v == null ? 'Pilih supplier' : null,
                      ),
                      const SizedBox(height: 12),

                      // Expected date + notes row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickExpectedDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Tanggal Diharapkan (opsional)',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _expectedDate != null
                                      ? FormatUtils.date(_expectedDate!)
                                      : 'Pilih tanggal',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: _expectedDate != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Catatan (opsional)',
                                prefixIcon: Icon(Icons.notes),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Items header
                      Row(
                        children: [
                          Text(
                            'Item Pemesanan',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Tambah Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Items list
                      Expanded(
                        child: _items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textTertiary),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada item',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _addItem,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Tambah Item'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _POItemRow(
                                    entry: _items[index],
                                    ingredients: _ingredients,
                                    index: index,
                                    onChanged: () => setState(() {}),
                                    onRemove: () => _removeItem(index),
                                  );
                                },
                              ),
                      ),

                      // Total & actions
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Total:',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FormatUtils.currency(_totalAmount),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Simpan PO'),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item')),
      );
      return;
    }

    // Validate items
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.ingredientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${i + 1}: Pilih bahan baku')),
        );
        return;
      }
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${i + 1}: Jumlah harus lebih dari 0')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final repo = PurchaseOrderRepository();
      final items = _items.map((item) => {
        'ingredient_id': item.ingredientId,
        'ingredient_name': item.ingredientName,
        'quantity': item.quantity,
        'unit': item.unit,
        'unit_cost': item.unitCost,
      }).toList();

      await repo.createPurchaseOrder(
        outletId: widget.outletId,
        supplierId: _selectedSupplierId!,
        items: items,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        expectedDate: _expectedDate,
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase Order berhasil dibuat')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PO: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// PO Item Row in create dialog
// ---------------------------------------------------------------------------
class _POItemRow extends StatelessWidget {
  final _POItemEntry entry;
  final List<IngredientModel> ingredients;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _POItemRow({
    required this.entry,
    required this.ingredients,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: AppTheme.errorColor),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                tooltip: 'Hapus item',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Ingredient dropdown
          DropdownButtonFormField<String>(
            value: entry.ingredientId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bahan Baku',
              prefixIcon: Icon(Icons.inventory_2_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: ingredients.map((i) {
              return DropdownMenuItem(
                value: i.id,
                child: Text('${i.name} (${i.unit})'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                final ingredient = ingredients.firstWhere((i) => i.id == v);
                entry.ingredientId = v;
                entry.ingredientName = ingredient.name;
                entry.unit = ingredient.unit;
                entry.unitCost = ingredient.costPerUnit;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: entry.quantity > 0 ? entry.quantity.toString() : '',
                  decoration: InputDecoration(
                    labelText: 'Jumlah',
                    suffixText: entry.unit,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    entry.quantity = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Unit cost
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: entry.unitCost > 0 ? entry.unitCost.toStringAsFixed(0) : '',
                  decoration: const InputDecoration(
                    labelText: 'Harga Satuan',
                    prefixText: 'Rp ',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    entry.unitCost = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Total (read-only)
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Subtotal',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(
                    FormatUtils.currency(entry.totalCost),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PO Detail Dialog
// ---------------------------------------------------------------------------
class _PODetailDialog extends ConsumerWidget {
  final String poId;
  final VoidCallback onUpdated;

  const _PODetailDialog({
    required this.poId,
    required this.onUpdated,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return const Color(0xFF6B7280);
      case 'ordered':
        return const Color(0xFF2563EB);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'received':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poAsync = ref.watch(purchaseOrderDetailProvider(poId));

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 650),
        child: poAsync.when(
          data: (po) => _buildContent(context, ref, po),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, PurchaseOrderModel po) {
    final statusColor = _statusColor(po.status);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  po.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                po.poNumber,
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows
          _DetailRow(label: 'Supplier', value: po.supplierName ?? '-'),
          _DetailRow(label: 'Tanggal Order', value: po.orderDate != null ? FormatUtils.date(po.orderDate!) : '-'),
          if (po.expectedDate != null)
            _DetailRow(label: 'Tanggal Diharapkan', value: FormatUtils.date(po.expectedDate!)),
          if (po.receivedDate != null)
            _DetailRow(label: 'Tanggal Diterima', value: FormatUtils.date(po.receivedDate!)),
          if (po.notes != null && po.notes!.isNotEmpty)
            _DetailRow(label: 'Catatan', value: po.notes!),

          const SizedBox(height: 16),
          Text(
            'Item (${po.items.length})',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Items table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('Bahan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Qty', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Harga Satuan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Total', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.right),
                        ),
                        if (po.status == 'received' || po.status == 'partial')
                          Expanded(
                            flex: 2,
                            child: Text('Diterima', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.right),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Table body
                  Expanded(
                    child: ListView.separated(
                      itemCount: po.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = po.items[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.ingredientName,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${FormatUtils.number(item.quantity, decimals: item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  FormatUtils.currency(item.unitCost),
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  FormatUtils.currency(item.totalCost),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              if (po.status == 'received' || po.status == 'partial')
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${FormatUtils.number(item.receivedQuantity, decimals: item.receivedQuantity == item.receivedQuantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: item.receivedQuantity >= item.quantity
                                          ? AppTheme.successColor
                                          : AppTheme.accentColor,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                FormatUtils.currency(po.totalAmount),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (po.status == 'draft') ...[
                OutlinedButton(
                  onPressed: () => _updateStatus(context, ref, po.id, 'cancelled'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                  child: const Text('Batalkan'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _updateStatus(context, ref, po.id, 'ordered'),
                  child: const Text('Kirim Pesanan'),
                ),
              ],
              if (po.status == 'ordered' || po.status == 'partial') ...[
                FilledButton.icon(
                  onPressed: () => _showReceiveDialog(context, ref, po),
                  icon: const Icon(Icons.inventory, size: 18),
                  label: const Text('Terima Barang'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.successColor),
                ),
              ],
              if (po.status == 'cancelled') ...[
                Text(
                  'PO ini telah dibatalkan',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.errorColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (po.status == 'received') ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: AppTheme.successColor),
                    const SizedBox(width: 6),
                    Text(
                      'Semua barang sudah diterima',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      final repo = ref.read(purchaseOrderRepositoryProvider);
      await repo.updatePOStatus(id, status);
      onUpdated();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status PO berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showReceiveDialog(BuildContext context, WidgetRef ref, PurchaseOrderModel po) {
    Navigator.pop(context); // Close detail dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReceivePODialog(
        po: po,
        outletId: ref.read(currentOutletIdProvider),
        onReceived: onUpdated,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row helper
// ---------------------------------------------------------------------------
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Receive PO Dialog
// ---------------------------------------------------------------------------
class _ReceivePODialog extends StatefulWidget {
  final PurchaseOrderModel po;
  final String outletId;
  final VoidCallback onReceived;

  const _ReceivePODialog({
    required this.po,
    required this.outletId,
    required this.onReceived,
  });

  @override
  State<_ReceivePODialog> createState() => _ReceivePODialogState();
}

class _ReceivePODialogState extends State<_ReceivePODialog> {
  late final List<TextEditingController> _qtyControllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyControllers = widget.po.items.map((item) {
      // Pre-fill with ordered quantity (minus already received)
      final remaining = item.quantity - item.receivedQuantity;
      return TextEditingController(text: remaining > 0 ? remaining.toString() : '0');
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _qtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 550),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Terima Barang - ${widget.po.poNumber}',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan jumlah barang yang diterima untuk setiap item.',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),

              // Items
              Expanded(
                child: ListView.separated(
                  itemCount: widget.po.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = widget.po.items[index];
                    final remaining = item.quantity - item.receivedQuantity;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.ingredientName,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dipesan: ${FormatUtils.number(item.quantity, decimals: 1)} ${item.unit}  |  Sudah diterima: ${FormatUtils.number(item.receivedQuantity, decimals: 1)} ${item.unit}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                                ),
                                if (remaining > 0)
                                  Text(
                                    'Sisa: ${FormatUtils.number(remaining, decimals: 1)} ${item.unit}',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.accentColor),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: _qtyControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Diterima',
                                suffixText: item.unit,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _receive,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Konfirmasi Penerimaan'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.successColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _receive() async {
    setState(() => _saving = true);

    try {
      final receivedItems = <Map<String, dynamic>>[];
      for (int i = 0; i < widget.po.items.length; i++) {
        final item = widget.po.items[i];
        final receivedQty = double.tryParse(_qtyControllers[i].text) ?? 0;
        receivedItems.add({
          'id': item.id,
          'ingredient_id': item.ingredientId,
          'received_quantity': item.receivedQuantity + receivedQty,
        });
      }

      final repo = PurchaseOrderRepository();
      await repo.receivePO(widget.po.id, widget.outletId, receivedItems);

      widget.onReceived();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang berhasil diterima dan stok diperbarui')),
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
