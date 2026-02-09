import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/product_image.dart';
import '../../core/services/image_upload_service.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/product_provider.dart';
import '../providers/modifier_provider.dart';
import '../repositories/product_repository.dart';
import '../repositories/modifier_repository.dart';

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
          if (MediaQuery.of(context).size.width > 600) ...[
            OutlinedButton.icon(
              onPressed: () => _showManageCategoriesDialog(context, ref),
              icon: const Icon(Icons.category, size: 18),
              label: const Text('Kelola Kategori'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showProductDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Produk'),
            ),
          ] else ...[
            IconButton(
              onPressed: () => _showManageCategoriesDialog(context, ref),
              icon: const Icon(Icons.category, size: 20),
              tooltip: 'Kelola Kategori',
            ),
            IconButton(
              onPressed: () => _showProductDialog(context, ref),
              icon: const Icon(Icons.add_circle, size: 20),
              tooltip: 'Tambah Produk',
            ),
          ],
          const SizedBox(width: 8),
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
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      // Mobile: stack search on top, categories below
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppTheme.surfaceColor,
        child: Column(
          children: [
            // Search field (full width)
            TextField(
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
            const SizedBox(height: 8),
            // Category chips (horizontal scroll)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(
                    label: 'Semua',
                    isSelected: _selectedCategoryId == null,
                    onTap: () => setState(() => _selectedCategoryId = null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          label: cat.name,
                          color: _parseColor(cat.color),
                          isSelected: _selectedCategoryId == cat.id,
                          onTap: () => setState(() => _selectedCategoryId = cat.id),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
          onDelete: () => _confirmDelete(context, ref, product),
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
        outletId: ref.read(currentOutletIdProvider),
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
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () {
          ref.invalidate(boCategoriesProvider);
          ref.invalidate(boProductsProvider);
        },
      ),
    );
  }

  void _showManageCategoriesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _ManageCategoriesDialog(
        outletId: ref.read(currentOutletIdProvider),
        onChanged: () {
          ref.invalidate(boCategoriesProvider);
          ref.invalidate(boProductsProvider);
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text(
          'Yakin ingin menghapus "${product.name}"?\n\nTindakan ini tidak bisa dibatalkan.',
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
                final repo = ref.read(productRepositoryProvider);
                await repo.deleteProduct(product.id);
                ref.invalidate(boProductsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${product.name}" berhasil dihapus'),
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
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  Widget _buildProductImage(bool isActive) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : AppTheme.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: product.primaryImageUrl != null &&
              product.primaryImageUrl!.isNotEmpty
          ? Image.network(
              product.primaryImageUrl!,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) => Icon(
                Icons.coffee,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
                size: 24,
              ),
            )
          : Icon(
              Icons.coffee,
              color: isActive
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary,
              size: 24,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = product.isActive;
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return _buildMobileCard(isActive);
    }
    return _buildDesktopCard(isActive);
  }

  /// Mobile: compact 2-line card
  Widget _buildMobileCard(bool isActive) {
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildProductImage(isActive),
              const SizedBox(width: 12),
              // Name + category + price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          product.categoryName ?? 'Tanpa Kategori',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.successColor.withValues(alpha: 0.1)
                                : AppTheme.textTertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Off',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive ? AppTheme.successColor : AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Price + actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.currency(product.sellingPrice),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onToggle,
                        child: Icon(
                          isActive ? Icons.toggle_on : Icons.toggle_off,
                          size: 24,
                          color: isActive ? AppTheme.successColor : AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop: full row with all columns
  Widget _buildDesktopCard(bool isActive) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildProductImage(isActive),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// Product form dialog (add / edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ProductFormDialog extends StatefulWidget {
  final ProductModel? product;
  final String outletId;
  final VoidCallback onSaved;

  const _ProductFormDialog({this.product, required this.outletId, required this.onSaved});

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

  // Product images
  List<ProductImage> _images = [];
  bool _loadingImages = false;
  bool _uploadingImage = false;

  // Modifier assignments
  List<BOModifierGroup> _allModifierGroups = [];
  Set<String> _assignedGroupIds = {};
  bool _loadingModifiers = false;

  // Featured category assignments
  List<CategoryModel> _featuredCategories = [];
  Set<String> _assignedFeaturedIds = {};
  bool _loadingFeatured = false;

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
    _loadModifierGroups();
    _loadFeaturedCategories();

    // Load existing images if editing
    if (_isEditing) {
      _images = List.from(widget.product!.images);
      if (_images.isEmpty) {
        _loadProductImages();
      }
    }
  }

  Future<void> _loadProductImages() async {
    if (!_isEditing) return;
    setState(() => _loadingImages = true);
    try {
      final repo = ProductRepository();
      final imgs = await repo.getProductImages(widget.product!.id);
      if (mounted) {
        setState(() {
          _images = imgs;
          _loadingImages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!_isEditing) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simpan produk terlebih dahulu sebelum menambah gambar'),
          ),
        );
      }
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final picked = await ImageUploadService.pickImage();
      if (picked == null) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }

      // Upload to Supabase Storage
      final publicUrl = await ImageUploadService.uploadImage(
        productId: widget.product!.id,
        bytes: picked.bytes,
        fileName: picked.name,
        mimeType: picked.mimeType,
      );

      // Save to product_images table
      final repo = ProductRepository();
      final isPrimary = _images.isEmpty; // First image is automatically primary
      final newImage = await repo.addProductImage(
        productId: widget.product!.id,
        imageUrl: publicUrl,
        sortOrder: _images.length,
        isPrimary: isPrimary,
      );

      if (mounted) {
        setState(() {
          _images.add(newImage);
          _uploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload gambar: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(ProductImage image) async {
    try {
      // Delete from storage
      await ImageUploadService.deleteImage(image.imageUrl);
      // Delete from DB
      final repo = ProductRepository();
      await repo.deleteProductImage(image.id);

      if (mounted) {
        setState(() {
          _images.removeWhere((i) => i.id == image.id);
          // If we deleted the primary, set the first remaining as primary
          if (image.isPrimary && _images.isNotEmpty) {
            _images[0] = _images[0].copyWith(isPrimary: true);
            repo.setPrimaryImage(
              productId: widget.product!.id,
              imageId: _images[0].id,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus gambar: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _setPrimary(ProductImage image) async {
    try {
      final repo = ProductRepository();
      await repo.setPrimaryImage(
        productId: widget.product!.id,
        imageId: image.id,
      );
      if (mounted) {
        setState(() {
          _images = _images.map((i) {
            return i.copyWith(isPrimary: i.id == image.id);
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal set gambar utama: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _moveImage(int oldIndex, int newIndex) async {
    if (newIndex < 0 || newIndex >= _images.length) return;
    setState(() {
      final image = _images.removeAt(oldIndex);
      _images.insert(newIndex, image);
    });
    // Persist new sort order
    try {
      final repo = ProductRepository();
      await repo.reorderImages(_images.map((i) => i.id).toList());
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ProductRepository();
      final cats = await repo.getCategories(widget.outletId);
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

  Future<void> _loadModifierGroups() async {
    setState(() => _loadingModifiers = true);
    try {
      final modRepo = BOModifierRepository();
      final groups = await modRepo.getModifierGroups(widget.outletId);
      Set<String> assigned = {};
      if (_isEditing) {
        final assignments =
            await modRepo.getProductModifiers(widget.product!.id);
        assigned = assignments.map((a) => a.modifierGroupId).toSet();
      }
      if (mounted) {
        setState(() {
          _allModifierGroups = groups;
          _assignedGroupIds = assigned;
          _loadingModifiers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingModifiers = false);
    }
  }

  Future<void> _loadFeaturedCategories() async {
    setState(() => _loadingFeatured = true);
    try {
      final repo = ProductRepository();
      final allCats = await repo.getCategories(widget.outletId);
      final featured = allCats.where((c) => c.isFeatured).toList();

      Set<String> assigned = {};
      if (_isEditing) {
        final supabase = Supabase.instance.client;
        final res = await supabase
            .from('product_featured_categories')
            .select('featured_category_id')
            .eq('product_id', widget.product!.id);
        assigned = (res as List)
            .map((r) => r['featured_category_id'] as String)
            .toSet();
      }

      if (mounted) {
        setState(() {
          _featuredCategories = featured;
          _assignedFeaturedIds = assigned;
          _loadingFeatured = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFeatured = false);
    }
  }

  Future<void> _toggleFeaturedCategory(String categoryId, bool assign) async {
    if (!_isEditing) return;
    try {
      final supabase = Supabase.instance.client;
      if (assign) {
        await supabase.from('product_featured_categories').insert({
          'product_id': widget.product!.id,
          'featured_category_id': categoryId,
        });
      } else {
        await supabase
            .from('product_featured_categories')
            .delete()
            .eq('product_id', widget.product!.id)
            .eq('featured_category_id', categoryId);
      }
      setState(() {
        if (assign) {
          _assignedFeaturedIds.add(categoryId);
        } else {
          _assignedFeaturedIds.remove(categoryId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.errorColor),
        );
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
        width: 500,
        child: SingleChildScrollView(
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

              // Category dropdown (exclude featured — those are tags, not primary)
              _loadingCategories
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori Utama',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tanpa Kategori'),
                        ),
                        ..._categories
                            .where((c) => !c.isFeatured)
                            .map(
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

              // ── Featured categories section ──────────────
              if (_featuredCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 20, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Kategori Khusus',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (!_isEditing)
                      Text(
                        'Simpan produk dulu',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Produk akan muncul di tab ini selain kategori utamanya',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingFeatured)
                  const LinearProgressIndicator()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _featuredCategories.map((cat) {
                      final isAssigned = _assignedFeaturedIds.contains(cat.id);
                      return FilterChip(
                        selected: isAssigned,
                        onSelected: _isEditing
                            ? (v) => _toggleFeaturedCategory(cat.id, v)
                            : null,
                        label: Text(cat.name),
                        avatar: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: isAssigned
                              ? Colors.white
                              : AppTheme.accentColor,
                        ),
                        selectedColor: AppTheme.accentColor,
                        checkmarkColor: Colors.white,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isAssigned ? Colors.white : AppTheme.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
              ],

              // ── Modifier section ─────────────────────────
              if (_allModifierGroups.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 20, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Modifier',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (!_isEditing)
                      Text(
                        'Simpan produk dulu',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingModifiers)
                  const LinearProgressIndicator()
                else
                  ..._allModifierGroups.map((group) {
                    final isAssigned =
                        _assignedGroupIds.contains(group.id);
                    return CheckboxListTile(
                      value: isAssigned,
                      onChanged: _isEditing
                          ? (v) async {
                              final modRepo = BOModifierRepository();
                              try {
                                if (v == true) {
                                  await modRepo.assignModifierToProduct(
                                    productId: widget.product!.id,
                                    groupId: group.id,
                                  );
                                } else {
                                  await modRepo
                                      .removeModifierFromProduct(
                                    productId: widget.product!.id,
                                    groupId: group.id,
                                  );
                                }
                                setState(() {
                                  if (v == true) {
                                    _assignedGroupIds.add(group.id);
                                  } else {
                                    _assignedGroupIds
                                        .remove(group.id);
                                  }
                                });
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Gagal: $e'),
                                      backgroundColor:
                                          AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      title: Text(
                        group.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${group.options.length} opsi${group.isRequired ? ' (wajib)' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity:
                          ListTileControlAffinity.leading,
                    );
                  }),
              ],

              // ── Product Images section ──────────────────────
              if (_isEditing) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 20, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Gambar Produk',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_uploadingImage)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _pickAndUploadImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: const Text('Tambah'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingImages)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_images.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.image_outlined,
                              size: 32, color: AppTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada gambar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 110,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        _moveImage(oldIndex, newIndex);
                      },
                      buildDefaultDragHandles: true,
                      itemBuilder: (context, index) {
                        final img = _images[index];
                        return _ImageThumbnail(
                          key: ValueKey(img.id),
                          image: img,
                          onDelete: () => _deleteImage(img),
                          onSetPrimary: () => _setPrimary(img),
                        );
                      },
                    ),
                  ),
              ],
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
          outletId: widget.outletId,
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
// Image thumbnail widget (used in product form)
// ═══════════════════════════════════════════════════════════════════════════

class _ImageThumbnail extends StatelessWidget {
  final ProductImage image;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

  const _ImageThumbnail({
    super.key,
    required this.image,
    required this.onDelete,
    required this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          // Image with overlay controls
          Expanded(
            child: Stack(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    image.imageUrl,
                    fit: BoxFit.cover,
                    width: 100,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppTheme.textTertiary, size: 24),
                      ),
                    ),
                  ),
                ),
                // Primary badge
                if (image.isPrimary)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Utama',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Delete button
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Set as primary button
          if (!image.isPrimary)
            GestureDetector(
              onTap: onSetPrimary,
              child: Text(
                'Set Utama',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          else
            Text(
              'Gambar Utama',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.successColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Category form dialog
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryFormDialog extends StatefulWidget {
  final String outletId;
  final VoidCallback onSaved;

  const _CategoryFormDialog({required this.outletId, required this.onSaved});

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
        outletId: widget.outletId,
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

// ═══════════════════════════════════════════════════════════════════════════
// Manage categories dialog (list, add, edit, delete)
// ═══════════════════════════════════════════════════════════════════════════

class _ManageCategoriesDialog extends StatefulWidget {
  final String outletId;
  final VoidCallback onChanged;

  const _ManageCategoriesDialog({required this.outletId, required this.onChanged});

  @override
  State<_ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<_ManageCategoriesDialog> {
  final _repo = ProductRepository();
  List<CategoryModel> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getCategories(widget.outletId);
      if (mounted) setState(() { _categories = cats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppTheme.primaryColor;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kelola Kategori'),
      content: SizedBox(
        width: 450,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada kategori',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _hexToColor(cat.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(cat.name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit',
                              onPressed: () => _editCategory(cat),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 20, color: AppTheme.errorColor),
                              tooltip: 'Hapus',
                              onPressed: () => _deleteCategory(cat),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            // Open add category dialog (reuse existing)
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (_) => _CategoryFormDialog(
                  outletId: widget.outletId,
                  onSaved: () {
                    widget.onChanged();
                  },
                ),
              );
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah Kategori'),
        ),
      ],
    );
  }

  void _editCategory(CategoryModel cat) {
    final nameController = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Kategori'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            prefixIcon: Icon(Icons.category),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repo.updateCategory(cat.id, name: newName);
                widget.onChanged();
                await _loadCategories();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kategori berhasil diupdate')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text(
          'Yakin ingin menghapus kategori "${cat.name}"?\n\n'
          'Produk yang menggunakan kategori ini akan menjadi "Tanpa Kategori".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repo.deleteCategory(cat.id);
                widget.onChanged();
                await _loadCategories();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kategori "${cat.name}" berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal: $e'),
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
