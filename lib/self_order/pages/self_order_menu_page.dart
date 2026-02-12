import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../shared/themes/app_theme.dart';
import '../providers/self_order_provider.dart';
import '../repositories/self_order_repository.dart';
import 'self_order_cart_page.dart';

// ---------------------------------------------------------------------------
// Currency formatter for Indonesian Rupiah
// ---------------------------------------------------------------------------
final _currencyFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

// ---------------------------------------------------------------------------
// Search query provider (local to this page)
// ---------------------------------------------------------------------------
final _searchQueryProvider = StateProvider<String>((ref) => '');

/// Customer-facing menu page for self-ordering.
///
/// Displayed when a customer scans a QR code at their table.
/// Takes [tableId] as a constructor parameter to identify which table
/// the order belongs to.
class SelfOrderMenuPage extends ConsumerStatefulWidget {
  final String tableId;

  const SelfOrderMenuPage({super.key, required this.tableId});

  @override
  ConsumerState<SelfOrderMenuPage> createState() => _SelfOrderMenuPageState();
}

class _SelfOrderMenuPageState extends ConsumerState<SelfOrderMenuPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(selfOrderTableInfoProvider(widget.tableId));
    final categoriesAsync = ref.watch(selfOrderCategoriesProvider);
    final selectedCategory = ref.watch(selfOrderSelectedCategoryProvider);
    final filteredAsync = ref.watch(selfOrderFilteredProductsProvider);
    final cartItemCount = ref.watch(selfOrderCartItemCountProvider);
    final cartTotal = ref.watch(selfOrderCartTotalProvider);
    final searchQuery = ref.watch(_searchQueryProvider);

    // Animate FAB in/out based on cart contents
    if (cartItemCount > 0) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        body: SafeArea(
          child: Column(
            children: [
              // -- Header with outlet name & table info --
              _buildHeader(tableAsync),

              // -- Search bar --
              _buildSearchBar(),

              // -- Category chips --
              _buildCategoryChips(categoriesAsync, selectedCategory),

              // -- Product grid --
              Expanded(
                child: _buildProductGrid(filteredAsync, searchQuery),
              ),
            ],
          ),
        ),
        // -- Floating cart button --
        floatingActionButton: _buildCartFAB(cartItemCount, cartTotal),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================
  Widget _buildHeader(AsyncValue<Map<String, dynamic>?> tableAsync) {
    final tableNumber = tableAsync.whenOrNull(
      data: (info) => info?['table_number']?.toString() ?? info?['name']?.toString(),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Collab logo only
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/logo_collab_light_sm.png'
                    : 'assets/images/logo_collab_dark_sm.png',
                height: 36,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              // Table badge
              if (tableNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_restaurant_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Meja $tableNumber',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SEARCH BAR
  // =========================================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            ref.read(_searchQueryProvider.notifier).state = value;
          },
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Cari menu favorit kamu...',
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: AppTheme.textTertiary,
                size: 22,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(_searchQueryProvider.notifier).state = '';
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppTheme.textTertiary,
                        size: 20,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // CATEGORY CHIPS
  // =========================================================================
  Widget _buildCategoryChips(
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    String? selectedCategory,
  ) {
    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) {
        final featured = categories.where((c) => c['is_featured'] == true).toList();
        final regular = categories.where((c) => c['is_featured'] != true).toList();

        // Build ordered list: featured → Semua → regular
        final chips = <Widget>[
          ...featured.map((cat) {
            final name = cat['name'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: name,
                isSelected: selectedCategory == name,
                isFeatured: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(selfOrderSelectedCategoryProvider.notifier).state = name;
                },
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CategoryChip(
              label: 'Semua',
              isSelected: selectedCategory == null,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(selfOrderSelectedCategoryProvider.notifier).state = null;
              },
            ),
          ),
          ...regular.map((cat) {
            final name = cat['name'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: name,
                isSelected: selectedCategory == name,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(selfOrderSelectedCategoryProvider.notifier).state = name;
                },
              ),
            );
          }),
        ];

        return Container(
          height: 56,
          padding: const EdgeInsets.only(top: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: chips,
          ),
        );
      },
    );
  }

  // =========================================================================
  // PRODUCT GRID
  // =========================================================================
  Widget _buildProductGrid(
    AsyncValue<List<Map<String, dynamic>>> filteredAsync,
    String searchQuery,
  ) {
    return filteredAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Memuat menu...',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppTheme.errorColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat menu',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Periksa koneksi internet kamu dan coba lagi',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(selfOrderMenuProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (products) {
        // Apply search filter locally
        final filtered = searchQuery.isEmpty
            ? products
            : products.where((p) {
                final name =
                    (p['name'] as String? ?? '').toLowerCase();
                return name.contains(searchQuery.toLowerCase());
              }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(searchQuery);
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8, // Reduced from 12 (Moka style)
            crossAxisSpacing: 8, // Reduced from 12 (Moka style)
            childAspectRatio: 0.87, // ~1:1.15 ratio (slightly portrait, Moka style)
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return _ProductCard(
              product: product,
              onTap: () => _showProductDetailSheet(product),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // EMPTY STATE
  // =========================================================================
  Widget _buildEmptyState(String searchQuery) {
    final isSearching = searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.restaurant_menu_rounded,
                size: 48,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? 'Menu tidak ditemukan' : 'Belum ada menu',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Coba kata kunci lain atau hapus pencarian'
                  : 'Menu sedang disiapkan, coba lagi nanti',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            if (isSearching) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  ref.read(_searchQueryProvider.notifier).state = '';
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Hapus Pencarian'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CART FAB
  // =========================================================================
  Widget? _buildCartFAB(int itemCount, double total) {
    if (itemCount == 0) return null;

    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelfOrderCartPage(tableId: widget.tableId),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Item count badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$itemCount',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Lihat Keranjang',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _currencyFormat.format(total),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // PRODUCT DETAIL BOTTOM SHEET
  // =========================================================================
  void _showProductDetailSheet(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailSheet(
        product: product,
        tableId: widget.tableId,
      ),
    );
  }
}

// ===========================================================================
// CATEGORY CHIP WIDGET
// ===========================================================================
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFeatured;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : isFeatured
                  ? AppTheme.accentColor.withValues(alpha: 0.08)
                  : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : isFeatured
                    ? AppTheme.accentColor.withValues(alpha: 0.4)
                    : AppTheme.borderColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFeatured && !isSelected) ...[
              Icon(Icons.star_rounded, size: 14, color: AppTheme.accentColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected || isFeatured ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isFeatured
                        ? AppTheme.accentColor
                        : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// PRODUCT CARD WIDGET
// ===========================================================================
/// Extracts the primary image URL from a product map.
/// Checks product_images list first (primary flag, then first by sort_order),
/// falls back to the legacy image_url field.
String? _getPrimaryImageUrl(Map<String, dynamic> product) {
  final images = product['product_images'] as List<dynamic>?;
  if (images != null && images.isNotEmpty) {
    // Sort by sort_order
    final sorted = List<Map<String, dynamic>>.from(
      images.map((e) => e as Map<String, dynamic>),
    )..sort((a, b) =>
        ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0));

    // Find primary first
    for (final img in sorted) {
      if (img['is_primary'] == true) {
        return img['image_url'] as String?;
      }
    }
    // Fallback to first image
    return sorted.first['image_url'] as String?;
  }
  return product['image_url'] as String?;
}

/// Returns all image URLs for a product, sorted by sort_order.
List<String> _getAllImageUrls(Map<String, dynamic> product) {
  final images = product['product_images'] as List<dynamic>?;
  if (images != null && images.isNotEmpty) {
    final sorted = List<Map<String, dynamic>>.from(
      images.map((e) => e as Map<String, dynamic>),
    )..sort((a, b) =>
        ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0));

    return sorted
        .map((img) => img['image_url'] as String?)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
  }
  final legacy = product['image_url'] as String?;
  if (legacy != null && legacy.isNotEmpty) return [legacy];
  return [];
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? 'Produk';
    final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final imageUrl = _getPrimaryImageUrl(product);
    final category = product['categories'] as Map<String, dynamic>?;
    final categoryName = category?['name'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12), // Reduced from 16 (Moka compact style)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image - Moka style: dominant image (89% of card)
            Expanded(
              flex: 8, // Increased from 3 to 8 (Moka style)
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12), // Reduced from 16 for compact feel
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildPlaceholderImage(),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return _buildPlaceholderImage(
                            showLoading: true,
                          );
                        },
                      )
                    else
                      _buildPlaceholderImage(),
                    // Category badge overlay
                    if (categoryName != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            categoryName,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product info - Moka style: minimal text area (11% of card)
            Expanded(
              flex: 1, // Reduced from 2 to 1 (Moka style)
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6), // Tighter padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1, // Reduced from 2 (Moka compact style)
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11, // Reduced from 13 (Moka style)
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2), // Replace Spacer with fixed height
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _currencyFormat.format(price),
                            style: GoogleFonts.inter(
                              fontSize: 11, // Reduced from 14 (Moka style)
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 26, // Reduced from 30 (more compact)
                          height: 26, // Reduced from 30
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage({bool showLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.06),
            AppTheme.primaryColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryLight,
                ),
              )
            : Icon(
                Icons.lunch_dining_rounded,
                size: 40,
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
              ),
      ),
    );
  }
}

