import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../providers/product_provider.dart';
import '../repositories/product_repository.dart';

const _outletId = 'a0000000-0000-0000-0000-000000000001';

class ProductManagementPage extends ConsumerStatefulWidget {
  const ProductManagementPage({super.key});

  @override
  ConsumerState<ProductManagementPage> createState() =>
      _ProductManagementPageState();
}

class _ProductManagementPageState extends ConsumerState<ProductManagementPage> {
  String? _selectedCategoryId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> _filterProducts(
    List<ProductModel> products,
    List<CategoryModel> categories,
  ) {
    var filtered = products;

    // Filter by category
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.description?.toLowerCase().contains(query) ?? false) ||
            (p.categoryName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(boProductsProvider);
    final categoriesAsync = ref.watch(boCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Produk'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showCategoryDialog(context, ref),
            icon: const Icon(Icons.category, size: 18),
            label: const Text('Tambah Kategori'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showProductDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Produk'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: productsAsync.when(
        data: (products) => categoriesAsync.when(
          data: (categories) =>
              _buildBody(context, ref, products, categories),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, ref, e),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, ref, e),
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
            onPressed: () {
              ref.invalidate(boProductsProvider);
              ref.invalidate(boCategoriesProvider);
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<ProductModel> products,
    List<CategoryModel> categories,
  ) {
    final filtered = _filterProducts(products, categories);

    return Column(
      children: [
        // ── Filter row ──────────────────────────────────────────────
        _buildFilterRow(categories),
        const Divider(height: 1),

        // ── Product list ────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(context, ref, products.isEmpty)
              : _buildProductList(context, ref, filtered, categories),
        ),
      ],
    );
  }

  Widget _buildFilterRow(List<CategoryModel> categories) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          // Category chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'Semua',
                    isSelected: _selectedCategoryId == null,
                    onTap: () =>
                        setState(() => _selectedCategoryId = null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          label: cat.name,
                          color: _parseColor(cat.color),
                          isSelected: _selectedCategoryId == cat.id,
                          onTap: () =>
                              setState(() => _selectedCategoryId = cat.id),
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Search field
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref, bool noProducts) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            noProducts ? 'Belum ada produk' : 'Tidak ada produk ditemukan',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noProducts
                ? 'Tambah produk pertama untuk mulai berjualan'
                : 'Coba ubah filter atau kata kunci pencarian',
            style:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
          ),
          if (noProducts) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showProductDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Produk'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductList(
    BuildContext context,
    WidgetRef ref,
    List<ProductModel> products,
    List<CategoryModel> categories,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(
          product: product,
          onEdit: () =>
              _showProductDialog(context, ref, product: product),
          onToggle: () => _confirmToggle(context, ref, product),
        );
      },
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  void _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    ProductModel? product,
  }) {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        product: product,
        onSaved: () {
          ref.invalidate(boProductsProvider);
          ref.invalidate(boCategoriesProvider);
        },
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        onSaved: () {
          ref.invalidate(boCategoriesProvider);
          ref.invalidate(boProductsProvider);
        },
      ),
    );
  }

  void _confirmToggle(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
  ) {
    final newState = !product.isActive;
    final action = newState ? 'mengaktifkan' : 'menonaktifkan';
    final actionLabel = newState ? 'Aktifkan' : 'Nonaktifkan';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionLabel Produk'),
        content: Text('Yakin ingin $action "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  newState ? AppTheme.successColor : AppTheme.warningColor,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repo = ref.read(productRepositoryProvider);
                await repo.toggleProduct(product.id, newState);
                ref.invalidate(boProductsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${product.name}" berhasil di${newState ? 'aktifkan' : 'nonaktifkan'}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// Parse a hex color string (e.g. "#FF5733") into a [Color].
  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Category filter chip
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;

    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: chipColor,
      backgroundColor: AppTheme.backgroundColor,
      side: BorderSide(
        color: isSelected ? chipColor : AppTheme.borderColor,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Product card
// ═══════════════════════════════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = product.isActive;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Product icon / image placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : AppTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.coffee,
                color: isActive ? AppTheme.primaryColor : AppTheme.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Name + category
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isActive
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.categoryName ?? 'Tanpa Kategori',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Selling price
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Harga Jual',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Text(
                    FormatUtils.currency(product.sellingPrice),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isActive
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Cost price
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Harga Modal',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Text(
                    FormatUtils.currency(product.costPrice),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isActive
                          ? AppTheme.textSecondary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Margin %
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Margin',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Text(
                    '${product.marginPercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: product.marginPercent > 0
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Aktif' : 'Nonaktif',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppTheme.successColor : AppTheme.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Actions
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(
                isActive ? Icons.toggle_on : Icons.toggle_off,
                size: 28,
                color: isActive ? AppTheme.successColor : AppTheme.textTertiary,
              ),
              onPressed: onToggle,
              tooltip: isActive ? 'Nonaktifkan' : 'Aktifkan',
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Product form dialog (add / edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ProductFormDialog extends StatefulWidget {
  final ProductModel? product;
  final VoidCallback onSaved;

  const _ProductFormDialog({this.product, required this.onSaved});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _descriptionController;
  String? _selectedCategoryId;
  bool _saving = false;

  // Categories loaded from Supabase
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.product?.name ?? '');
    _sellingPriceController = TextEditingController(
      text: widget.product != null
          ? widget.product!.sellingPrice.toStringAsFixed(0)
          : '',
    );
    _costPriceController = TextEditingController(
      text: widget.product != null
          ? widget.product!.costPrice.toStringAsFixed(0)
          : '',
    );
    _descriptionController =
        TextEditingController(text: widget.product?.description ?? '');
    _selectedCategoryId = widget.product?.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ProductRepository();
      final cats = await repo.getCategories(_outletId);
      if (mounted) {
        setState(() {
          _categories = cats;
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Produk' : 'Tambah Produk Baru'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk',
                  prefixIcon: Icon(Icons.local_cafe),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama produk wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // Category dropdown
              _loadingCategories
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tanpa Kategori'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCategoryId = v),
                    ),
              const SizedBox(height: 12),

              // Selling price
              TextFormField(
                controller: _sellingPriceController,
                decoration: const InputDecoration(
                  labelText: 'Harga Jual',
                  prefixIcon: Icon(Icons.sell),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Harga jual wajib diisi';
                  }
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Harga jual harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Cost price
              TextFormField(
                controller: _costPriceController,
                decoration: const InputDecoration(
                  labelText: 'Harga Modal',
                  prefixIcon: Icon(Icons.payments_outlined),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Harga modal tidak valid';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
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
      final repo = ProductRepository();
      final name = _nameController.text.trim();
      final sellingPrice =
          double.parse(_sellingPriceController.text.trim());
      final costPriceText = _costPriceController.text.trim();
      final costPrice =
          costPriceText.isEmpty ? 0.0 : double.parse(costPriceText);
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      if (_isEditing) {
        await repo.updateProduct(
          widget.product!.id,
          name: name,
          categoryId: _selectedCategoryId,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          description: description,
        );
      } else {
        await repo.createProduct(
          outletId: _outletId,
          name: name,
          categoryId: _selectedCategoryId,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          description: description,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? '"$name" berhasil diupdate'
                  : '"$name" berhasil ditambahkan',
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
// Category form dialog
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryFormDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const _CategoryFormDialog({required this.onSaved});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedColor;
  bool _saving = false;

  static const _presetColors = [
    ('Merah', '#EF4444'),
    ('Oranye', '#F59E0B'),
    ('Hijau', '#10B981'),
    ('Biru', '#3B82F6'),
    ('Ungu', '#8B5CF6'),
    ('Pink', '#EC4899'),
    ('Abu-abu', '#6B7280'),
    ('Indigo', '#6366F1'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Kategori Baru'),
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
                  labelText: 'Nama Kategori',
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nama kategori wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),

              // Color picker (preset)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Warna',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetColors.map((preset) {
                  final isSelected = _selectedColor == preset.$2;
                  return Tooltip(
                    message: preset.$1,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColor = preset.$2),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _hexToColor(preset.$2),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.textPrimary, width: 3)
                              : Border.all(
                                  color: AppTheme.borderColor, width: 1),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
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
              : const Text('Tambah'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = ProductRepository();
      await repo.createCategory(
        outletId: _outletId,
        name: _nameController.text.trim(),
        color: _selectedColor,
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kategori "${_nameController.text.trim()}" berhasil ditambahkan',
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
