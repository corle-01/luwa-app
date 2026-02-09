import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/providers/outlet_provider.dart';
import '../providers/product_stock_provider.dart';
import '../repositories/product_stock_repository.dart';

/// Standalone page with Scaffold (for direct navigation).
class ProductStockPage extends ConsumerWidget {
  const ProductStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Produk Jadi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(productStockListProvider);
              ref.invalidate(allProductStockMovementsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const ProductStockContent(),
    );
  }
}

/// Embeddable content widget (no Scaffold) -- used as a tab inside InventoryPage.
class ProductStockContent extends ConsumerWidget {
  const ProductStockContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(productStockListProvider);

    return stockAsync.when(
      data: (products) {
        final tracked = products.where((p) => p.trackStock).toList();
        final lowStockItems = tracked
            .where((p) => p.isLowStock || p.isOutOfStock)
            .toList();
        final totalStockValue = tracked.fold<double>(
          0,
          (sum, p) => sum + p.stockValue,
        );

        return Column(
          children: [
            // Summary cards
            _SummaryRow(
              totalTracked: tracked.length,
              lowStockCount: lowStockItems.length,
              totalStockValue: totalStockValue,
            ),
            const Divider(height: 1),
            // Product stock table
            Expanded(
              child: _ProductStockTable(
                products: products,
                ref: ref,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(productStockListProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final int totalTracked;
  final int lowStockCount;
  final double totalStockValue;

  const _SummaryRow({
    required this.totalTracked,
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
                  label: 'Dilacak',
                  value: totalTracked.toString(),
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
// Product Stock Table
// ---------------------------------------------------------------------------

class _ProductStockTable extends StatelessWidget {
  final List<ProductStockModel> products;
  final WidgetRef ref;

  const _ProductStockTable({
    required this.products,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        iconColor: AppTheme.textTertiary,
        title: 'Belum ada produk',
        subtitle: 'Produk yang dilacak stoknya akan muncul di sini',
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildMobileCard(context, product);
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
            DataColumn(label: Text('Produk')),
            DataColumn(label: Text('Lacak')),
            DataColumn(label: Text('Stok'), numeric: true),
            DataColumn(label: Text('Min'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                // Produk name + category
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style:
                            GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      if (product.categoryName != null)
                        Text(
                          product.categoryName!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Track toggle
                DataCell(
                  Switch(
                    value: product.trackStock,
                    onChanged: (val) async {
                      final repo = ProductStockRepository();
                      await repo.toggleTrackStock(product.id, val);
                      ref.invalidate(productStockListProvider);
                    },
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                // Stok quantity
                DataCell(
                  Text(
                    product.trackStock
                        ? product.stockQuantity.toString()
                        : '-',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: !product.trackStock
                          ? AppTheme.textTertiary
                          : product.isOutOfStock
                              ? AppTheme.errorColor
                              : product.isLowStock
                                  ? AppTheme.warningColor
                                  : AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Min stock
                DataCell(
                  Text(
                    product.trackStock
                        ? product.minStock.toString()
                        : '-',
                    style: GoogleFonts.inter(
                      color: product.trackStock
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
                // Status badge
                DataCell(_StatusBadge(product: product)),
                // Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit Min Stok & Harga Modal',
                        onPressed: () => _showEditProductStockDialog(
                          context,
                          ref,
                          product,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 20),
                        tooltip: 'Stok Masuk / Keluar',
                        onPressed: product.trackStock
                            ? () => _showStockMovementDialog(
                                  context,
                                  ref,
                                  product,
                                )
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, size: 20),
                        tooltip: 'Riwayat',
                        onPressed: () => _showMovementHistory(
                          context,
                          ref,
                          product,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.errorColor),
                        tooltip: 'Hapus Produk',
                        onPressed: () => _confirmDeleteProduct(
                          context,
                          ref,
                          product,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, ProductStockModel product) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        children: [
          // Row 1: name + stock quantity
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.categoryName != null)
                      Text(
                        product.categoryName!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.trackStock
                        ? '${product.stockQuantity} pcs'
                        : '-',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: !product.trackStock
                          ? AppTheme.textTertiary
                          : product.isOutOfStock
                              ? AppTheme.errorColor
                              : product.isLowStock
                                  ? AppTheme.warningColor
                                  : AppTheme.textPrimary,
                    ),
                  ),
                  if (product.trackStock)
                    Text(
                      'Min: ${product.minStock}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: track toggle + status + actions
          Row(
            children: [
              SizedBox(
                height: 28,
                child: Switch(
                  value: product.trackStock,
                  onChanged: (val) async {
                    final repo = ProductStockRepository();
                    await repo.toggleTrackStock(product.id, val);
                    ref.invalidate(productStockListProvider);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(product: product),
              const Spacer(),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit',
                  onPressed: () => _showEditProductStockDialog(context, ref, product),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  tooltip: 'Stok Masuk / Keluar',
                  onPressed: product.trackStock
                      ? () => _showStockMovementDialog(context, ref, product)
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.history, size: 20),
                  padding: EdgeInsets.zero,
                  tooltip: 'Riwayat',
                  onPressed: () => _showMovementHistory(context, ref, product),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.errorColor),
                  padding: EdgeInsets.zero,
                  tooltip: 'Hapus',
                  onPressed: () =>
                      _confirmDeleteProduct(context, ref, product),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditProductStockDialog(
    BuildContext context,
    WidgetRef ref,
    ProductStockModel product,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditProductStockDialog(
        product: product,
        onSaved: () {
          ref.invalidate(productStockListProvider);
        },
      ),
    );
  }

  void _showStockMovementDialog(
    BuildContext context,
    WidgetRef ref,
    ProductStockModel product,
  ) {
    showDialog(
      context: context,
      builder: (context) => _StockMovementDialog(
        product: product,
        outletId: ref.read(currentOutletIdProvider),
        onSaved: () {
          ref.invalidate(productStockListProvider);
          ref.invalidate(allProductStockMovementsProvider);
        },
      ),
    );
  }

  void _confirmDeleteProduct(
    BuildContext context,
    WidgetRef ref,
    ProductStockModel product,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text(
          'Yakin ingin menghapus "${product.name}"?\n\nProduk akan dinonaktifkan dan tidak muncul di POS.',
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
                final repo = ProductStockRepository();
                await repo.deleteProduct(product.id);
                ref.invalidate(productStockListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} berhasil dihapus'),
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

  void _showMovementHistory(
    BuildContext context,
    WidgetRef ref,
    ProductStockModel product,
  ) {
    showDialog(
      context: context,
      builder: (context) => _MovementHistoryDialog(
        product: product,
        ref: ref,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final ProductStockModel product;

  const _StatusBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.trackStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          'Tidak Dilacak',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
          ),
        ),
      );
    }

    final String label;
    final Color color;

    if (product.isOutOfStock) {
      label = 'Habis';
      color = AppTheme.errorColor;
    } else if (product.isLowStock) {
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
// Movements List (Riwayat tab)
// ---------------------------------------------------------------------------

class _MovementsList extends StatelessWidget {
  final List<ProductStockMovement> movements;

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
  final ProductStockMovement movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.quantity > 0;
    final quantityColor =
        isPositive ? AppTheme.successColor : AppTheme.errorColor;
    final quantityPrefix = isPositive ? '+' : '';

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
                        movement.productName ?? '-',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypeBadge(
                        type: movement.type, label: movement.typeLabel),
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
            '$quantityPrefix${movement.quantity} pcs',
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
      case 'stock_in':
        return AppTheme.successColor;
      case 'stock_out':
        return AppTheme.errorColor;
      case 'adjustment':
        return AppTheme.infoColor;
      case 'production':
        return AppTheme.primaryColor;
      case 'sale':
        return AppTheme.accentColor;
      case 'return':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'stock_in':
        return Icons.arrow_downward;
      case 'stock_out':
        return Icons.arrow_upward;
      case 'adjustment':
        return Icons.tune;
      case 'production':
        return Icons.precision_manufacturing_outlined;
      case 'sale':
        return Icons.point_of_sale;
      case 'return':
        return Icons.undo;
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
      case 'stock_in':
        color = AppTheme.successColor;
        break;
      case 'stock_out':
        color = AppTheme.errorColor;
        break;
      case 'adjustment':
        color = AppTheme.infoColor;
        break;
      case 'production':
        color = AppTheme.primaryColor;
        break;
      case 'sale':
        color = AppTheme.accentColor;
        break;
      case 'return':
        color = AppTheme.secondaryColor;
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
// Stock Movement Dialog (Add Stock In/Out)
// ---------------------------------------------------------------------------

class _StockMovementDialog extends StatefulWidget {
  final ProductStockModel product;
  final String outletId;
  final VoidCallback onSaved;

  const _StockMovementDialog({
    required this.product,
    required this.outletId,
    required this.onSaved,
  });

  @override
  State<_StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<_StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedType = 'stock_in';
  bool _saving = false;

  static const _types = [
    ('stock_in', 'Stok Masuk', Icons.arrow_downward),
    ('stock_out', 'Stok Keluar', Icons.arrow_upward),
    ('adjustment', 'Penyesuaian', Icons.tune),
    ('production', 'Produksi', Icons.precision_manufacturing_outlined),
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pergerakan Stok',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.product.name,
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
        width: 480,
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
                child: Row(
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
                      '${widget.product.stockQuantity} pcs',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Min: ${widget.product.minStock}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) {
                  final isSelected = _selectedType == t.$1;
                  return InkWell(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusM),
                    onTap: () =>
                        setState(() => _selectedType = t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            t.$3,
                            size: 18,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.$2,
                            style: GoogleFonts.inter(
                              fontSize: 12,
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
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Quantity input
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Jumlah (pcs)',
                  prefixIcon: const Icon(Icons.numbers),
                  hintText: _selectedType == 'stock_out'
                      ? 'Masukkan jumlah keluar'
                      : 'Masukkan jumlah',
                  helperText: _selectedType == 'stock_out'
                      ? 'Stok akan dikurangi'
                      : _selectedType == 'stock_in'
                          ? 'Stok akan ditambah'
                          : _selectedType == 'production'
                              ? 'Stok akan ditambah (hasil produksi)'
                              : 'Positif = masuk, negatif = keluar',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Jumlah wajib diisi';
                  }
                  final parsed = int.tryParse(v.trim());
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
      final repo = ProductStockRepository();
      final rawQuantity = int.parse(_quantityController.text.trim());

      // For stock_out, always make quantity negative
      // For stock_in & production, always positive
      // For adjustment, keep as-is
      final int quantity;
      if (_selectedType == 'stock_out') {
        quantity = -(rawQuantity.abs());
      } else if (_selectedType == 'stock_in' ||
          _selectedType == 'production') {
        quantity = rawQuantity.abs();
      } else {
        quantity = rawQuantity;
      }

      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      await repo.addStockMovement(
        productId: widget.product.id,
        outletId: widget.outletId,
        type: _selectedType,
        quantity: quantity,
        notes: notes,
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stok ${widget.product.name} berhasil diupdate',
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
// Movement History Dialog (per product)
// ---------------------------------------------------------------------------

class _MovementHistoryDialog extends ConsumerWidget {
  final ProductStockModel product;
  final WidgetRef ref;

  const _MovementHistoryDialog({
    required this.product,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync =
        ref.watch(productStockMovementsProvider(product.id));

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Stok',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  product.name,
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
        width: 500,
        height: 400,
        child: movementsAsync.when(
          data: (movements) {
            if (movements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history,
                        size: 48, color: AppTheme.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada riwayat',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: movements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final m = movements[index];
                final isPositive = m.quantity > 0;
                final prefix = isPositive ? '+' : '';
                final color = isPositive
                    ? AppTheme.successColor
                    : AppTheme.errorColor;

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(
                      isPositive
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 16,
                      color: color,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        m.typeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$prefix${m.quantity} pcs',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        FormatUtils.relativeTime(m.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      if (m.notes != null && m.notes!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.notes!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: GoogleFonts.inter(color: AppTheme.errorColor),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Product Stock Dialog (min_stock + cost_price)
// ---------------------------------------------------------------------------

class _EditProductStockDialog extends StatefulWidget {
  final ProductStockModel product;
  final VoidCallback onSaved;

  const _EditProductStockDialog({
    required this.product,
    required this.onSaved,
  });

  @override
  State<_EditProductStockDialog> createState() =>
      _EditProductStockDialogState();
}

class _EditProductStockDialogState extends State<_EditProductStockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minStockController;
  late final TextEditingController _costPriceController;
  bool _saving = false;
  bool _hasRecipe = false;
  bool _loadingRecipe = true;

  @override
  void initState() {
    super.initState();
    _minStockController =
        TextEditingController(text: widget.product.minStock.toString());
    _costPriceController = TextEditingController(
        text: widget.product.costPrice > 0
            ? widget.product.costPrice.toStringAsFixed(0)
            : '');
    _checkRecipe();
  }

  Future<void> _checkRecipe() async {
    final repo = ProductStockRepository();
    final has = await repo.hasRecipe(widget.product.id);
    if (mounted) {
      setState(() {
        _hasRecipe = has;
        _loadingRecipe = false;
      });
    }
  }

  @override
  void dispose() {
    _minStockController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final margin = widget.product.sellingPrice - widget.product.costPrice;
    final marginPct = widget.product.sellingPrice > 0
        ? (margin / widget.product.sellingPrice * 100)
        : 0.0;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Produk',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.product.name,
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
              // Current info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Harga Jual',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.textTertiary)),
                        Text(
                          FormatUtils.currency(widget.product.sellingPrice),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('HPP (Harga Modal)',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.textTertiary)),
                        Text(
                          FormatUtils.currency(widget.product.costPrice),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Margin',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.textTertiary)),
                        Text(
                          '${FormatUtils.currency(margin)} (${marginPct.toStringAsFixed(1)}%)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: marginPct >= 30
                                ? AppTheme.successColor
                                : marginPct >= 15
                                    ? AppTheme.warningColor
                                    : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stok Saat Ini',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.textTertiary)),
                        Text(
                          '${widget.product.stockQuantity} pcs',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // HPP source indicator
              if (!_loadingRecipe)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hasRecipe
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasRecipe ? Icons.auto_fix_high : Icons.edit_note,
                        size: 16,
                        color: _hasRecipe
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _hasRecipe
                              ? 'HPP otomatis dari resep (tidak bisa edit manual)'
                              : 'HPP manual — produk ini belum punya resep',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _hasRecipe
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Min stock input
              TextFormField(
                controller: _minStockController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Stok (pcs)',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                  helperText: 'Alert jika stok di bawah jumlah ini',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Masukkan angka valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Cost price input (disabled if has recipe)
              TextFormField(
                controller: _costPriceController,
                enabled: !_hasRecipe,
                decoration: InputDecoration(
                  labelText: 'Harga Modal (Rp)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  helperText: _hasRecipe
                      ? 'Dihitung otomatis dari resep bahan baku'
                      : 'Harga beli per pcs dari supplier',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_hasRecipe) return null;
                  if (v != null && v.trim().isNotEmpty) {
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Masukkan angka valid';
                    }
                  }
                  return null;
                },
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
      final repo = ProductStockRepository();
      final minStock = int.parse(_minStockController.text.trim());
      await repo.updateMinStock(widget.product.id, minStock);

      // Only update cost_price if product has no recipe (manual HPP)
      if (!_hasRecipe) {
        final costText = _costPriceController.text.trim();
        final costPrice =
            costText.isEmpty ? 0.0 : double.parse(costText);
        await repo.updateCostPrice(widget.product.id, costPrice);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} berhasil diupdate'),
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
