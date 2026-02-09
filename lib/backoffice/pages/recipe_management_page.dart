import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/recipe_provider.dart';
import '../repositories/recipe_repository.dart';

class RecipeManagementPage extends ConsumerStatefulWidget {
  const RecipeManagementPage({super.key});

  @override
  ConsumerState<RecipeManagementPage> createState() =>
      _RecipeManagementPageState();
}

class _RecipeManagementPageState extends ConsumerState<RecipeManagementPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductWithRecipes> _filterProducts(List<ProductWithRecipes> products) {
    if (_searchQuery.isEmpty) return products;
    final query = _searchQuery.toLowerCase();
    return products.where((p) {
      return p.productName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsWithRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Resep'),
      ),
      body: productsAsync.when(
        data: (products) => _buildBody(context, ref, products),
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
            onPressed: () => ref.invalidate(productsWithRecipesProvider),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<ProductWithRecipes> products,
  ) {
    final filtered = _filterProducts(products);

    return Column(
      children: [
        // Search bar
        _buildSearchBar(),
        const Divider(height: 1),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(products.isEmpty)
              : _buildProductList(context, ref, filtered),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Kelola resep dan bahan baku untuk setiap produk',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 16),
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

  Widget _buildEmpty(bool noProducts) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined,
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
                ? 'Tambahkan produk terlebih dahulu di halaman Kelola Produk'
                : 'Coba ubah kata kunci pencarian',
            style:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(
    BuildContext context,
    WidgetRef ref,
    List<ProductWithRecipes> products,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductRecipeCard(
          product: product,
          onAddIngredient: () =>
              _showAddIngredientDialog(context, ref, product),
          onEditItem: (item) =>
              _showEditIngredientDialog(context, ref, item),
          onDeleteItem: (item) =>
              _confirmDeleteItem(context, ref, item),
        );
      },
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  void _showAddIngredientDialog(
    BuildContext context,
    WidgetRef ref,
    ProductWithRecipes product,
  ) {
    showDialog(
      context: context,
      builder: (context) => _RecipeItemFormDialog(
        productId: product.productId,
        productName: product.productName,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(productsWithRecipesProvider),
      ),
    );
  }

  void _showEditIngredientDialog(
    BuildContext context,
    WidgetRef ref,
    RecipeItem item,
  ) {
    showDialog(
      context: context,
      builder: (context) => _RecipeItemFormDialog(
        productId: item.productId,
        productName: item.productName,
        existingItem: item,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () => ref.invalidate(productsWithRecipesProvider),
      ),
    );
  }

  void _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    RecipeItem item,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Bahan'),
        content: Text(
          'Yakin ingin menghapus "${item.ingredientName}" dari resep?',
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
                final repo = ref.read(recipeRepositoryProvider);
                await repo.deleteRecipeItem(item.id);
                ref.invalidate(productsWithRecipesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${item.ingredientName}" berhasil dihapus dari resep',
                      ),
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
// Product recipe card (expandable)
// ═══════════════════════════════════════════════════════════════════════════

class _ProductRecipeCard extends StatefulWidget {
  final ProductWithRecipes product;
  final VoidCallback onAddIngredient;
  final void Function(RecipeItem item) onEditItem;
  final void Function(RecipeItem item) onDeleteItem;

  const _ProductRecipeCard({
    required this.product,
    required this.onAddIngredient,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  @override
  State<_ProductRecipeCard> createState() => _ProductRecipeCardState();
}

class _ProductRecipeCardState extends State<_ProductRecipeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasRecipes = product.recipes.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Product icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.coffee,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Product name
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasRecipes
                              ? '${product.recipes.length} bahan'
                              : 'Belum ada resep',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: hasRecipes
                                ? AppTheme.textTertiary
                                : AppTheme.warningColor,
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
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Total ingredient cost
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Biaya Bahan',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        Text(
                          hasRecipes
                              ? FormatUtils.currency(product.totalCost)
                              : '-',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: hasRecipes
                                ? AppTheme.textSecondary
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Margin
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
                          hasRecipes
                              ? '${product.marginPercent.toStringAsFixed(1)}%'
                              : '-',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: hasRecipes && product.marginPercent > 0
                                ? AppTheme.successColor
                                : hasRecipes
                                    ? AppTheme.errorColor
                                    : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Expand/collapse icon
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded recipe items ───────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            Container(
              color: AppTheme.backgroundColor,
              child: Column(
                children: [
                  // Recipe items table header
                  if (hasRecipes)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 42 + 12), // align with icon
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Bahan',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Jumlah',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Biaya/Unit',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Subtotal',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 80), // action buttons space
                        ],
                      ),
                    ),

                  // Recipe item rows
                  if (hasRecipes)
                    ...product.recipes.map((item) => _RecipeItemRow(
                          item: item,
                          onEdit: () => widget.onEditItem(item),
                          onDelete: () => widget.onDeleteItem(item),
                        )),

                  // Empty state
                  if (!hasRecipes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 36, color: AppTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada resep',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tambahkan bahan baku untuk produk ini',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Total cost row
                  if (hasRecipes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.dividerColor,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 42 + 12),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Total Biaya Bahan',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.currency(product.totalCost),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 80),
                        ],
                      ),
                    ),

                  // Add ingredient button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onAddIngredient,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Bahan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Recipe item row
// ═══════════════════════════════════════════════════════════════════════════

class _RecipeItemRow extends StatelessWidget {
  final RecipeItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeItemRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 42 + 12),
          // Ingredient name + notes
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ingredientName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Text(
                    item.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          // Quantity + unit
          Expanded(
            flex: 2,
            child: Text(
              '${_formatQuantity(item.quantity)} ${item.unit}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          // Cost per unit
          Expanded(
            flex: 2,
            child: Text(
              FormatUtils.currency(item.costPerUnit),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ),

          // Subtotal
          Expanded(
            flex: 2,
            child: Text(
              FormatUtils.currency(item.totalCost),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // Action buttons
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.errorColor),
                  onPressed: onDelete,
                  tooltip: 'Hapus',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Recipe item form dialog (add / edit)
// ═══════════════════════════════════════════════════════════════════════════

class _RecipeItemFormDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final RecipeItem? existingItem;
  final String outletId;
  final VoidCallback onSaved;

  const _RecipeItemFormDialog({
    required this.productId,
    required this.productName,
    this.existingItem,
    required this.outletId,
    required this.onSaved,
  });

  @override
  State<_RecipeItemFormDialog> createState() => _RecipeItemFormDialogState();
}

class _RecipeItemFormDialogState extends State<_RecipeItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _notesController;
  String? _selectedIngredientId;
  bool _saving = false;

  // Ingredients loaded from Supabase
  List<IngredientOption> _ingredients = [];
  bool _loadingIngredients = true;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.existingItem != null
          ? _formatInitialQuantity(widget.existingItem!.quantity)
          : '',
    );
    _unitController = TextEditingController(
      text: widget.existingItem?.unit ?? 'gram',
    );
    _notesController = TextEditingController(
      text: widget.existingItem?.notes ?? '',
    );
    _selectedIngredientId = widget.existingItem?.ingredientId;
    _loadIngredients();
  }

  String _formatInitialQuantity(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  }

  Future<void> _loadIngredients() async {
    try {
      final repo = RecipeRepository();
      final ingredients = await repo.getIngredients(widget.outletId);
      if (mounted) {
        setState(() {
          _ingredients = ingredients;
          _loadingIngredients = false;
          // Auto-fill unit from selected ingredient
          if (_selectedIngredientId != null) {
            final selected = ingredients
                .where((i) => i.id == _selectedIngredientId)
                .toList();
            if (selected.isNotEmpty) {
              _unitController.text = selected.first.unit;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingIngredients = false);
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Bahan' : 'Tambah Bahan'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.coffee,
                        size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.productName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ingredient search autocomplete
              _loadingIngredients
                  ? const LinearProgressIndicator()
                  : _isEditing
                      ? TextFormField(
                          initialValue: _ingredients
                              .where((i) => i.id == _selectedIngredientId)
                              .map((i) => '${i.name} (${i.unit})')
                              .firstOrNull ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Bahan Baku',
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                          enabled: false,
                        )
                      : _IngredientSearchField(
                          ingredients: _ingredients,
                          selectedId: _selectedIngredientId,
                          onSelected: (ingredient) {
                            setState(() {
                              _selectedIngredientId = ingredient.id;
                              _unitController.text = ingredient.unit;
                            });
                          },
                          validator: (_) => _selectedIngredientId == null
                              ? 'Pilih bahan baku'
                              : null,
                        ),
              const SizedBox(height: 12),

              // Quantity + Unit row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Jumlah wajib diisi';
                        }
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Jumlah harus > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        prefixIcon: Icon(Icons.scale),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.notes),
                  hintText: 'Contoh: iris tipis, cincang halus',
                ),
                maxLines: 2,
              ),

              // Cost preview
              if (_selectedIngredientId != null) ...[
                const SizedBox(height: 16),
                _buildCostPreview(),
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

  Widget _buildCostPreview() {
    final selected =
        _ingredients.where((i) => i.id == _selectedIngredientId).toList();
    if (selected.isEmpty) return const SizedBox.shrink();

    final ingredient = selected.first;
    final qtyText = _quantityController.text.trim();
    final qty = double.tryParse(qtyText) ?? 0;
    final recipeUnit = _unitController.text.trim();
    final factor = RecipeItem.unitConversionFactor(
      recipeUnit.isEmpty ? ingredient.unit : recipeUnit,
      ingredient.unit,
    );
    final subtotal = qty * factor * ingredient.costPerUnit;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined,
              size: 18, color: AppTheme.successColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Biaya per unit: ${FormatUtils.currency(ingredient.costPerUnit)}/${ingredient.unit}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            'Subtotal: ${FormatUtils.currency(subtotal)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = RecipeRepository();
      final quantity = double.parse(_quantityController.text.trim());
      final unit = _unitController.text.trim();
      final notes =
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (_isEditing) {
        await repo.updateRecipeItem(
          id: widget.existingItem!.id,
          quantity: quantity,
          unit: unit,
          notes: notes,
        );
      } else {
        await repo.addRecipeItem(
          productId: widget.productId,
          ingredientId: _selectedIngredientId!,
          quantity: quantity,
          unit: unit,
          notes: notes,
        );
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Bahan berhasil diupdate'
                  : 'Bahan berhasil ditambahkan ke resep',
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
// Ingredient Search Field (autocomplete replacement for dropdown)
// ═══════════════════════════════════════════════════════════════════════════

class _IngredientSearchField extends StatefulWidget {
  final List<IngredientOption> ingredients;
  final String? selectedId;
  final void Function(IngredientOption) onSelected;
  final String? Function(String?)? validator;

  const _IngredientSearchField({
    required this.ingredients,
    this.selectedId,
    required this.onSelected,
    this.validator,
  });

  @override
  State<_IngredientSearchField> createState() => _IngredientSearchFieldState();
}

class _IngredientSearchFieldState extends State<_IngredientSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  List<IngredientOption> _filtered = [];
  bool _showSuggestions = false;
  IngredientOption? _selected;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (widget.selectedId != null) {
      final match = widget.ingredients
          .where((i) => i.id == widget.selectedId)
          .toList();
      if (match.isNotEmpty) {
        _selected = match.first;
        _controller = TextEditingController(
            text: '${match.first.name} (${match.first.unit})');
      } else {
        _controller = TextEditingController();
      }
    } else {
      _controller = TextEditingController();
    }
    _filtered = widget.ingredients;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _selected == null) {
        setState(() => _showSuggestions = true);
      }
      if (!_focusNode.hasFocus) {
        // Delay to allow tap on suggestion
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _selected = null;
      _showSuggestions = true;
      if (q.isEmpty) {
        _filtered = widget.ingredients;
      } else {
        _filtered = widget.ingredients
            .where((i) => i.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _selectIngredient(IngredientOption ingredient) {
    setState(() {
      _selected = ingredient;
      _controller.text = '${ingredient.name} (${ingredient.unit})';
      _showSuggestions = false;
    });
    widget.onSelected(ingredient);
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
            labelText: 'Cari Bahan Baku',
            prefixIcon: const Icon(Icons.search),
            hintText: 'Ketik nama bahan...',
            suffixIcon: _selected != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _selected = null;
                        _controller.clear();
                        _filtered = widget.ingredients;
                        _showSuggestions = true;
                      });
                      _focusNode.requestFocus();
                    },
                  )
                : null,
          ),
          onChanged: _onChanged,
          validator: widget.validator,
          onTap: () {
            if (_selected == null) {
              setState(() => _showSuggestions = true);
            }
          },
        ),
        if (_showSuggestions && _selected == null)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: AppTheme.shadowSM,
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Tidak ditemukan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final ingredient = _filtered[index];
                      return InkWell(
                        onTap: () => _selectIngredient(ingredient),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ingredient.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ingredient.unit,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                FormatUtils.currency(ingredient.costPerUnit),
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
      ],
    );
  }
}
