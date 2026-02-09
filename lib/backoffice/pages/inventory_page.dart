import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/product_stock_provider.dart';
import '../repositories/inventory_repository.dart';
import 'product_stock_page.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final movementsAsync = ref.watch(stockMovementsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventori & Stok'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(ingredientsProvider);
                ref.invalidate(stockMovementsProvider);
                ref.invalidate(productStockListProvider);
                ref.invalidate(allProductStockMovementsProvider);
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Semua Bahan'),
              Tab(text: 'Stok Rendah'),
              Tab(text: 'Riwayat'),
              Tab(text: 'Produk Jadi'),
            ],
          ),
        ),
        body: ingredientsAsync.when(
          data: (ingredients) {
            final lowStockItems = ingredients
                .where((i) => i.isLowStock || i.isOutOfStock)
                .toList();
            final totalStockValue = ingredients.fold<double>(
              0,
              (sum, i) => sum + i.stockValue,
            );

            return Column(
              children: [
                // Summary cards
                _SummaryRow(
                  totalIngredients: ingredients.length,
                  lowStockCount: lowStockItems.length,
                  totalStockValue: totalStockValue,
                ),
                const Divider(height: 1),
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Semua Bahan
                      _IngredientsTable(
                        ingredients: ingredients,
                        ref: ref,
                      ),
                      // Tab 2: Stok Rendah
                      lowStockItems.isEmpty
                          ? _EmptyState(
                              icon: Icons.check_circle_outline,
                              iconColor: AppTheme.successColor,
                              title: 'Semua stok aman',
                              subtitle:
                                  'Tidak ada bahan dengan stok rendah saat ini',
                            )
                          : _IngredientsTable(
                              ingredients: lowStockItems,
                              ref: ref,
                            ),
                      // Tab 3: Riwayat
                      movementsAsync.when(
                        data: (movements) {
                          if (movements.isEmpty) {
                            return _EmptyState(
                              icon: Icons.history,
                              iconColor: AppTheme.textTertiary,
                              title: 'Belum ada riwayat',
                              subtitle:
                                  'Riwayat pergerakan stok akan muncul di sini',
                            );
                          }
                          return _MovementsList(movements: movements);
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => _ErrorState(
                          message: e.toString(),
                          onRetry: () =>
                              ref.invalidate(stockMovementsProvider),
                        ),
                      ),
                      // Tab 4: Produk Jadi (embedded)
                      const ProductStockContent(),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(ingredientsProvider),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final int totalIngredients;
  final int lowStockCount;
  final double totalStockValue;

  const _SummaryRow({
    required this.totalIngredients,
    required this.lowStockCount,
    required this.totalStockValue,
  });

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
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppTheme.primaryColor,
                  label: 'Total Bahan',
                  value: totalIngredients.toString(),
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: lowStockCount > 0
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                  label: 'Stok Rendah',
                  value: lowStockCount.toString(),
                  badgeColor:
                      lowStockCount > 0 ? AppTheme.errorColor : null,
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppTheme.accentColor,
                  label: 'Nilai Stok',
                  value: FormatUtils.currency(totalStockValue),
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
  final Color? badgeColor;
  final bool compact;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.badgeColor,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeColor != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeColor != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
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
// Ingredients Table
// ---------------------------------------------------------------------------

class _IngredientsTable extends StatelessWidget {
  final List<IngredientModel> ingredients;
  final WidgetRef ref;

  const _IngredientsTable({
    required this.ingredients,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return _EmptyState(
        icon: Icons.inventory_2_outlined,
        iconColor: AppTheme.textTertiary,
        title: 'Belum ada bahan',
        subtitle: 'Tambah bahan baku untuk mulai mengelola inventori',
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: ingredients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ingredient = ingredients[index];
          return _buildMobileCard(context, ingredient);
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ),
          headingTextStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
          dataTextStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textPrimary,
          ),
          border: TableBorder(
            horizontalInside: BorderSide(
              color: AppTheme.dividerColor,
              width: 0.5,
            ),
          ),
          columns: const [
            DataColumn(label: Text('Nama')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Harga/Unit'), numeric: true),
            DataColumn(label: Text('Stok'), numeric: true),
            DataColumn(label: Text('Min'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: ingredients.map((ingredient) {
            return DataRow(
              cells: [
                // Nama
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      if (ingredient.supplierName != null)
                        Text(
                          ingredient.supplierName!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Unit
                DataCell(Text(ingredient.unit)),
                // Harga/Unit
                DataCell(
                  Text(
                    FormatUtils.currency(ingredient.costPerUnit),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: ingredient.costPerUnit > 0
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
                // Stok
                DataCell(
                  Text(
                    FormatUtils.number(ingredient.currentStock,
                        decimals: ingredient.currentStock ==
                                ingredient.currentStock.roundToDouble()
                            ? 0
                            : 2),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: ingredient.isOutOfStock
                          ? AppTheme.errorColor
                          : ingredient.isLowStock
                              ? AppTheme.warningColor
                              : AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Min
                DataCell(
                  Text(
                    FormatUtils.number(ingredient.minStock,
                        decimals: ingredient.minStock ==
                                ingredient.minStock.roundToDouble()
                            ? 0
                            : 2),
                  ),
                ),
                // Status badge
                DataCell(_StatusBadge(ingredient: ingredient)),
                // Aksi
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.tune, size: 20),
                    tooltip: 'Sesuaikan Stok & Harga',
                    onPressed: () => _showAdjustmentDialog(
                      context,
                      ref,
                      ingredient,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, IngredientModel ingredient) {
    final stockDecimals = ingredient.currentStock ==
            ingredient.currentStock.roundToDouble()
        ? 0
        : 2;
    return GestureDetector(
      onTap: () => _showAdjustmentDialog(context, ref, ingredient),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: AppTheme.shadowSM,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ingredient.unit} \u2022 ${FormatUtils.currency(ingredient.costPerUnit)}/${ingredient.unit}${ingredient.supplierName != null ? ' \u2022 ${ingredient.supplierName}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${FormatUtils.number(ingredient.currentStock, decimals: stockDecimals)} ${ingredient.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ingredient.isOutOfStock
                        ? AppTheme.errorColor
                        : ingredient.isLowStock
                            ? AppTheme.warningColor
                            : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusBadge(ingredient: ingredient),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.tune, size: 20, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showAdjustmentDialog(
    BuildContext context,
    WidgetRef ref,
    IngredientModel ingredient,
  ) {
    showDialog(
      context: context,
      builder: (context) => _StockAdjustmentDialog(
        ingredient: ingredient,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () {
          ref.invalidate(ingredientsProvider);
          ref.invalidate(stockMovementsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final IngredientModel ingredient;

  const _StatusBadge({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (ingredient.isOutOfStock) {
      label = 'Habis';
      color = AppTheme.errorColor;
    } else if (ingredient.isLowStock) {
      label = 'Rendah';
      color = AppTheme.warningColor;
    } else {
      label = 'Normal';
      color = AppTheme.successColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
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

// ---------------------------------------------------------------------------
// Movements List (Riwayat)
// ---------------------------------------------------------------------------

class _MovementsList extends StatelessWidget {
  final List<StockMovement> movements;

  const _MovementsList({required this.movements});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final movement = movements[index];
        return _MovementCard(movement: movement);
      },
    );
  }
}

class _MovementCard extends StatelessWidget {
  final StockMovement movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.quantity > 0;
    final quantityColor =
        isPositive ? AppTheme.successColor : AppTheme.errorColor;
    final quantityPrefix = isPositive ? '+' : '';
    final unitLabel = movement.ingredientUnit ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor(movement.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(
              _typeIcon(movement.type),
              color: _typeColor(movement.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movement.ingredientName ?? '-',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypeBadge(type: movement.type, label: movement.typeLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      FormatUtils.relativeTime(movement.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    if (movement.notes != null &&
                        movement.notes!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '\u2022',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          movement.notes!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Quantity
          Text(
            '$quantityPrefix${FormatUtils.number(movement.quantity, decimals: movement.quantity == movement.quantity.roundToDouble() ? 0 : 2)} $unitLabel',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: quantityColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'purchase':
        return AppTheme.successColor;
      case 'adjustment':
        return AppTheme.infoColor;
      case 'waste':
        return AppTheme.errorColor;
      case 'transfer':
        return AppTheme.accentColor;
      case 'production':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'purchase':
        return Icons.shopping_cart_outlined;
      case 'adjustment':
        return Icons.tune;
      case 'waste':
        return Icons.delete_outline;
      case 'transfer':
        return Icons.swap_horiz;
      case 'production':
        return Icons.precision_manufacturing_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final String label;

  const _TypeBadge({required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case 'purchase':
        color = AppTheme.successColor;
        break;
      case 'adjustment':
        color = AppTheme.infoColor;
        break;
      case 'waste':
        color = AppTheme.errorColor;
        break;
      case 'transfer':
        color = AppTheme.accentColor;
        break;
      case 'production':
        color = AppTheme.primaryColor;
        break;
      default:
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
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
// Stock Adjustment Dialog
// ---------------------------------------------------------------------------

class _StockAdjustmentDialog extends StatefulWidget {
  final IngredientModel ingredient;
  final String outletId;
  final VoidCallback onSaved;

  const _StockAdjustmentDialog({
    required this.ingredient,
    required this.outletId,
    required this.onSaved,
  });

  @override
  State<_StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _costController = TextEditingController();
  String _selectedType = 'purchase';
  bool _saving = false;

  static const _types = [
    ('purchase', 'Pembelian', Icons.shopping_cart_outlined),
    ('adjustment', 'Penyesuaian', Icons.tune),
    ('waste', 'Waste', Icons.delete_outline),
  ];

  @override
  void initState() {
    super.initState();
    _costController.text = widget.ingredient.costPerUnit > 0
        ? widget.ingredient.costPerUnit.toStringAsFixed(0)
        : '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.tune, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesuaikan Stok',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.ingredient.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current stock info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stok Saat Ini:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${FormatUtils.number(widget.ingredient.currentStock, decimals: widget.ingredient.currentStock == widget.ingredient.currentStock.roundToDouble() ? 0 : 2)} ${widget.ingredient.unit}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Harga/Unit:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          FormatUtils.currency(widget.ingredient.costPerUnit),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.ingredient.costPerUnit > 0
                                ? AppTheme.textPrimary
                                : AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cost per unit input
              TextFormField(
                controller: _costController,
                decoration: InputDecoration(
                  labelText: 'Harga per ${widget.ingredient.unit}',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(Icons.attach_money),
                  hintText: 'Harga beli per unit',
                  helperText: 'Ubah harga akan otomatis update HPP produk terkait',
                  helperStyle: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Type selector
              Text(
                'Tipe Pergerakan',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _types.map((t) {
                  final isSelected = _selectedType == t.$1;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: t.$1 != _types.last.$1 ? 8 : 0,
                      ),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                        onTap: () =>
                            setState(() => _selectedType = t.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                    .withValues(alpha: 0.1)
                                : AppTheme.backgroundColor,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                t.$3,
                                size: 20,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textTertiary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Quantity input
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText:
                      'Jumlah (${widget.ingredient.unit})',
                  prefixIcon: const Icon(Icons.numbers),
                  hintText: _selectedType == 'waste'
                      ? 'Masukkan jumlah waste'
                      : 'Masukkan jumlah',
                  helperText: _selectedType == 'waste'
                      ? 'Stok akan dikurangi'
                      : _selectedType == 'purchase'
                          ? 'Stok akan ditambah'
                          : 'Positif = masuk, negatif = keluar',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Jumlah wajib diisi';
                  }
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed == 0) {
                    return 'Masukkan angka yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Notes input
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
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final repo = InventoryRepository();
      final rawQuantity =
          double.parse(_quantityController.text.trim());

      // For waste type, always make quantity negative
      // For purchase, always positive
      // For adjustment, keep as-is (user can enter negative)
      final double quantity;
      if (_selectedType == 'waste') {
        quantity = -(rawQuantity.abs());
      } else if (_selectedType == 'purchase') {
        quantity = rawQuantity.abs();
      } else {
        quantity = rawQuantity;
      }

      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      // Update cost_per_unit if changed
      final newCost = double.tryParse(_costController.text.trim().replaceAll('.', ''));
      if (newCost != null && newCost != widget.ingredient.costPerUnit) {
        await repo.updateIngredient(
          widget.ingredient.id,
          costPerUnit: newCost,
        );
      }

      await repo.adjustStock(
        ingredientId: widget.ingredient.id,
        outletId: widget.outletId,
        quantity: quantity,
        type: _selectedType,
        notes: notes,
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stok ${widget.ingredient.name} berhasil diupdate',
            ),
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