// ===========================================================================
// PRODUCT DETAIL BOTTOM SHEET
// ===========================================================================
class _ProductDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final String tableId;

  const _ProductDetailSheet({
    required this.product,
    required this.tableId,
  });

  @override
  ConsumerState<_ProductDetailSheet> createState() =>
      _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<_ProductDetailSheet> {
  int _quantity = 1;
  final _notesController = TextEditingController();

  // Modifier selections: groupId -> selected option(s)
  // For single-select (radio): groupId -> [single option map]
  // For multi-select (checkbox): groupId -> [list of option maps]
  final Map<String, List<Map<String, dynamic>>> _modifierSelections = {};

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _selectedModifiersTotal {
    double total = 0;
    for (final options in _modifierSelections.values) {
      for (final opt in options) {
        total += (opt['price'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  double get _itemTotal {
    final unitPrice =
        (widget.product['selling_price'] as num?)?.toDouble() ?? 0;
    return (unitPrice + _selectedModifiersTotal) * _quantity;
  }

  /// Validates that all required modifier groups have selections
  bool _areRequiredModifiersSelected(List<Map<String, dynamic>> modifierGroups) {
    for (final group in modifierGroups) {
      final isRequired = group['is_required'] as bool? ?? false;
      if (isRequired) {
        final groupId = group['id'] as String;
        final selectedOptions = _modifierSelections[groupId] ?? [];
        if (selectedOptions.isEmpty) {
          return false; // Required group has no selection
        }
      }
    }
    return true; // All required groups are satisfied
  }

  void _addToCart() {
    final product = widget.product;
    final unitPrice = (product['selling_price'] as num?)?.toDouble() ?? 0;

    // Build modifier list for the cart item
    final modifiers = <Map<String, dynamic>>[];
    for (final entry in _modifierSelections.entries) {
      for (final opt in entry.value) {
        modifiers.add({
          'name': opt['group_name'] ?? '',
          'option': opt['name'] ?? '',
          'price': (opt['price'] as num?)?.toDouble() ?? 0,
          if (opt['id'] != null) 'modifier_option_id': opt['id'],
        });
      }
    }

    final item = SelfOrderItem(
      productId: product['id'] as String,
      productName: product['name'] as String? ?? 'Produk',
      unitPrice: unitPrice,
      quantity: _quantity,
      modifiers: modifiers.isNotEmpty ? modifiers : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      imageUrl: _getPrimaryImageUrl(product),
    );

    ref.read(selfOrderCartProvider.notifier).addItem(item);

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();

    // Show snackbar confirmation
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${product['name']} ditambahkan ke keranjang',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final name = product['name'] as String? ?? 'Produk';
    final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final description = product['description'] as String?;
    final allImageUrls = _getAllImageUrls(product);
    final productId = product['id'] as String;
    final modifierGroupsAsync =
        ref.watch(selfOrderModifierGroupsProvider(productId));

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image(s) - carousel if multiple
                  if (allImageUrls.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: allImageUrls.length == 1
                            ? Image.network(
                                allImageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildSheetPlaceholder(),
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return _buildSheetPlaceholder(
                                    showLoading: true,
                                  );
                                },
                              )
                            : _ImageCarousel(imageUrls: allImageUrls),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: _buildSheetPlaceholder(),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Product name & price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currencyFormat.format(price),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Modifier groups
                  modifierGroupsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (groups) {
                      if (groups.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: groups.map((group) {
                          return _buildModifierGroup(group);
                        }).toList(),
                      );
                    },
                  ),

                  // Notes field
                  _buildNotesField(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom bar: quantity selector + add-to-cart button
          // Pass modifier groups for validation (empty list if still loading/error)
          _buildBottomBar(
            name,
            price,
            modifierGroupsAsync.maybeWhen(
              data: (groups) => groups,
              orElse: () => <Map<String, dynamic>>[],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetPlaceholder({bool showLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.05),
            AppTheme.primaryColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: showLoading
            ? const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryLight,
              )
            : Icon(
                Icons.lunch_dining_rounded,
                size: 56,
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Modifier group builder
  // -------------------------------------------------------------------------
  Widget _buildModifierGroup(Map<String, dynamic> group) {
    final groupId = group['id'] as String;
    final groupName = group['name'] as String? ?? '';
    final isRequired = group['is_required'] as bool? ?? false;
    final maxSelections = group['max_selections'] as int? ?? 1;
    final isSingleSelect = maxSelections <= 1;
    final options =
        (group['modifier_options'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    if (options.isEmpty) return const SizedBox.shrink();

    final selectedOptions = _modifierSelections[groupId] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Row(
            children: [
              Expanded(
                child: Text(
                  groupName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Wajib',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.errorColor,
                    ),
                  ),
                )
              else
                Text(
                  'Opsional',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
            ],
          ),
          if (!isSingleSelect)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Pilih hingga $maxSelections',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: 10),

          // Options list
          ...options.map((option) {
            final optionName = option['name'] as String? ?? '';
            final optionPrice =
                (option['price'] as num?)?.toDouble() ?? 0;
            final isSelected = selectedOptions.any(
              (sel) => sel['id'] == option['id'],
            );

            // Add group_name to option map for cart usage
            final optionWithGroup = {
              ...option,
              'group_name': groupName,
            };

            return _buildModifierOption(
              groupId: groupId,
              option: optionWithGroup,
              optionName: optionName,
              optionPrice: optionPrice,
              isSelected: isSelected,
              isSingleSelect: isSingleSelect,
              maxSelections: maxSelections,
              selectedOptions: selectedOptions,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModifierOption({
    required String groupId,
    required Map<String, dynamic> option,
    required String optionName,
    required double optionPrice,
    required bool isSelected,
    required bool isSingleSelect,
    required int maxSelections,
    required List<Map<String, dynamic>> selectedOptions,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSingleSelect) {
            // Radio-style: replace selection
            if (isSelected) {
              _modifierSelections.remove(groupId);
            } else {
              _modifierSelections[groupId] = [option];
            }
          } else {
            // Checkbox-style: toggle selection
            if (isSelected) {
              selectedOptions.removeWhere(
                  (sel) => sel['id'] == option['id']);
              if (selectedOptions.isEmpty) {
                _modifierSelections.remove(groupId);
              } else {
                _modifierSelections[groupId] = [...selectedOptions];
              }
            } else {
              if (selectedOptions.length < maxSelections) {
                _modifierSelections[groupId] = [
                  ...selectedOptions,
                  option
                ];
              }
            }
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Radio/checkbox indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                shape: isSingleSelect
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: isSingleSelect
                    ? null
                    : BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                optionName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            if (optionPrice > 0)
              Text(
                '+${_currencyFormat.format(optionPrice)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Notes field
  // -------------------------------------------------------------------------
  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catatan',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Contoh: tidak pedas, tanpa es...',
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Bottom bar with quantity + add-to-cart button
  // -------------------------------------------------------------------------
  Widget _buildBottomBar(String name, double basePrice, List<Map<String, dynamic>> modifierGroups) {
    // Validate required modifiers
    final canAddToCart = _areRequiredModifiersSelected(modifierGroups);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Quantity selector
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus button
                  _QuantityButton(
                    icon: Icons.remove_rounded,
                    onTap: _quantity > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _quantity--);
                          }
                        : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        '$_quantity',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Plus button
                  _QuantityButton(
                    icon: Icons.add_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _quantity++);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Add to cart button - disabled if required modifiers not selected
            Expanded(
              child: ElevatedButton(
                onPressed: canAddToCart ? _addToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.borderColor,
                  disabledForegroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Tambah',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currencyFormat.format(_itemTotal),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// IMAGE CAROUSEL (for multi-image products in detail sheet)
// ===========================================================================
class _ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;

  const _ImageCarousel({required this.imageUrls});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Swipeable images
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemBuilder: (context, index) {
            return Image.network(
              widget.imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 40,
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  ),
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Page indicators (dots)
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.imageUrls.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        // Image counter badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_currentPage + 1}/${widget.imageUrls.length}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// QUANTITY BUTTON (reusable for the +/- controls)
// ===========================================================================
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: isDisabled
                ? AppTheme.textTertiary.withValues(alpha: 0.4)
                : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
