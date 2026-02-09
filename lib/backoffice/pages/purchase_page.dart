import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/purchase.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/inventory_provider.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/inventory_repository.dart';
import '../../core/services/image_upload_service.dart';

class PurchasePage extends ConsumerWidget {
  const PurchasePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchaseListProvider);
    final statsAsync = ref.watch(purchaseStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembelian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(purchaseListProvider);
              ref.invalidate(purchaseStatsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: purchasesAsync.when(
        data: (purchases) {
          final stats = statsAsync.valueOrNull ??
              const PurchaseStats(
                totalAmount: 0,
                kasKasirAmount: 0,
                uangLuarAmount: 0,
                totalTransactions: 0,
              );

          return Column(
            children: [
              // Summary row
              _SummaryRow(stats: stats),
              const Divider(height: 1),
              // Purchase list
              Expanded(
                child: purchases.isEmpty
                    ? _EmptyState(
                        icon: Icons.shopping_bag_outlined,
                        iconColor: AppTheme.textTertiary,
                        title: 'Belum ada pembelian',
                        subtitle:
                            'Catat pembelian harian untuk tracking pengeluaran',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: purchases.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final purchase = purchases[index];
                          return _PurchaseCard(
                            purchase: purchase,
                            onTap: () => _showDetailDialog(
                              context,
                              ref,
                              purchase,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(purchaseListProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Catat Pembelian'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreatePurchaseDialog(
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () {
          ref.invalidate(purchaseListProvider);
          ref.invalidate(purchaseStatsProvider);
          ref.invalidate(ingredientsProvider);
        },
      ),
    );
  }

  void _showDetailDialog(
    BuildContext context,
    WidgetRef ref,
    Purchase purchase,
  ) {
    showDialog(
      context: context,
      builder: (context) => _PurchaseDetailDialog(
        purchase: purchase,
        onDeleted: () {
          ref.invalidate(purchaseListProvider);
          ref.invalidate(purchaseStatsProvider);
          ref.invalidate(ingredientsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final PurchaseStats stats;

  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 8 : 12,
          ),
          color: AppTheme.backgroundColor,
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.shopping_bag_outlined,
                  iconColor: AppTheme.primaryColor,
                  label: 'Total Bulan Ini',
                  value: FormatUtils.currency(stats.totalAmount),
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.point_of_sale,
                  iconColor: AppTheme.successColor,
                  label: 'Dari Kas',
                  value: FormatUtils.currency(stats.kasKasirAmount),
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppTheme.infoColor,
                  label: 'Dari Luar',
                  value: FormatUtils.currency(stats.uangLuarAmount),
                  compact: compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool compact;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: AppTheme.shadowSM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase Card
// ---------------------------------------------------------------------------

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onTap;

  const _PurchaseCard({
    required this.purchase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isKas = purchase.paymentSource == 'kas_kasir';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: AppTheme.shadowSM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: date + supplier | total
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.supplierName.isNotEmpty
                            ? purchase.supplierName
                            : 'Tanpa Supplier',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FormatUtils.date(purchase.purchaseDate),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  FormatUtils.currency(purchase.totalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: PIC + payment badge + receipt icon
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    purchase.picName.isNotEmpty
                        ? purchase.picName
                        : '-',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _PaymentSourceBadge(isKas: isKas),
                if (purchase.receiptImageUrl != null &&
                    purchase.receiptImageUrl!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment Source Badge
// ---------------------------------------------------------------------------

class _PaymentSourceBadge extends StatelessWidget {
  final bool isKas;

  const _PaymentSourceBadge({required this.isKas});

  @override
  Widget build(BuildContext context) {
    final color = isKas ? AppTheme.successColor : AppTheme.infoColor;
    final label = isKas ? 'Kas Kasir' : 'Uang Luar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Purchase Dialog
// ---------------------------------------------------------------------------

class _PurchaseItemEntry {
  String? ingredientId;
  String itemName = '';
  String unit = 'pcs';
  double quantity = 0;
  double unitPrice = 0;
  double get totalPrice => quantity * unitPrice;

  final nameController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _CreatePurchaseDialog extends StatefulWidget {
  final String outletId;
  final VoidCallback onSaved;

  const _CreatePurchaseDialog({
    required this.outletId,
    required this.onSaved,
  });

  @override
  State<_CreatePurchaseDialog> createState() => _CreatePurchaseDialogState();
}

class _CreatePurchaseDialogState extends State<_CreatePurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picController = TextEditingController();
  final _notesController = TextEditingController();
  final _manualSupplierController = TextEditingController();

  String? _selectedSupplierId;
  bool _manualSupplier = false;
  DateTime _purchaseDate = DateTime.now();
  String _paymentSource = 'kas_kasir';
  final List<_PurchaseItemEntry> _items = [];
  bool _saving = false;

  // Image upload
  String? _receiptImageUrl;
  bool _uploadingImage = false;

  // Data from providers
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
      final supplierRepo =
          SupplierRepository();
      final inventoryRepo =
          InventoryRepository();
      final suppliers = await supplierRepo.getSuppliers(widget.outletId);
      final ingredients =
          await inventoryRepo.getIngredients(widget.outletId);
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
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _picController.dispose();
    _notesController.dispose();
    _manualSupplierController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  void _addItem() {
    setState(() {
      _items.add(_PurchaseItemEntry());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _pickReceiptImage() async {
    setState(() => _uploadingImage = true);

    try {
      final pickedFile = await ImageUploadService.pickImage();
      if (pickedFile == null) {
        setState(() => _uploadingImage = false);
        return;
      }

      // Upload to 'purchase-receipts' bucket using Supabase Storage
      final supabase = Supabase.instance.client;
      final ext = pickedFile.name.contains('.')
          ? pickedFile.name.split('.').last.toLowerCase()
          : 'jpg';
      final storagePath =
          'receipts/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage
          .from('purchase-receipts')
          .uploadBinary(
            storagePath,
            pickedFile.bytes,
            fileOptions: FileOptions(
              contentType: pickedFile.mimeType,
              upsert: true,
            ),
          );

      final publicUrl = supabase.storage
          .from('purchase-receipts')
          .getPublicUrl(storagePath);

      if (mounted) {
        setState(() {
          _receiptImageUrl = publicUrl;
          _uploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload nota: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 700 ? 600.0 : screenWidth * 0.95;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
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
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Catat Pembelian',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Supplier (search + manual unified) ---
                              _SupplierSearchField(
                                suppliers: _suppliers,
                                selectedId: _selectedSupplierId,
                                controller: _manualSupplierController,
                                onSelected: (supplier) {
                                  setState(() {
                                    _selectedSupplierId = supplier.id;
                                    _manualSupplier = false;
                                    // Don't clear — field already shows supplier.name
                                  });
                                },
                                onManualEntry: (name) {
                                  setState(() {
                                    _selectedSupplierId = null;
                                    _manualSupplier = true;
                                    // Controller already has the text
                                  });
                                },
                              ),
                              const SizedBox(height: 12),

                              // --- PIC + Date row ---
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _picController,
                                      decoration: const InputDecoration(
                                        labelText: 'PIC (Penanggung Jawab)',
                                        prefixIcon: Icon(Icons.person),
                                        hintText: 'Nama yang beli...',
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'PIC wajib diisi'
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _pickDate,
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal',
                                          prefixIcon:
                                              Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          FormatUtils.date(_purchaseDate),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // --- Payment Source ---
                              Text(
                                'Sumber Uang',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PaymentSourceOption(
                                      icon: Icons.point_of_sale,
                                      label: 'Kas Kasir',
                                      isSelected:
                                          _paymentSource == 'kas_kasir',
                                      color: AppTheme.successColor,
                                      onTap: () => setState(
                                        () => _paymentSource = 'kas_kasir',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _PaymentSourceOption(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      label: 'Uang Luar',
                                      isSelected:
                                          _paymentSource == 'uang_luar',
                                      color: AppTheme.infoColor,
                                      onTap: () => setState(
                                        () => _paymentSource = 'uang_luar',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // --- Items header ---
                              Row(
                                children: [
                                  Text(
                                    'Item Pembelian',
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

                              // --- Items list ---
                              if (_items.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 32),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM),
                                    border: Border.all(
                                        color: AppTheme.borderColor),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 40,
                                        color: AppTheme.textTertiary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Belum ada item',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppTheme.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: _addItem,
                                        icon:
                                            const Icon(Icons.add, size: 16),
                                        label:
                                            const Text('Tambah Item'),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...List.generate(_items.length, (index) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: _PurchaseItemRow(
                                      entry: _items[index],
                                      ingredients: _ingredients,
                                      index: index,
                                      onChanged: () => setState(() {}),
                                      onRemove: () => _removeItem(index),
                                    ),
                                  );
                                }),

                              // Running total
                              if (_items.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total (${_items.length} item)',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        FormatUtils.currency(_totalAmount),
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // --- Upload Nota ---
                              Row(
                                children: [
                                  Text(
                                    'Upload Nota',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(opsional)',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_receiptImageUrl != null) ...[
                                Stack(
                                  children: [
                                    Container(
                                      height: 120,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(
                                                AppTheme.radiusM),
                                        border: Border.all(
                                            color: AppTheme.borderColor),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(
                                                AppTheme.radiusM),
                                        child: Image.network(
                                          _receiptImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) =>
                                                  Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                              color:
                                                  AppTheme.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Material(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: () => setState(
                                              () => _receiptImageUrl = null),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                OutlinedButton.icon(
                                  onPressed:
                                      _uploadingImage ? null : _pickReceiptImage,
                                  icon: _uploadingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _uploadingImage
                                        ? 'Mengupload...'
                                        : 'Pilih Foto Nota',
                                  ),
                                ),

                              const SizedBox(height: 12),

                              // --- Notes ---
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Catatan (opsional)',
                                  prefixIcon: Icon(Icons.notes),
                                  hintText: 'Tambahkan catatan...',
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer actions
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Total display
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total:',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              Text(
                                FormatUtils.currency(_totalAmount),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save, size: 18),
                            label: const Text('Simpan Pembelian'),
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
      if (item.itemName.isEmpty && item.ingredientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${i + 1}: Nama item wajib diisi')),
        );
        return;
      }
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Item ${i + 1}: Jumlah harus lebih dari 0')),
        );
        return;
      }
    }

    // Resolve supplier name — always read controller text as fallback
    String supplierName = '';
    String? supplierId;
    if (_selectedSupplierId != null) {
      supplierId = _selectedSupplierId;
      try {
        final supplier = _suppliers.firstWhere(
          (s) => s.id == _selectedSupplierId,
        );
        supplierName = supplier.name;
      } catch (_) {
        // supplier not found in list
      }
    }
    // Fallback: use whatever text is in the supplier field
    if (supplierName.isEmpty) {
      supplierName = _manualSupplierController.text.trim();
    }

    setState(() => _saving = true);

    try {
      final repo = PurchaseRepository();

      final purchase = Purchase(
        id: '', // Will be assigned by DB
        outletId: widget.outletId,
        supplierId: supplierId,
        supplierName: supplierName,
        picName: _picController.text.trim(),
        paymentSource: _paymentSource,
        receiptImageUrl: _receiptImageUrl,
        totalAmount: _totalAmount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        purchaseDate: _purchaseDate,
        createdAt: DateTime.now(),
      );

      final purchaseItems = _items.map((entry) {
        return PurchaseItem(
          id: '', // Will be assigned by DB
          purchaseId: '', // Will be assigned during insert
          ingredientId: entry.ingredientId,
          itemName: entry.itemName,
          quantity: entry.quantity,
          unit: entry.unit,
          unitPrice: entry.unitPrice,
          totalPrice: entry.totalPrice,
        );
      }).toList();

      await repo.createPurchase(purchase, purchaseItems);

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pembelian berhasil disimpan'),
            backgroundColor: AppTheme.successColor,
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

// ---------------------------------------------------------------------------
// Payment Source Option
// ---------------------------------------------------------------------------

class _PaymentSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentSourceOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? color : AppTheme.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase Item Row
// ---------------------------------------------------------------------------

class _PurchaseItemRow extends StatelessWidget {
  final _PurchaseItemEntry entry;
  final List<IngredientModel> ingredients;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _PurchaseItemRow({
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
          // Header row
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

          // Item name: dropdown OR manual input
          Autocomplete<IngredientModel>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return ingredients;
              }
              return ingredients.where((ingredient) {
                return ingredient.name
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            displayStringForOption: (option) =>
                '${option.name} (${option.unit})',
            onSelected: (option) {
              final ingredient = option;
              entry.ingredientId = ingredient.id;
              entry.itemName = ingredient.name;
              entry.unit = ingredient.unit;
              entry.unitPrice = ingredient.costPerUnit;
              entry.priceController.text =
                  ingredient.costPerUnit > 0
                      ? ingredient.costPerUnit.toStringAsFixed(0)
                      : '';
              onChanged();
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              // Sync the autocomplete controller with our entry
              if (controller.text.isEmpty && entry.itemName.isNotEmpty) {
                controller.text = entry.itemName;
              }
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Nama Item / Bahan',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  hintText: 'Ketik nama atau pilih bahan...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) {
                  entry.itemName = v;
                  entry.ingredientId = null;
                  onChanged();
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 350,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final ingredient =
                            options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(
                            ingredient.name,
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${ingredient.unit} - ${FormatUtils.currency(ingredient.costPerUnit)}/unit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          onTap: () => onSelected(ingredient),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Qty, Unit, Price, Subtotal row
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.qtyController,
                  decoration: InputDecoration(
                    labelText: 'Jumlah',
                    suffixText: entry.unit,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (v) {
                    entry.quantity = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Unit price
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.priceController,
                  decoration: const InputDecoration(
                    labelText: 'Harga Satuan',
                    prefixText: 'Rp ',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (v) {
                    entry.unitPrice = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Subtotal (read-only)
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Subtotal',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(
                    FormatUtils.currency(entry.totalPrice),
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
// Purchase Detail Dialog
// ---------------------------------------------------------------------------

class _PurchaseDetailDialog extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onDeleted;

  const _PurchaseDetailDialog({
    required this.purchase,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final isKas = purchase.paymentSource == 'kas_kasir';
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 700 ? 600.0 : screenWidth * 0.95;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.supplierName.isNotEmpty
                              ? purchase.supplierName
                              : 'Tanpa Supplier',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          FormatUtils.date(purchase.purchaseDate),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info rows
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        label: 'PIC',
                        value: purchase.picName.isNotEmpty
                            ? purchase.picName
                            : '-',
                      ),
                      _DetailRow(
                        label: 'Sumber Uang',
                        child: _PaymentSourceBadge(isKas: isKas),
                      ),
                      if (purchase.notes != null &&
                          purchase.notes!.isNotEmpty)
                        _DetailRow(
                          label: 'Catatan',
                          value: purchase.notes!,
                        ),

                      const SizedBox(height: 16),

                      // Items
                      Text(
                        'Item (${purchase.items.length})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Item',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Qty',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Harga',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Total',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Table body
                            if (purchase.items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'Tidak ada item detail',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...purchase.items.map((item) {
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item.itemName,
                                              style: GoogleFonts.inter(
                                                  fontSize: 13),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${FormatUtils.number(item.quantity, decimals: item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              FormatUtils.currency(
                                                  item.unitPrice),
                                              style: GoogleFonts.inter(
                                                  fontSize: 13),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              FormatUtils.currency(
                                                  item.totalPrice),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item != purchase.items.last)
                                      const Divider(height: 1),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Total: ',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            FormatUtils.currency(purchase.totalAmount),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),

                      // Receipt image
                      if (purchase.receiptImageUrl != null &&
                          purchase.receiptImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Foto Nota',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                            border:
                                Border.all(color: AppTheme.borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                            child: Image.network(
                              purchase.receiptImageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stack) =>
                                  Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 40,
                                      color: AppTheme.textTertiary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Gagal memuat gambar',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _confirmDelete(context, purchase),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Purchase purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pembelian'),
        content: Text(
          'Yakin ingin menghapus pembelian dari "${purchase.supplierName.isNotEmpty ? purchase.supplierName : 'Tanpa Supplier'}" senilai ${FormatUtils.currency(purchase.totalAmount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx); // close confirm dialog
              try {
                final repo = PurchaseRepository();
                await repo.deletePurchase(purchase.id);
                onDeleted();
                if (context.mounted) {
                  Navigator.pop(context); // close detail dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Pembelian berhasil dihapus'),
                      backgroundColor: AppTheme.successColor,
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

// ---------------------------------------------------------------------------
// Detail Row Helper
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _DetailRow({
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          if (child != null)
            child!
          else
            Expanded(
              child: Text(
                value ?? '-',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Error: $message',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Supplier Search Field (unified search + manual entry)
// ═══════════════════════════════════════════════════════════════════════════

class _SupplierSearchField extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final String? selectedId;
  final TextEditingController controller;
  final void Function(SupplierModel) onSelected;
  final void Function(String name) onManualEntry;

  const _SupplierSearchField({
    required this.suppliers,
    this.selectedId,
    required this.controller,
    required this.onSelected,
    required this.onManualEntry,
  });

  @override
  State<_SupplierSearchField> createState() => _SupplierSearchFieldState();
}

class _SupplierSearchFieldState extends State<_SupplierSearchField> {
  final FocusNode _focusNode = FocusNode();
  List<SupplierModel> _filtered = [];
  bool _showSuggestions = false;
  bool _hasSelection = false;

  TextEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _filtered = widget.suppliers;

    if (widget.selectedId != null) {
      final match =
          widget.suppliers.where((s) => s.id == widget.selectedId).toList();
      if (match.isNotEmpty) {
        _controller.text = match.first.name;
        _hasSelection = true;
      }
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_hasSelection) {
        setState(() => _showSuggestions = true);
      }
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _showSuggestions = false);
            // If text doesn't match any supplier, treat as manual
            if (!_hasSelection && _controller.text.trim().isNotEmpty) {
              widget.onManualEntry(_controller.text.trim());
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _hasSelection = false;
      _showSuggestions = true;
      if (q.isEmpty) {
        _filtered = widget.suppliers;
      } else {
        _filtered = widget.suppliers
            .where((s) => s.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _selectSupplier(SupplierModel supplier) {
    setState(() {
      _hasSelection = true;
      _controller.text = supplier.name;
      _showSuggestions = false;
    });
    widget.onSelected(supplier);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Supplier',
            prefixIcon: const Icon(Icons.local_shipping),
            hintText: 'Cari atau ketik nama supplier...',
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _hasSelection = false;
                        _controller.clear();
                        _filtered = widget.suppliers;
                        _showSuggestions = true;
                      });
                      widget.onManualEntry('');
                      _focusNode.requestFocus();
                    },
                  )
                : null,
          ),
          onChanged: _onChanged,
          onTap: () {
            if (!_hasSelection) {
              setState(() => _showSuggestions = true);
            }
          },
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Supplier wajib diisi' : null,
        ),
        if (_showSuggestions && !_hasSelection)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: AppTheme.shadowSM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filtered.isNotEmpty)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final supplier = _filtered[index];
                        return InkWell(
                          onTap: () => _selectSupplier(supplier),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    supplier.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (supplier.phone != null)
                                  Text(
                                    supplier.phone!,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_filtered.isEmpty && _controller.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.textTertiary),
                        const SizedBox(width: 8),
                        Text(
                          'Supplier baru: "${_controller.text.trim()}"',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
